import { NextRequest, NextResponse } from "next/server";
import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

const APP_NAME = "busmate-admin";

function getAdminServices() {
  const existing = getApps().find((a) => a.name === APP_NAME);
  const app =
    existing ??
    initializeApp(
      { credential: cert(JSON.parse(process.env.FIREBASE_ADMIN_SERVICE_ACCOUNT!)) },
      APP_NAME
    );
  return { db: getFirestore(app, "busmate-db"), auth: getAuth(app) };
}

export async function POST(req: NextRequest) {
  const { email, schoolId, code } = await req.json();
  if (!email || !schoolId || !code) {
    return NextResponse.json({ error: "Email, schoolId, and code are required." }, { status: 400 });
  }

  const normalised = email.trim().toLowerCase();
  const { db, auth } = getAdminServices();

  // Fetch stored setup code
  const docKey = `${schoolId}:${normalised}`;
  const codeRef = db.collection("setupCodes").doc(docKey);
  const codeDoc = await codeRef.get();

  if (!codeDoc.exists) {
    return NextResponse.json({ error: "No setup code found. Please request a new code." }, { status: 404 });
  }

  const { code: storedCode, expiresAt } = codeDoc.data()!;

  // Check expiry
  const now = Timestamp.now();
  if (now.toMillis() > (expiresAt as Timestamp).toMillis()) {
    await codeRef.delete();
    return NextResponse.json({ error: "Code has expired. Please request a new one." }, { status: 410 });
  }

  // Check code (case-insensitive)
  if (code.trim().toUpperCase() !== storedCode) {
    return NextResponse.json({ error: "Incorrect code. Please try again." }, { status: 401 });
  }

  // Code valid — delete it so it can't be reused
  await codeRef.delete();

  // Find the user's Firestore doc to get their role and Firestore doc ID
  const collections = ["drivers", "parents", "students"];
  let role = "";
  let firestoreDocId = "";

  for (const col of collections) {
    const snap = await db
      .collection(col)
      .where("schoolId", "==", schoolId)
      .where("email", "==", normalised)
      .where("isActive", "==", true)
      .limit(1)
      .get();
    if (!snap.empty) {
      role = col.slice(0, -1); // "drivers" → "driver" etc.
      firestoreDocId = snap.docs[0].id;
      break;
    }
  }

  if (!role) {
    return NextResponse.json({ error: "Account not found." }, { status: 404 });
  }

  // Check if a Firebase Auth account already exists for this email
  let uid: string;
  try {
    const existing = await auth.getUserByEmail(normalised);
    uid = existing.uid;
  } catch {
    // No Firebase Auth account yet — create one (password will be set by the app via signUp)
    // We return a custom token so the app can sign in server-side after creating the account
    // The app calls signUpWithEmailPassword first, then signs in — no custom token needed here.
    // Return a marker so the app knows the code is valid and can proceed with signUp.
    return NextResponse.json({ verified: true, firestoreDocId, role, needsSignUp: true });
  }

  // Firebase Auth account exists — create a custom token so the app can sign in
  const customToken = await auth.createCustomToken(uid, { role });
  return NextResponse.json({ verified: true, firestoreDocId, role, customToken, needsSignUp: false });
}

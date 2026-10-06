import { NextRequest, NextResponse } from "next/server";
import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

const APP_NAME = "busmate-admin";

function getAdminServices() {
  const existing = getApps().find(a => a.name === APP_NAME);
  const app = existing ?? initializeApp(
    { credential: cert(JSON.parse(process.env.FIREBASE_ADMIN_SERVICE_ACCOUNT!)) },
    APP_NAME,
  );
  return { db: getFirestore(app, "busmate-db"), auth: getAuth(app) };
}

export async function POST(req: NextRequest) {
  const { token, email } = await req.json();
  if (!token || !email) {
    return NextResponse.json({ error: "Token and email are required." }, { status: 400 });
  }

  const normalised = email.trim().toLowerCase();
  const { db, auth } = getAdminServices();

  // Fetch and validate the token document
  const tokenRef = db.collection("adminSigninTokens").doc(token);
  const tokenDoc = await tokenRef.get();

  if (!tokenDoc.exists) {
    return NextResponse.json({ error: "Invalid or expired sign-in link." }, { status: 404 });
  }

  const data = tokenDoc.data()!;

  // Check expiry
  const now = Timestamp.now();
  if (now.toMillis() > (data.expiresAt as Timestamp).toMillis()) {
    await tokenRef.delete();
    return NextResponse.json({ error: "This sign-in link has expired. Please request a new one." }, { status: 410 });
  }

  // Check email matches
  if (data.email !== normalised) {
    return NextResponse.json({ error: "Email does not match this sign-in link." }, { status: 401 });
  }

  // Consume the token immediately — single use
  await tokenRef.delete();

  const pendingSignup = data.pendingSignup as {
    schoolName: string;
    schoolNameLower: string;
    adminName: string;
    email: string;
    isSignup: boolean;
  } | undefined;

  let adminUid: string;
  let schoolName: string;
  let adminName: string;

  if (pendingSignup?.isSignup) {
    // New signup — create the Firebase Auth user if they don't exist yet,
    // then create the school doc. The custom token will sign them in.
    let uid: string;
    try {
      const existing = await auth.getUserByEmail(normalised);
      uid = existing.uid;
    } catch {
      // User doesn't exist in Firebase Auth — create them
      const created = await auth.createUser({
        email: normalised,
        displayName: pendingSignup.adminName !== normalised ? pendingSignup.adminName : undefined,
        emailVerified: true,
      });
      uid = created.uid;
    }

    // Write the school document
    await db.collection("schools").add({
      schoolName: pendingSignup.schoolName,
      schoolNameLower: pendingSignup.schoolNameLower,
      email: normalised,
      adminUid: uid,
      adminName: pendingSignup.adminName,
      createdAt: Timestamp.now(),
      emailVerified: true,
    });

    adminUid = uid;
    schoolName = pendingSignup.schoolName;
    adminName = pendingSignup.adminName;

    // Fire welcome email — non-blocking, don't let it break the login flow
    fetch(`${req.nextUrl.origin}/api/welcome/admin`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: normalised, adminName, schoolName }),
    }).catch(err => console.error("welcome/admin fire error:", err));
  } else {
    // Returning login — look up the school
    const snap = await db.collection("schools").where("email", "==", normalised).limit(1).get();
    if (snap.empty) {
      return NextResponse.json({ error: "No admin account found for this email." }, { status: 404 });
    }
    const schoolData = snap.docs[0].data();
    adminUid = schoolData.adminUid;
    schoolName = schoolData.schoolName ?? "";
    adminName = schoolData.adminName ?? "";
  }

  const customToken = await auth.createCustomToken(adminUid, { role: "admin" });

  return NextResponse.json({ customToken, schoolName, adminName, adminUid, isSignup: !!pendingSignup?.isSignup });
}

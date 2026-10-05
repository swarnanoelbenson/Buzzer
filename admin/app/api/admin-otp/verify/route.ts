import { NextRequest, NextResponse } from "next/server";
import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

function getAdminServices() {
  if (!getApps().length) {
    initializeApp({ credential: cert(JSON.parse(process.env.FIREBASE_ADMIN_SERVICE_ACCOUNT!)) });
  }
  return { db: getFirestore(), auth: getAuth() };
}

export async function POST(req: NextRequest) {
  const { email, otp } = await req.json();
  if (!email || !otp) {
    return NextResponse.json({ error: "Email and OTP are required." }, { status: 400 });
  }

  const normalised = email.trim().toLowerCase();
  const { db, auth } = getAdminServices();

  // Fetch stored OTP
  const otpRef = db.collection("adminOtps").doc(normalised);
  const otpDoc = await otpRef.get();

  if (!otpDoc.exists) {
    return NextResponse.json({ error: "No OTP found. Please request a new code." }, { status: 404 });
  }

  const { otp: storedOtp, expiresAt } = otpDoc.data()!;

  // Check expiry
  const now = Timestamp.now();
  if (now.toMillis() > (expiresAt as Timestamp).toMillis()) {
    await otpRef.delete();
    return NextResponse.json({ error: "OTP has expired. Please request a new code." }, { status: 410 });
  }

  // Check code
  if (otp.trim() !== storedOtp) {
    return NextResponse.json({ error: "Incorrect code. Please try again." }, { status: 401 });
  }

  // OTP valid — delete it so it can't be reused
  await otpRef.delete();

  // Look up admin in schools collection
  const snap = await db.collection("schools").where("email", "==", normalised).limit(1).get();
  if (snap.empty) {
    return NextResponse.json({ error: "Admin account not found." }, { status: 404 });
  }

  const schoolData = snap.docs[0].data();
  const adminUid: string = schoolData.adminUid;
  const schoolName: string = schoolData.schoolName ?? "";
  const adminName: string = schoolData.adminName ?? "";

  // Create a custom Firebase Auth token so the iOS app can sign in
  const customToken = await auth.createCustomToken(adminUid, { role: "admin" });

  return NextResponse.json({ customToken, schoolName, adminName, adminUid });
}

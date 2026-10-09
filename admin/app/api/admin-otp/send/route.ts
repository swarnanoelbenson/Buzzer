import { NextRequest, NextResponse } from "next/server";
import { randomInt } from "crypto";
import { Resend } from "resend";
import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

const APP_NAME = "busmate-admin";

function getAdminDb() {
  const existing = getApps().find(a => a.name === APP_NAME);
  const app = existing ?? initializeApp(
    { credential: cert(JSON.parse(process.env.FIREBASE_ADMIN_SERVICE_ACCOUNT!)) },
    APP_NAME,
  );
  return getFirestore(app, "busmate-db");
}

function generateOtp(): string {
  return randomInt(100000, 1000000).toString();
}

export async function POST(req: NextRequest) {
  const { email } = await req.json();
  if (!email || typeof email !== "string") {
    return NextResponse.json({ error: "Email is required." }, { status: 400 });
  }

  const normalised = email.trim().toLowerCase();

  // Verify the email exists in the schools collection
  const db = getAdminDb();
  const snap = await db.collection("schools").where("email", "==", normalised).limit(1).get();
  if (snap.empty) {
    return NextResponse.json({ error: "No admin account found for this email." }, { status: 404 });
  }

  const schoolDoc = snap.docs[0];
  const schoolName: string = schoolDoc.data().schoolName ?? "";

  // Generate OTP and store with 10-minute expiry
  const otp = generateOtp();
  const expiresAt = Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000));
  await db.collection("adminOtps").doc(normalised).set({ otp, expiresAt, schoolName });

  // Send via Resend
  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    return NextResponse.json({ error: "Email service not configured." }, { status: 500 });
  }

  const resend = new Resend(resendKey);
  try {
    await resend.emails.send({
      from: "BusMate <noreply@updates.busmate.com.au>",
      to: [normalised],
      subject: `Your BusMate sign-in code: ${otp}`,
      html: `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f9fafb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:440px;">
          <tr>
            <td align="center" style="padding-bottom:24px;">
              <div style="display:inline-block;background:#2563eb;border-radius:16px;padding:12px 20px;">
                <span style="color:white;font-size:16px;font-weight:900;letter-spacing:0.15em;">BUSMATE</span>
              </div>
              <p style="margin:8px 0 0;font-size:11px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Admin Console</p>
            </td>
          </tr>
          <tr>
            <td style="background:white;border-radius:20px;border:1px solid #f3f4f6;padding:32px;text-align:center;">
              <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;">Your sign-in code</h2>
              <p style="margin:0 0 28px;font-size:14px;color:#6b7280;">Use this 6-digit code to sign in to BusMate Admin on your device. It expires in 10 minutes.</p>
              <div style="display:inline-block;background:#eff6ff;border:2px solid #bfdbfe;border-radius:16px;padding:20px 36px;margin-bottom:28px;">
                <span style="font-size:36px;font-weight:900;letter-spacing:0.25em;color:#1d4ed8;">${otp}</span>
              </div>
              <p style="margin:0;font-size:13px;color:#9ca3af;">If you didn't request this, you can safely ignore this email.</p>
            </td>
          </tr>
          <tr>
            <td style="padding-top:20px;text-align:center;">
              <p style="margin:0;font-size:11px;color:#d1d5db;">BusMate Admin Console · ${schoolName}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
      `.trim(),
    });
  } catch (err) {
    console.error("admin-otp send error:", err);
    return NextResponse.json({ error: "Failed to send OTP email." }, { status: 500 });
  }

  return NextResponse.json({ sent: true, schoolName });
}

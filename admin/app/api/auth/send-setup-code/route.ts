import { NextRequest, NextResponse } from "next/server";
import { randomBytes } from "crypto";
import { Resend } from "resend";
import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

const APP_NAME = "busmate-admin";

function getAdminDb() {
  const existing = getApps().find((a) => a.name === APP_NAME);
  const app =
    existing ??
    initializeApp(
      { credential: cert(JSON.parse(process.env.FIREBASE_ADMIN_SERVICE_ACCOUNT!)) },
      APP_NAME
    );
  return getFirestore(app, "busmate-db");
}

/** Generates a 6-character uppercase alphanumeric code (no O/0/I/1 to avoid confusion). */
function generateSetupCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  const bytes = randomBytes(6);
  for (let i = 0; i < 6; i++) {
    code += chars[bytes[i] % chars.length];
  }
  return code;
}

export async function POST(req: NextRequest) {
  const { email, schoolId } = await req.json();
  if (!email || !schoolId) {
    return NextResponse.json({ error: "Email and schoolId are required." }, { status: 400 });
  }

  const normalised = email.trim().toLowerCase();
  const db = getAdminDb();

  // Verify the email exists in drivers, parents, or students for this school
  const collections = ["drivers", "parents", "students"];
  let found = false;
  let userName = "";

  for (const col of collections) {
    const snap = await db
      .collection(col)
      .where("schoolId", "==", schoolId)
      .where("email", "==", normalised)
      .where("isActive", "==", true)
      .limit(1)
      .get();
    if (!snap.empty) {
      found = true;
      userName = snap.docs[0].data().name ?? "";
      break;
    }
  }

  if (!found) {
    return NextResponse.json(
      { error: "No active account found for this email at this school." },
      { status: 404 }
    );
  }

  // Generate code and store with 10-minute expiry
  const code = generateSetupCode();
  const expiresAt = Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000));
  // Key by schoolId+email so the same email at different schools doesn't collide
  const docKey = `${schoolId}:${normalised}`;
  await db.collection("setupCodes").doc(docKey).set({ code, expiresAt, email: normalised, schoolId });

  // Send via Resend
  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    return NextResponse.json({ error: "Email service not configured." }, { status: 500 });
  }

  const resend = new Resend(resendKey);
  try {
    await resend.emails.send({
      from: "BusMate <onboarding@resend.dev>",
      to: [normalised],
      subject: `Your BusMate setup code: ${code}`,
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
            </td>
          </tr>
          <tr>
            <td style="background:white;border-radius:20px;border:1px solid #f3f4f6;padding:32px;text-align:center;">
              <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;">Set up your password</h2>
              <p style="margin:0 0 28px;font-size:14px;color:#6b7280;">Hi ${userName ? userName + ", use" : "Use"} this code to verify your email and set your BusMate password. It expires in 10 minutes.</p>
              <div style="display:inline-block;background:#eff6ff;border:2px solid #bfdbfe;border-radius:16px;padding:20px 36px;margin-bottom:28px;">
                <span style="font-size:36px;font-weight:900;letter-spacing:0.25em;color:#1d4ed8;">${code}</span>
              </div>
              <p style="margin:0;font-size:13px;color:#9ca3af;">If you didn't request this, you can safely ignore this email.</p>
            </td>
          </tr>
          <tr>
            <td style="padding-top:20px;text-align:center;">
              <p style="margin:0;font-size:11px;color:#d1d5db;">BusMate · Password Setup</p>
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
    console.error("auth/send-setup-code error:", err);
    return NextResponse.json({ error: "Failed to send setup code email." }, { status: 500 });
  }

  return NextResponse.json({ sent: true });
}

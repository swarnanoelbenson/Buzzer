import { NextRequest, NextResponse } from "next/server";
import { randomBytes } from "crypto";
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

function generateToken(): string {
  return randomBytes(32).toString("hex");
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { email, pendingSignup, origin } = body as {
    email: string;
    pendingSignup?: {
      schoolName: string;
      schoolNameLower: string;
      adminName: string;
      email: string;
      isSignup: boolean;
    };
    origin: string;
  };

  if (!email || typeof email !== "string") {
    return NextResponse.json({ error: "Email is required." }, { status: 400 });
  }
  if (!origin || typeof origin !== "string") {
    return NextResponse.json({ error: "Origin is required." }, { status: 400 });
  }

  const normalised = email.trim().toLowerCase();
  const db = getAdminDb();

  // For login: gate on existing school account
  if (!pendingSignup) {
    const snap = await db.collection("schools").where("email", "==", normalised).limit(1).get();
    if (snap.empty) {
      return NextResponse.json({ error: "No account found for this email. Please sign up first." }, { status: 404 });
    }
  }

  // Generate a secure random token with a 15-minute expiry
  const token = generateToken();
  const expiresAt = Timestamp.fromDate(new Date(Date.now() + 15 * 60 * 1000));

  await db.collection("adminSigninTokens").doc(token).set({
    email: normalised,
    expiresAt,
    ...(pendingSignup ? { pendingSignup } : {}),
  });

  const linkUrl = `${origin}/auth-callback?token=${token}&email=${encodeURIComponent(normalised)}`;

  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    return NextResponse.json({ error: "Email service not configured." }, { status: 500 });
  }

  const isSignup = !!pendingSignup;
  const resend = new Resend(resendKey);

  try {
    await resend.emails.send({
      from: "BusMate <onboarding@resend.dev>",
      to: [normalised],
      subject: isSignup ? "Complete your BusMate Admin sign-up" : "Your BusMate Admin sign-in link",
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
              <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;">
                ${isSignup ? "Complete your sign-up" : "Sign in to BusMate Admin"}
              </h2>
              <p style="margin:0 0 28px;font-size:14px;color:#6b7280;">
                Click the button below to ${isSignup ? "create your admin account" : "sign in"}. This link expires in 15 minutes.
              </p>
              <a href="${linkUrl}"
                style="display:inline-block;background:#2563eb;color:white;font-size:15px;font-weight:900;letter-spacing:0.05em;text-decoration:none;padding:14px 32px;border-radius:12px;">
                ${isSignup ? "Create Account" : "Sign In"}
              </a>
              <p style="margin:28px 0 0;font-size:13px;color:#9ca3af;">
                If you didn't request this, you can safely ignore this email.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-top:20px;text-align:center;">
              <p style="margin:0;font-size:11px;color:#d1d5db;">BusMate Admin Console</p>
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
    console.error("admin-signin-link send error:", err);
    return NextResponse.json({ error: "Failed to send sign-in link." }, { status: 500 });
  }

  return NextResponse.json({ sent: true });
}

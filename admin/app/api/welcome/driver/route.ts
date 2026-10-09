import { NextRequest, NextResponse } from "next/server";
import { Resend } from "resend";

const TESTFLIGHT_URL = "https://testflight.apple.com/join/BRfvZxFF";
const WEBSITE_URL = "https://www.busmate.com.au";

export async function POST(req: NextRequest) {
  const { email, driverName, schoolName, phone } = await req.json();

  if (!email || !driverName || !schoolName) {
    return NextResponse.json({ error: "Missing required fields." }, { status: 400 });
  }

  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    return NextResponse.json({ skipped: true });
  }

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body style="margin:0;padding:0;background:#f9fafb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;">

          <!-- Header -->
          <tr>
            <td align="center" style="padding-bottom:24px;">
              <div style="display:inline-block;background:#2563eb;border-radius:16px;padding:12px 20px;">
                <span style="color:white;font-size:16px;font-weight:900;letter-spacing:0.15em;">BUSMATE</span>
              </div>
              <p style="margin:8px 0 0;font-size:11px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Driver App</p>
            </td>
          </tr>

          <!-- Card -->
          <tr>
            <td style="background:white;border-radius:20px;border:1px solid #f3f4f6;padding:32px;">

              <!-- Icon -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;">
                <tr>
                  <td align="center">
                    <div style="width:56px;height:56px;background:#dbeafe;border-radius:16px;display:inline-flex;align-items:center;justify-content:center;">
                      <span style="font-size:28px;">🚌</span>
                    </div>
                  </td>
                </tr>
              </table>

              <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">You're all set, ${driverName}!</h2>
              <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">${schoolName} has added you as a driver on BusMate. Here's what you need to get started.</p>

              <!-- Driver details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;border-radius:12px;padding:16px;margin-bottom:24px;">
                <tr>
                  <td style="padding:6px 0;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">School</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${schoolName}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Driver</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${driverName}</span>
                  </td>
                </tr>
                ${phone ? `<tr>
                  <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Phone</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${phone}</span>
                  </td>
                </tr>` : ""}
              </table>

              <!-- What you do in the app -->
              <p style="margin:0 0 12px;font-size:11px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">How BusMate works for you</p>
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
                <tr>
                  <td style="padding:8px 0;border-bottom:1px solid #f3f4f6;">
                    <span style="font-size:18px;">📋</span>&nbsp;&nbsp;
                    <span style="font-size:14px;font-weight:700;color:#111827;">See your daily trips</span><br>
                    <span style="font-size:13px;color:#6b7280;padding-left:30px;display:block;">Your assigned pick-up and drop-off runs appear automatically each day.</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:8px 0;border-bottom:1px solid #f3f4f6;">
                    <span style="font-size:18px;">✅</span>&nbsp;&nbsp;
                    <span style="font-size:14px;font-weight:700;color:#111827;">Mark attendance</span><br>
                    <span style="font-size:13px;color:#6b7280;padding-left:30px;display:block;">Tap to record each student as on-bus, off-bus, or absent in real time.</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:8px 0;">
                    <span style="font-size:18px;">🗺️</span>&nbsp;&nbsp;
                    <span style="font-size:14px;font-weight:700;color:#111827;">Stop-by-stop route view</span><br>
                    <span style="font-size:13px;color:#6b7280;padding-left:30px;display:block;">See every student's pick-up and drop-off stop in order, so you're always on track.</span>
                  </td>
                </tr>
              </table>

              <!-- CTA -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
                <tr>
                  <td align="center">
                    <a href="${TESTFLIGHT_URL}"
                      style="display:inline-block;background:#2563eb;color:white;font-size:15px;font-weight:900;letter-spacing:0.05em;text-decoration:none;padding:14px 32px;border-radius:12px;">
                      Download the BusMate App
                    </a>
                  </td>
                </tr>
              </table>

              <p style="margin:0 0 8px;font-size:13px;color:#6b7280;text-align:center;">
                Log in with your phone number — no password needed.
              </p>

              <p style="margin:16px 0 0;font-size:13px;color:#6b7280;text-align:center;">
                Need help? Visit <a href="${WEBSITE_URL}" style="color:#2563eb;text-decoration:none;font-weight:700;">busmate.com.au</a>
              </p>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding-top:20px;text-align:center;">
              <p style="margin:0;font-size:11px;color:#d1d5db;">BusMate · Driver Welcome</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim();

  try {
    const resend = new Resend(resendKey);
    await resend.emails.send({
      from: "BusMate <noreply@updates.busmate.com.au>",
      to: [email],
      subject: `Welcome to BusMate — You're all set, ${driverName}`,
      html,
    });
    return NextResponse.json({ sent: true });
  } catch (err) {
    console.error("welcome/driver email error:", err);
    return NextResponse.json({ error: "Email failed to send." }, { status: 500 });
  }
}

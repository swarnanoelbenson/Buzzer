import { NextRequest, NextResponse } from "next/server";
import { Resend } from "resend";

export async function POST(req: NextRequest) {
  const { email, displayName, schoolName, timestamp } = await req.json();

  if (!email || !schoolName) {
    return NextResponse.json({ error: "Missing required fields." }, { status: 400 });
  }

  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    // Silently skip if Resend not configured — don't break the login flow
    return NextResponse.json({ skipped: true });
  }

  const loginTime = timestamp
    ? new Date(timestamp).toLocaleString("en-AU", {
        dateStyle: "full",
        timeStyle: "short",
        timeZone: "Australia/Sydney",
      })
    : new Date().toLocaleString("en-AU", {
        dateStyle: "full",
        timeStyle: "short",
        timeZone: "Australia/Sydney",
      });

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
              <p style="margin:8px 0 0;font-size:11px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Admin Console</p>
            </td>
          </tr>

          <!-- Card -->
          <tr>
            <td style="background:white;border-radius:20px;border:1px solid #f3f4f6;padding:32px;">

              <!-- Icon row -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;">
                <tr>
                  <td align="center">
                    <div style="width:56px;height:56px;background:#dbeafe;border-radius:16px;display:inline-flex;align-items:center;justify-content:center;">
                      <span style="font-size:28px;">🔐</span>
                    </div>
                  </td>
                </tr>
              </table>

              <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">New Sign-In Detected</h2>
              <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">A sign-in to your BusMate Admin Console account was recorded.</p>

              <!-- Details box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;border-radius:12px;padding:16px;margin-bottom:24px;">
                <tr>
                  <td style="padding:6px 0;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">School</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${schoolName}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Admin</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${displayName ?? email}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Email</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${email}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Time</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${loginTime}</span>
                  </td>
                </tr>
              </table>

              <p style="margin:0;font-size:13px;color:#6b7280;text-align:center;">
                If this wasn't you, please change your password immediately.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding-top:20px;text-align:center;">
              <p style="margin:0;font-size:11px;color:#d1d5db;">BusMate Admin Console · Automated security notification</p>
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
      subject: `New sign-in to BusMate — ${schoolName}`,
      html,
    });

    return NextResponse.json({ sent: true });
  } catch (err) {
    console.error("notify-login email error:", err);
    // Don't break the login flow if email fails
    return NextResponse.json({ error: "Email failed to send." }, { status: 500 });
  }
}

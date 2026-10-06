import { NextRequest, NextResponse } from "next/server";
import { Resend } from "resend";

const TESTFLIGHT_URL = "https://testflight.apple.com/join/BRfvZxFF";
const WEBSITE_URL = "https://www.busmate.com.au";

interface StudentWelcome {
  studentName: string;
  studentEmail: string;
  grade: string;
  stopAM: string;
  stopPM: string;
  pickupTime: string;
  dropoffTime: string;
  routeName: string;
  term: number;
  year: number;
}

interface ParentWelcome {
  parentName: string;
  parentEmail: string;
  studentName: string;
  grade: string;
  stopAM: string;
  stopPM: string;
  pickupTime: string;
  dropoffTime: string;
  routeName: string;
  term: number;
  year: number;
  schoolName: string;
}

function buildStudentHtml(s: StudentWelcome): string {
  return `
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
              <p style="margin:8px 0 0;font-size:11px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Student App</p>
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
                      <span style="font-size:28px;">🎒</span>
                    </div>
                  </td>
                </tr>
              </table>

              <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">You're on the bus, ${s.studentName}!</h2>
              <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">Your school has set up your bus route for Term ${s.term} ${s.year}. Here are your details.</p>

              <!-- Route details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;border-radius:12px;padding:16px;margin-bottom:24px;">
                <tr>
                  <td style="padding:6px 0;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Route</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${s.routeName}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Grade</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${s.grade || "—"}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Morning Pick-up</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${s.stopAM || "—"}</span>
                    ${s.pickupTime ? `<span style="font-size:12px;color:#6b7280;"> · ${s.pickupTime}</span>` : ""}
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Afternoon Drop-off</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${s.stopPM || "—"}</span>
                    ${s.dropoffTime ? `<span style="font-size:12px;color:#6b7280;"> · ${s.dropoffTime}</span>` : ""}
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
                More info at <a href="${WEBSITE_URL}" style="color:#2563eb;text-decoration:none;font-weight:700;">busmate.com.au</a>
              </p>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding-top:20px;text-align:center;">
              <p style="margin:0;font-size:11px;color:#d1d5db;">BusMate · Student Welcome</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim();
}

function buildParentHtml(p: ParentWelcome): string {
  return `
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
              <p style="margin:8px 0 0;font-size:11px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Parent App</p>
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
                      <span style="font-size:28px;">👨‍👩‍👧</span>
                    </div>
                  </td>
                </tr>
              </table>

              <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">Welcome to BusMate, ${p.parentName}!</h2>
              <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">${p.schoolName} has enrolled ${p.studentName} on a bus route for Term ${p.term} ${p.year}. Track your child's journey in real time.</p>

              <!-- Child details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;border-radius:12px;padding:16px;margin-bottom:24px;">
                <tr>
                  <td style="padding:6px 0;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Child</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${p.studentName}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Route</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${p.routeName} · Term ${p.term} ${p.year}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Morning Pick-up</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${p.stopAM || "—"}</span>
                    ${p.pickupTime ? `<span style="font-size:12px;color:#6b7280;"> · ${p.pickupTime}</span>` : ""}
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
                    <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Afternoon Drop-off</span><br>
                    <span style="font-size:14px;font-weight:700;color:#111827;">${p.stopPM || "—"}</span>
                    ${p.dropoffTime ? `<span style="font-size:12px;color:#6b7280;"> · ${p.dropoffTime}</span>` : ""}
                  </td>
                </tr>
              </table>

              <!-- What you can do -->
              <p style="margin:0 0 12px;font-size:11px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">What you can do in the app</p>
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
                <tr>
                  <td style="padding:8px 0;border-bottom:1px solid #f3f4f6;">
                    <span style="font-size:18px;">📍</span>&nbsp;&nbsp;
                    <span style="font-size:14px;font-weight:700;color:#111827;">Live bus status</span><br>
                    <span style="font-size:13px;color:#6b7280;padding-left:30px;display:block;">See exactly when your child boards and leaves the bus.</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:8px 0;border-bottom:1px solid #f3f4f6;">
                    <span style="font-size:18px;">📝</span>&nbsp;&nbsp;
                    <span style="font-size:14px;font-weight:700;color:#111827;">Add absence notes</span><br>
                    <span style="font-size:13px;color:#6b7280;padding-left:30px;display:block;">Let the driver know if your child won't be on the bus on a given day.</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:8px 0;">
                    <span style="font-size:18px;">🔔</span>&nbsp;&nbsp;
                    <span style="font-size:14px;font-weight:700;color:#111827;">Push notifications</span><br>
                    <span style="font-size:13px;color:#6b7280;padding-left:30px;display:block;">Get notified the moment your child is marked on or off the bus.</span>
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
                More info at <a href="${WEBSITE_URL}" style="color:#2563eb;text-decoration:none;font-weight:700;">busmate.com.au</a>
              </p>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding-top:20px;text-align:center;">
              <p style="margin:0;font-size:11px;color:#d1d5db;">BusMate · Parent Welcome</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim();
}

export async function POST(req: NextRequest) {
  const { students, parents, routeName, term, year, schoolName } = await req.json() as {
    students: StudentWelcome[];
    parents: ParentWelcome[];
    routeName: string;
    term: number;
    year: number;
    schoolName: string;
  };

  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    return NextResponse.json({ skipped: true });
  }

  const resend = new Resend(resendKey);
  const errors: string[] = [];

  // Send student emails (fire-and-forget per recipient)
  for (const s of students ?? []) {
    if (!s.studentEmail) continue;
    try {
      await resend.emails.send({
        from: "BusMate <onboarding@resend.dev>",
        to: [s.studentEmail],
        subject: `You're on the bus — BusMate Term ${s.term} ${s.year}`,
        html: buildStudentHtml(s),
      });
    } catch (err) {
      console.error("welcome/route student email error:", err);
      errors.push(`student:${s.studentEmail}`);
    }
  }

  // Send parent emails
  for (const p of parents ?? []) {
    if (!p.parentEmail) continue;
    try {
      await resend.emails.send({
        from: "BusMate <onboarding@resend.dev>",
        to: [p.parentEmail],
        subject: `${p.studentName} is on the bus — BusMate ${schoolName}`,
        html: buildParentHtml(p),
      });
    } catch (err) {
      console.error("welcome/route parent email error:", err);
      errors.push(`parent:${p.parentEmail}`);
    }
  }

  return NextResponse.json({ sent: true, errors: errors.length > 0 ? errors : undefined });
}

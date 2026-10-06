import { NextRequest, NextResponse } from "next/server";
import { Resend } from "resend";

// ── Types ─────────────────────────────────────────────────────────────────────

interface StudentRow {
  name: string;
  grade: string;
  studentPhone: string;
  studentEmail: string;
  orderAM: string;
  pickupTime: string;
  stopAM: string;
  orderPM: string;
  dropoffTime: string;
  stopPM: string;
  parentName: string;
  parentPhone: string;
  parentEmail: string;
  relationship: string;
}

interface GenerateAndNotifyPayload {
  schoolName: string;
  routeName: string;
  term: number;
  year: number;
  busRego: string;
  driverName: string;
  driverPhone: string;
  driverEmail?: string;
  adminEmail?: string;
  students: StudentRow[];
}

interface NotifyResult {
  driver: { sent: boolean; skipped: boolean };
  parents: { sent: number; skipped: number };
  students: { sent: number; skipped: number };
}

// Note: PDF generation has been removed from this route.
// Emails are sent as HTML-only to stay within Vercel's serverless function
// timeout. Attaching a PDF to every email in a sequential loop causes the
// function to exceed the 10-second limit for rosters with >3-4 students.

// ── HTML email builders ───────────────────────────────────────────────────────

const LOGO_BLOCK = `
  <div style="display:inline-block;background:#2563eb;border-radius:16px;padding:12px 20px;">
    <span style="color:white;font-size:16px;font-weight:900;letter-spacing:0.15em;">BUSMATE</span>
  </div>
  <p style="margin:8px 0 0;font-size:11px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Schedule Notification</p>
`;

function detailsBox(rows: { label: string; value: string }[]): string {
  return `
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;border-radius:12px;padding:16px;margin-bottom:24px;">
      ${rows.map((r, i) => `
        <tr>
          <td style="padding:6px 0;${i > 0 ? "border-top:1px solid #e5e7eb;" : ""}">
            <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">${r.label}</span><br>
            <span style="font-size:14px;font-weight:700;color:#111827;">${r.value || "—"}</span>
          </td>
        </tr>
      `).join("")}
    </table>
  `;
}

function wrap(subtitle: string, body: string): string {
  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f9fafb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;">
          <tr>
            <td align="center" style="padding-bottom:24px;">
              ${LOGO_BLOCK}
            </td>
          </tr>
          <tr>
            <td style="background:white;border-radius:20px;border:1px solid #f3f4f6;padding:32px;">
              ${body}
            </td>
          </tr>
          <tr>
            <td style="padding-top:20px;text-align:center;">
              <p style="margin:0;font-size:11px;color:#d1d5db;">BusMate · ${subtitle}</p>
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

function driverHtml(p: GenerateAndNotifyPayload): string {
  const body = `
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;">
      <tr><td align="center">
        <div style="width:56px;height:56px;background:#dbeafe;border-radius:16px;display:inline-flex;align-items:center;justify-content:center;">
          <span style="font-size:28px;">🚌</span>
        </div>
      </td></tr>
    </table>
    <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">New schedule ready, ${p.driverName}!</h2>
    <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">
      A new schedule has been published for <strong>${p.schoolName}</strong>. Check out the full student list in the attached PDF.
    </p>
    ${detailsBox([
      { label: "Route", value: p.routeName },
      { label: "Term / Year", value: `Term ${p.term} · ${p.year}` },
      { label: "Bus Registration", value: p.busRego },
      { label: "School", value: p.schoolName },
    ])}
    <p style="margin:0;font-size:13px;color:#6b7280;text-align:center;">
      The full student schedule is attached as a PDF. Open the BusMate app to see your upcoming trips.
    </p>
  `;
  return wrap("Driver Schedule Notification", body);
}

function studentHtml(p: GenerateAndNotifyPayload, row: StudentRow): string {
  const body = `
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;">
      <tr><td align="center">
        <div style="width:56px;height:56px;background:#dbeafe;border-radius:16px;display:inline-flex;align-items:center;justify-content:center;">
          <span style="font-size:28px;">🎒</span>
        </div>
      </td></tr>
    </table>
    <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">Your schedule is ready, ${row.name}! 🎉</h2>
    <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">
      Hey ${row.name}! Your bus service schedule for <strong>Term ${p.term} ${p.year}</strong> at <strong>${p.schoolName}</strong> is confirmed and ready to go!
    </p>
    ${detailsBox([
      { label: "School", value: p.schoolName },
      { label: "Route", value: p.routeName },
      { label: "Term / Year", value: `Term ${p.term} · ${p.year}` },
      { label: "Bus Registration", value: p.busRego },
      { label: "Driver", value: p.driverName },
      { label: "Driver Phone", value: p.driverPhone },
    ])}
    <p style="margin:0;font-size:13px;color:#6b7280;text-align:center;">
      Your full schedule — including pick-up times and stop locations — is attached as a PDF. See you on the bus! 🚌
    </p>
  `;
  return wrap("Student Schedule Notification", body);
}

function parentHtml(p: GenerateAndNotifyPayload, row: StudentRow): string {
  const body = `
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;">
      <tr><td align="center">
        <div style="width:56px;height:56px;background:#dbeafe;border-radius:16px;display:inline-flex;align-items:center;justify-content:center;">
          <span style="font-size:28px;">👨‍👩‍👧</span>
        </div>
      </td></tr>
    </table>
    <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">
      ${row.name}'s schedule is ready! 🎉
    </h2>
    <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">
      Hey ${row.parentName}! <strong>${row.name}</strong>'s bus service schedule for <strong>Term ${p.term} ${p.year}</strong> at <strong>${p.schoolName}</strong> is confirmed!
    </p>
    ${detailsBox([
      { label: "Child", value: row.name },
      { label: "School", value: p.schoolName },
      { label: "Route", value: p.routeName },
      { label: "Term / Year", value: `Term ${p.term} · ${p.year}` },
      { label: "Bus Registration", value: p.busRego },
      { label: "Driver", value: p.driverName },
      { label: "Driver Phone", value: p.driverPhone },
    ])}
    <p style="margin:0;font-size:13px;color:#6b7280;text-align:center;">
      The full schedule — including your child's pick-up and drop-off times — is attached as a PDF.
    </p>
  `;
  return wrap("Parent Schedule Notification", body);
}

// ── Route handler ─────────────────────────────────────────────────────────────

export async function POST(req: NextRequest) {
  const payload = await req.json() as GenerateAndNotifyPayload;
  const { driverEmail, adminEmail, students } = payload;

  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    return NextResponse.json({ skipped: true });
  }

  const resend = new Resend(resendKey);

  const result: NotifyResult = {
    driver: { sent: false, skipped: true },
    parents: { sent: 0, skipped: 0 },
    students: { sent: 0, skipped: 0 },
  };

  // ── Driver email (CC admin) — sent first, awaited ─────────────────────────
  if (driverEmail) {
    try {
      const ccList: string[] = [];
      if (adminEmail) ccList.push(adminEmail);
      await resend.emails.send({
        from: "BusMate <onboarding@resend.dev>",
        to: [driverEmail],
        ...(ccList.length > 0 ? { cc: ccList } : {}),
        subject: `New schedule ready — ${payload.routeName} Term ${payload.term} ${payload.year}`,
        html: driverHtml(payload),
      });
      result.driver = { sent: true, skipped: false };
    } catch (err) {
      console.error("schedule/generate-and-notify driver error:", err);
      result.driver = { sent: false, skipped: false };
    }
  }

  // ── Student + parent emails — sent in parallel ────────────────────────────
  const studentJobs = students.map(row => {
    if (!row.studentEmail) {
      result.students.skipped++;
      return Promise.resolve();
    }
    return resend.emails.send({
      from: "BusMate <onboarding@resend.dev>",
      to: [row.studentEmail],
      subject: `Your schedule is ready — ${payload.schoolName} Term ${payload.term} ${payload.year} 🎉`,
      html: studentHtml(payload, row),
    }).then(() => {
      result.students.sent++;
    }).catch((err) => {
      console.error("schedule/generate-and-notify student error:", err);
      result.students.skipped++;
    });
  });

  const parentJobs = students.map(row => {
    if (!row.parentEmail || !row.parentName) {
      result.parents.skipped++;
      return Promise.resolve();
    }
    return resend.emails.send({
      from: "BusMate <onboarding@resend.dev>",
      to: [row.parentEmail],
      subject: `${row.name}'s schedule is ready — ${payload.schoolName} Term ${payload.term} ${payload.year} 🎉`,
      html: parentHtml(payload, row),
    }).then(() => {
      result.parents.sent++;
    }).catch((err) => {
      console.error("schedule/generate-and-notify parent error:", err);
      result.parents.skipped++;
    });
  });

  await Promise.allSettled([...studentJobs, ...parentJobs]);

  return NextResponse.json(result);
}

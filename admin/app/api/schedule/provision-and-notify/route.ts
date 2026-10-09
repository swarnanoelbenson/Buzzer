import { NextRequest, NextResponse } from "next/server";
import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { Resend } from "resend";

// ── Firebase Admin ────────────────────────────────────────────────────────────

function getAdminDb() {
  const app = getApps().length
    ? getApps()[0]
    : initializeApp({ credential: cert(JSON.parse(process.env.FIREBASE_ADMIN_SERVICE_ACCOUNT!)) });
  return getFirestore(app, "busmate-db");
}

// ── Constants ─────────────────────────────────────────────────────────────────

const TESTFLIGHT_URL = "https://testflight.apple.com/join/BRfvZxFF";
const WEBSITE_URL = "https://www.busmate.com.au";

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

interface ProvisionAndNotifyPayload {
  schoolId: string;
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

// ── Email helpers ─────────────────────────────────────────────────────────────

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
            <span style="font-size:14px;font-weight:700;color:#111827;">${r.value || "N/A"}</span>
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

// ── Driver schedule email ─────────────────────────────────────────────────────

function driverScheduleHtml(p: ProvisionAndNotifyPayload): string {
  const body = `
    <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">Schedule update: ${p.routeName}</h2>
    <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">
      A new schedule has been published for <strong>${p.schoolName}</strong>. Your route details are below. Log in to the BusMate app to view your full trip list.
    </p>
    ${detailsBox([
      { label: "Route", value: p.routeName },
      { label: "Term / Year", value: `Term ${p.term}, ${p.year}` },
      { label: "Bus Registration", value: p.busRego },
      { label: "School", value: p.schoolName },
    ])}
    <p style="margin:0;font-size:13px;color:#6b7280;text-align:center;">
      Contact your school administrator if you have any questions.
    </p>
  `;
  return wrap("Driver Schedule Notification", body);
}

// ── Student welcome email (new profile) ──────────────────────────────────────

function studentWelcomeHtml(p: ProvisionAndNotifyPayload, row: StudentRow): string {
  const body = `
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;">
      <tr>
        <td align="center">
          <div style="width:56px;height:56px;background:#dbeafe;border-radius:16px;display:inline-flex;align-items:center;justify-content:center;">
            <span style="font-size:28px;">🎒</span>
          </div>
        </td>
      </tr>
    </table>
    <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">You're on the bus, ${row.name}!</h2>
    <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">
      ${p.schoolName} has set up your bus route for Term ${p.term} ${p.year}. Here are your details.
    </p>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;border-radius:12px;padding:16px;margin-bottom:24px;">
      <tr>
        <td style="padding:6px 0;">
          <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Route</span><br>
          <span style="font-size:14px;font-weight:700;color:#111827;">${p.routeName}</span>
        </td>
      </tr>
      <tr>
        <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
          <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Grade</span><br>
          <span style="font-size:14px;font-weight:700;color:#111827;">${row.grade || "—"}</span>
        </td>
      </tr>
      <tr>
        <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
          <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Morning Pick-up</span><br>
          <span style="font-size:14px;font-weight:700;color:#111827;">${row.stopAM || "—"}</span>
          ${row.pickupTime ? `<span style="font-size:12px;color:#6b7280;"> · ${row.pickupTime}</span>` : ""}
        </td>
      </tr>
      <tr>
        <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
          <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Afternoon Drop-off</span><br>
          <span style="font-size:14px;font-weight:700;color:#111827;">${row.stopPM || "—"}</span>
          ${row.dropoffTime ? `<span style="font-size:12px;color:#6b7280;"> · ${row.dropoffTime}</span>` : ""}
        </td>
      </tr>
    </table>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
      <tr>
        <td align="center">
          <a href="${TESTFLIGHT_URL}" style="display:inline-block;background:#2563eb;color:white;font-size:15px;font-weight:900;letter-spacing:0.05em;text-decoration:none;padding:14px 32px;border-radius:12px;">
            Download the BusMate App
          </a>
        </td>
      </tr>
    </table>
    <p style="margin:0 0 8px;font-size:13px;color:#6b7280;text-align:center;">Log in with your phone number — no password needed.</p>
    <p style="margin:16px 0 0;font-size:13px;color:#6b7280;text-align:center;">
      More info at <a href="${WEBSITE_URL}" style="color:#2563eb;text-decoration:none;font-weight:700;">busmate.com.au</a>
    </p>
  `;
  return wrap("Student Welcome", body);
}

// ── Student schedule email (existing profile) ─────────────────────────────────

function studentScheduleHtml(p: ProvisionAndNotifyPayload, row: StudentRow): string {
  const body = `
    <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">Bus schedule for Term ${p.term} ${p.year}</h2>
    <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">
      ${row.name}, your bus schedule for <strong>Term ${p.term} ${p.year}</strong> at <strong>${p.schoolName}</strong> is confirmed.
    </p>
    ${detailsBox([
      { label: "School", value: p.schoolName },
      { label: "Route", value: p.routeName },
      { label: "Term / Year", value: `Term ${p.term}, ${p.year}` },
      { label: "Bus Registration", value: p.busRego },
      { label: "Driver", value: p.driverName },
      { label: "Driver Phone", value: p.driverPhone },
    ])}
    <p style="margin:0;font-size:13px;color:#6b7280;text-align:center;">
      Log in to the BusMate app to view your full schedule. Contact your school if anything looks incorrect.
    </p>
  `;
  return wrap("Student Schedule Notification", body);
}

// ── Parent welcome email (new profile) ───────────────────────────────────────

function parentWelcomeHtml(p: ProvisionAndNotifyPayload, row: StudentRow): string {
  const body = `
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;">
      <tr>
        <td align="center">
          <div style="width:56px;height:56px;background:#dbeafe;border-radius:16px;display:inline-flex;align-items:center;justify-content:center;">
            <span style="font-size:28px;">👨‍👩‍👧</span>
          </div>
        </td>
      </tr>
    </table>
    <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">Welcome to BusMate, ${row.parentName}!</h2>
    <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">
      ${p.schoolName} has enrolled ${row.name} on a bus route for Term ${p.term} ${p.year}. Track your child's journey in real time.
    </p>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;border-radius:12px;padding:16px;margin-bottom:24px;">
      <tr>
        <td style="padding:6px 0;">
          <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Child</span><br>
          <span style="font-size:14px;font-weight:700;color:#111827;">${row.name}</span>
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
          <span style="font-size:14px;font-weight:700;color:#111827;">${row.stopAM || "—"}</span>
          ${row.pickupTime ? `<span style="font-size:12px;color:#6b7280;"> · ${row.pickupTime}</span>` : ""}
        </td>
      </tr>
      <tr>
        <td style="padding:6px 0;border-top:1px solid #e5e7eb;">
          <span style="font-size:10px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Afternoon Drop-off</span><br>
          <span style="font-size:14px;font-weight:700;color:#111827;">${row.stopPM || "—"}</span>
          ${row.dropoffTime ? `<span style="font-size:12px;color:#6b7280;"> · ${row.dropoffTime}</span>` : ""}
        </td>
      </tr>
    </table>
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
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
      <tr>
        <td align="center">
          <a href="${TESTFLIGHT_URL}" style="display:inline-block;background:#2563eb;color:white;font-size:15px;font-weight:900;letter-spacing:0.05em;text-decoration:none;padding:14px 32px;border-radius:12px;">
            Download the BusMate App
          </a>
        </td>
      </tr>
    </table>
    <p style="margin:0 0 8px;font-size:13px;color:#6b7280;text-align:center;">Log in with your phone number — no password needed.</p>
    <p style="margin:16px 0 0;font-size:13px;color:#6b7280;text-align:center;">
      More info at <a href="${WEBSITE_URL}" style="color:#2563eb;text-decoration:none;font-weight:700;">busmate.com.au</a>
    </p>
  `;
  return wrap("Parent Welcome", body);
}

// ── Parent schedule email (existing profile) ──────────────────────────────────

function parentScheduleHtml(p: ProvisionAndNotifyPayload, row: StudentRow): string {
  const body = `
    <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;text-align:center;">Bus schedule confirmed for ${row.name}</h2>
    <p style="margin:0 0 24px;font-size:14px;color:#6b7280;text-align:center;">
      Hi ${row.parentName}, <strong>${row.name}</strong>'s bus schedule for <strong>Term ${p.term} ${p.year}</strong> at <strong>${p.schoolName}</strong> is confirmed.
    </p>
    ${detailsBox([
      { label: "Child", value: row.name },
      { label: "School", value: p.schoolName },
      { label: "Route", value: p.routeName },
      { label: "Term / Year", value: `Term ${p.term}, ${p.year}` },
      { label: "Bus Registration", value: p.busRego },
      { label: "Driver", value: p.driverName },
      { label: "Driver Phone", value: p.driverPhone },
    ])}
    <p style="margin:0;font-size:13px;color:#6b7280;text-align:center;">
      Contact your school if anything needs to be updated.
    </p>
  `;
  return wrap("Parent Schedule Notification", body);
}

// ── Route handler ─────────────────────────────────────────────────────────────

export async function POST(req: NextRequest) {
  const payload = await req.json() as ProvisionAndNotifyPayload;
  const { schoolId, schoolName, driverEmail, adminEmail, students } = payload;

  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    return NextResponse.json({ skipped: true });
  }

  const resend = new Resend(resendKey);
  const db = getAdminDb();

  const result: NotifyResult = {
    driver: { sent: false, skipped: true },
    parents: { sent: 0, skipped: 0 },
    students: { sent: 0, skipped: 0 },
  };

  // ── Driver email (CC admin) ───────────────────────────────────────────────
  if (driverEmail) {
    try {
      const ccList: string[] = [];
      if (adminEmail) ccList.push(adminEmail);
      await resend.emails.send({
        from: "BusMate <noreply@updates.busmate.com.au>",
        to: [driverEmail],
        ...(ccList.length > 0 ? { cc: ccList } : {}),
        subject: `Schedule update: ${payload.routeName}, Term ${payload.term} ${payload.year}`,
        html: driverScheduleHtml(payload),
      });
      result.driver = { sent: true, skipped: false };
    } catch (err) {
      console.error("provision-and-notify driver error:", err);
      result.driver = { sent: false, skipped: false };
    }
  }

  // ── Check existing students and parents in parallel ───────────────────────
  // For each row, query Firestore by email + schoolId to determine isNew.
  // Rows without an email are skipped entirely (no DB check, no email).

  const studentChecks = students.map(async (row) => {
    if (!row.studentEmail) return { row, isNew: false, skip: true };
    const snap = await db.collection("students")
      .where("schoolId", "==", schoolId)
      .where("email", "==", row.studentEmail.trim().toLowerCase())
      .limit(1)
      .get();
    return { row, isNew: snap.empty, skip: false };
  });

  const parentChecks = students.map(async (row) => {
    if (!row.parentEmail || !row.parentName) return { row, isNew: false, skip: true };
    const snap = await db.collection("parents")
      .where("schoolId", "==", schoolId)
      .where("email", "==", row.parentEmail.trim().toLowerCase())
      .limit(1)
      .get();
    return { row, isNew: snap.empty, skip: false };
  });

  const [studentResults, parentResults] = await Promise.all([
    Promise.all(studentChecks),
    Promise.all(parentChecks),
  ]);

  // ── Build and send student + parent emails in parallel ────────────────────

  const emailJobs: Promise<void>[] = [];

  for (const { row, isNew, skip } of studentResults) {
    if (skip) { result.students.skipped++; continue; }

    if (isNew) {
      // New profile: welcome email + schedule email
      emailJobs.push(
        resend.emails.send({
          from: "BusMate <noreply@updates.busmate.com.au>",
          to: [row.studentEmail],
          subject: `You're on the bus — BusMate Term ${payload.term} ${payload.year}`,
          html: studentWelcomeHtml(payload, row),
        }).then(() => { result.students.sent++; })
          .catch((err) => { console.error("provision-and-notify student welcome error:", err); result.students.skipped++; })
      );
      emailJobs.push(
        resend.emails.send({
          from: "BusMate <noreply@updates.busmate.com.au>",
          to: [row.studentEmail],
          subject: `Bus schedule confirmed: ${schoolName}, Term ${payload.term} ${payload.year}`,
          html: studentScheduleHtml(payload, row),
        }).then(() => {}).catch((err) => { console.error("provision-and-notify student schedule error:", err); })
      );
    } else {
      // Existing profile: schedule email only
      emailJobs.push(
        resend.emails.send({
          from: "BusMate <noreply@updates.busmate.com.au>",
          to: [row.studentEmail],
          subject: `Bus schedule confirmed: ${schoolName}, Term ${payload.term} ${payload.year}`,
          html: studentScheduleHtml(payload, row),
        }).then(() => { result.students.sent++; })
          .catch((err) => { console.error("provision-and-notify student schedule error:", err); result.students.skipped++; })
      );
    }
  }

  for (const { row, isNew, skip } of parentResults) {
    if (skip) { result.parents.skipped++; continue; }

    if (isNew) {
      // New profile: welcome email + schedule email
      emailJobs.push(
        resend.emails.send({
          from: "BusMate <noreply@updates.busmate.com.au>",
          to: [row.parentEmail],
          subject: `${row.name} is on the bus — BusMate ${schoolName}`,
          html: parentWelcomeHtml(payload, row),
        }).then(() => { result.parents.sent++; })
          .catch((err) => { console.error("provision-and-notify parent welcome error:", err); result.parents.skipped++; })
      );
      emailJobs.push(
        resend.emails.send({
          from: "BusMate <noreply@updates.busmate.com.au>",
          to: [row.parentEmail],
          subject: `Bus schedule confirmed for ${row.name}: ${schoolName}, Term ${payload.term} ${payload.year}`,
          html: parentScheduleHtml(payload, row),
        }).then(() => {}).catch((err) => { console.error("provision-and-notify parent schedule error:", err); })
      );
    } else {
      // Existing profile: schedule email only
      emailJobs.push(
        resend.emails.send({
          from: "BusMate <noreply@updates.busmate.com.au>",
          to: [row.parentEmail],
          subject: `Bus schedule confirmed for ${row.name}: ${schoolName}, Term ${payload.term} ${payload.year}`,
          html: parentScheduleHtml(payload, row),
        }).then(() => { result.parents.sent++; })
          .catch((err) => { console.error("provision-and-notify parent schedule error:", err); result.parents.skipped++; })
      );
    }
  }

  await Promise.allSettled(emailJobs);

  return NextResponse.json(result);
}

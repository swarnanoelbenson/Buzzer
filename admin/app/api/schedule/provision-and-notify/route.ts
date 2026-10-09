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

interface NotifyPayload {
  stage: "student-welcome" | "parent-welcome" | "admin-schedule" | "driver-schedule" | "student-schedule" | "parent-schedule";
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

interface StageResult {
  sent: number;
  skipped: number;
  skipReason?: string;
}

// ── Email layout ──────────────────────────────────────────────────────────────

const LOGO_BLOCK = `
  <div style="display:inline-block;background:#2563eb;border-radius:16px;padding:12px 20px;">
    <span style="color:white;font-size:18px;font-weight:900;letter-spacing:0.15em;">BUSMATE</span>
  </div>
  <p style="margin:8px 0 0;font-size:13px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Schedule Notification</p>
`;

function detailsBox(rows: { label: string; value: string }[]): string {
  return `
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;border-radius:12px;padding:16px;margin-bottom:24px;">
      ${rows.map((r, i) => `
        <tr>
          <td style="padding:7px 0;${i > 0 ? "border-top:1px solid #e5e7eb;" : ""}">
            <span style="font-size:11px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">${r.label}</span><br>
            <span style="font-size:16px;font-weight:700;color:#111827;">${r.value || "N/A"}</span>
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
              <p style="margin:0;font-size:12px;color:#d1d5db;">BusMate · ${subtitle}</p>
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

function driverScheduleHtml(p: NotifyPayload): string {
  const body = `
    <h2 style="margin:0 0 8px;font-size:20px;font-weight:900;color:#111827;text-align:center;">Schedule update: ${p.routeName}</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#6b7280;text-align:center;">
      A new schedule has been published for <strong>${p.schoolName}</strong>. Your route details are below. Log in to the BusMate app to view your full trip list.
    </p>
    ${detailsBox([
      { label: "Route", value: p.routeName },
      { label: "Term / Year", value: `Term ${p.term}, ${p.year}` },
      { label: "Bus Registration", value: p.busRego },
      { label: "School", value: p.schoolName },
    ])}
    <p style="margin:0;font-size:14px;color:#6b7280;text-align:center;">
      Contact your school administrator if you have any questions.
    </p>
  `;
  return wrap("Driver Schedule Notification", body);
}

// ── Admin schedule email ──────────────────────────────────────────────────────

function adminScheduleHtml(p: NotifyPayload): string {
  const body = `
    <h2 style="margin:0 0 8px;font-size:20px;font-weight:900;color:#111827;text-align:center;">Schedule created: ${p.routeName}</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#6b7280;text-align:center;">
      A new bus route schedule has been published for <strong>${p.schoolName}</strong>.
    </p>
    ${detailsBox([
      { label: "Route", value: p.routeName },
      { label: "Term / Year", value: `Term ${p.term}, ${p.year}` },
      { label: "Bus Registration", value: p.busRego },
      { label: "Driver", value: p.driverName },
      { label: "Driver Phone", value: p.driverPhone },
      { label: "Students", value: String(p.students.length) },
    ])}
    <p style="margin:0;font-size:14px;color:#6b7280;text-align:center;">
      All students and parents have been notified.
    </p>
  `;
  return wrap("Admin Schedule Summary", body);
}

// ── Student welcome email (new profile) ──────────────────────────────────────

function studentWelcomeHtml(p: NotifyPayload, row: StudentRow): string {
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
    <h2 style="margin:0 0 8px;font-size:20px;font-weight:900;color:#111827;text-align:center;">You're on the bus, ${row.name}!</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#6b7280;text-align:center;">
      ${p.schoolName} has set up your bus route for Term ${p.term} ${p.year}. Here are your details.
    </p>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;border-radius:12px;padding:16px;margin-bottom:24px;">
      <tr>
        <td style="padding:7px 0;">
          <span style="font-size:11px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Route</span><br>
          <span style="font-size:16px;font-weight:700;color:#111827;">${p.routeName}</span>
        </td>
      </tr>
      <tr>
        <td style="padding:7px 0;border-top:1px solid #e5e7eb;">
          <span style="font-size:11px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Grade</span><br>
          <span style="font-size:16px;font-weight:700;color:#111827;">${row.grade || "—"}</span>
        </td>
      </tr>
      <tr>
        <td style="padding:7px 0;border-top:1px solid #e5e7eb;">
          <span style="font-size:11px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Morning Pick-up</span><br>
          <span style="font-size:16px;font-weight:700;color:#111827;">${row.stopAM || "—"}</span>
          ${row.pickupTime ? `<span style="font-size:13px;color:#6b7280;"> · ${row.pickupTime}</span>` : ""}
        </td>
      </tr>
      <tr>
        <td style="padding:7px 0;border-top:1px solid #e5e7eb;">
          <span style="font-size:11px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Afternoon Drop-off</span><br>
          <span style="font-size:16px;font-weight:700;color:#111827;">${row.stopPM || "—"}</span>
          ${row.dropoffTime ? `<span style="font-size:13px;color:#6b7280;"> · ${row.dropoffTime}</span>` : ""}
        </td>
      </tr>
    </table>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
      <tr>
        <td align="center">
          <a href="${TESTFLIGHT_URL}" style="display:inline-block;background:#2563eb;color:white;font-size:16px;font-weight:900;letter-spacing:0.05em;text-decoration:none;padding:14px 32px;border-radius:12px;">
            Download the BusMate App
          </a>
        </td>
      </tr>
    </table>
    <p style="margin:0 0 8px;font-size:14px;color:#6b7280;text-align:center;">Log in with your phone number — no password needed.</p>
    <p style="margin:16px 0 0;font-size:14px;color:#6b7280;text-align:center;">
      More info at <a href="${WEBSITE_URL}" style="color:#2563eb;text-decoration:none;font-weight:700;">busmate.com.au</a>
    </p>
  `;
  return wrap("Student Welcome", body);
}

// ── Student schedule email ────────────────────────────────────────────────────

function studentScheduleHtml(p: NotifyPayload, row: StudentRow): string {
  const body = `
    <h2 style="margin:0 0 8px;font-size:20px;font-weight:900;color:#111827;text-align:center;">Bus schedule for Term ${p.term} ${p.year}</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#6b7280;text-align:center;">
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
    <p style="margin:0;font-size:14px;color:#6b7280;text-align:center;">
      Log in to the BusMate app to view your full schedule. Contact your school if anything looks incorrect.
    </p>
  `;
  return wrap("Student Schedule Notification", body);
}

// ── Parent welcome email (new profile) ───────────────────────────────────────

function parentWelcomeHtml(p: NotifyPayload, row: StudentRow): string {
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
    <h2 style="margin:0 0 8px;font-size:20px;font-weight:900;color:#111827;text-align:center;">Welcome to BusMate, ${row.parentName}!</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#6b7280;text-align:center;">
      ${p.schoolName} has enrolled ${row.name} on a bus route for Term ${p.term} ${p.year}. Track your child's journey in real time.
    </p>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;border-radius:12px;padding:16px;margin-bottom:24px;">
      <tr>
        <td style="padding:7px 0;">
          <span style="font-size:11px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Child</span><br>
          <span style="font-size:16px;font-weight:700;color:#111827;">${row.name}</span>
        </td>
      </tr>
      <tr>
        <td style="padding:7px 0;border-top:1px solid #e5e7eb;">
          <span style="font-size:11px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Route</span><br>
          <span style="font-size:16px;font-weight:700;color:#111827;">${p.routeName} · Term ${p.term} ${p.year}</span>
        </td>
      </tr>
      <tr>
        <td style="padding:7px 0;border-top:1px solid #e5e7eb;">
          <span style="font-size:11px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Morning Pick-up</span><br>
          <span style="font-size:16px;font-weight:700;color:#111827;">${row.stopAM || "—"}</span>
          ${row.pickupTime ? `<span style="font-size:13px;color:#6b7280;"> · ${row.pickupTime}</span>` : ""}
        </td>
      </tr>
      <tr>
        <td style="padding:7px 0;border-top:1px solid #e5e7eb;">
          <span style="font-size:11px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">Afternoon Drop-off</span><br>
          <span style="font-size:16px;font-weight:700;color:#111827;">${row.stopPM || "—"}</span>
          ${row.dropoffTime ? `<span style="font-size:13px;color:#6b7280;"> · ${row.dropoffTime}</span>` : ""}
        </td>
      </tr>
    </table>
    <p style="margin:0 0 12px;font-size:12px;font-weight:900;letter-spacing:0.12em;text-transform:uppercase;color:#9ca3af;">What you can do in the app</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
      <tr>
        <td style="padding:8px 0;border-bottom:1px solid #f3f4f6;">
          <span style="font-size:18px;">📍</span>&nbsp;&nbsp;
          <span style="font-size:15px;font-weight:700;color:#111827;">Live bus status</span><br>
          <span style="font-size:14px;color:#6b7280;padding-left:30px;display:block;">See exactly when your child boards and leaves the bus.</span>
        </td>
      </tr>
      <tr>
        <td style="padding:8px 0;border-bottom:1px solid #f3f4f6;">
          <span style="font-size:18px;">📝</span>&nbsp;&nbsp;
          <span style="font-size:15px;font-weight:700;color:#111827;">Add absence notes</span><br>
          <span style="font-size:14px;color:#6b7280;padding-left:30px;display:block;">Let the driver know if your child won't be on the bus on a given day.</span>
        </td>
      </tr>
      <tr>
        <td style="padding:8px 0;">
          <span style="font-size:18px;">🔔</span>&nbsp;&nbsp;
          <span style="font-size:15px;font-weight:700;color:#111827;">Push notifications</span><br>
          <span style="font-size:14px;color:#6b7280;padding-left:30px;display:block;">Get notified the moment your child is marked on or off the bus.</span>
        </td>
      </tr>
    </table>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
      <tr>
        <td align="center">
          <a href="${TESTFLIGHT_URL}" style="display:inline-block;background:#2563eb;color:white;font-size:16px;font-weight:900;letter-spacing:0.05em;text-decoration:none;padding:14px 32px;border-radius:12px;">
            Download the BusMate App
          </a>
        </td>
      </tr>
    </table>
    <p style="margin:0 0 8px;font-size:14px;color:#6b7280;text-align:center;">Log in with your phone number — no password needed.</p>
    <p style="margin:16px 0 0;font-size:14px;color:#6b7280;text-align:center;">
      More info at <a href="${WEBSITE_URL}" style="color:#2563eb;text-decoration:none;font-weight:700;">busmate.com.au</a>
    </p>
  `;
  return wrap("Parent Welcome", body);
}

// ── Parent schedule email ─────────────────────────────────────────────────────

function parentScheduleHtml(p: NotifyPayload, row: StudentRow): string {
  const body = `
    <h2 style="margin:0 0 8px;font-size:20px;font-weight:900;color:#111827;text-align:center;">Bus schedule confirmed for ${row.name}</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#6b7280;text-align:center;">
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
    <p style="margin:0;font-size:14px;color:#6b7280;text-align:center;">
      Contact your school if anything needs to be updated.
    </p>
  `;
  return wrap("Parent Schedule Notification", body);
}

// ── Route handler ─────────────────────────────────────────────────────────────

export async function POST(req: NextRequest) {
  const payload = await req.json() as NotifyPayload;
  const { stage, schoolId, students } = payload;

  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    return NextResponse.json({ skipped: true });
  }

  const resend = new Resend(resendKey);
  const db = getAdminDb();
  const result: StageResult = { sent: 0, skipped: 0 };

  // ── stage: student-welcome ────────────────────────────────────────────────
  if (stage === "student-welcome") {
    for (const row of students) {
      if (!row.studentEmail?.trim()) { result.skipped++; continue; }
      const snap = await db.collection("students")
        .where("schoolId", "==", schoolId)
        .where("email", "==", row.studentEmail.trim().toLowerCase())
        .limit(1).get();
      if (!snap.empty) { result.skipped++; continue; } // existing — skip welcome
      try {
        await resend.emails.send({
          from: "BusMate <noreply@updates.busmate.com.au>",
          to: [row.studentEmail],
          subject: `You're on the bus — BusMate Term ${payload.term} ${payload.year}`,
          html: studentWelcomeHtml(payload, row),
        });
        result.sent++;
      } catch (err) {
        console.error("student-welcome error:", err);
        result.skipped++;
      }
    }
    return NextResponse.json(result);
  }

  // ── stage: parent-welcome ─────────────────────────────────────────────────
  if (stage === "parent-welcome") {
    const seenParentEmails = new Set<string>();
    for (const row of students) {
      if (!row.parentEmail?.trim() || !row.parentName?.trim()) { result.skipped++; continue; }
      const email = row.parentEmail.trim().toLowerCase();
      if (seenParentEmails.has(email)) continue; // deduplicate shared parent emails
      seenParentEmails.add(email);
      const snap = await db.collection("parents")
        .where("schoolId", "==", schoolId)
        .where("email", "==", email)
        .limit(1).get();
      if (!snap.empty) { result.skipped++; continue; } // existing — skip welcome
      try {
        await resend.emails.send({
          from: "BusMate <noreply@updates.busmate.com.au>",
          to: [row.parentEmail],
          subject: `${row.name} is on the bus — BusMate ${payload.schoolName}`,
          html: parentWelcomeHtml(payload, row),
        });
        result.sent++;
      } catch (err) {
        console.error("parent-welcome error:", err);
        result.skipped++;
      }
    }
    return NextResponse.json(result);
  }

  // ── stage: admin-schedule ─────────────────────────────────────────────────
  if (stage === "admin-schedule") {
    if (!payload.adminEmail) {
      return NextResponse.json({ sent: 0, skipped: 1, skipReason: "No admin email on file" });
    }
    try {
      await resend.emails.send({
        from: "BusMate <noreply@updates.busmate.com.au>",
        to: [payload.adminEmail],
        subject: `Schedule created: ${payload.routeName}, Term ${payload.term} ${payload.year}`,
        html: adminScheduleHtml(payload),
      });
      result.sent++;
    } catch (err) {
      console.error("admin-schedule error:", err);
      result.skipped++;
    }
    return NextResponse.json(result);
  }

  // ── stage: driver-schedule ────────────────────────────────────────────────
  if (stage === "driver-schedule") {
    if (!payload.driverEmail) {
      return NextResponse.json({ sent: 0, skipped: 1, skipReason: "Driver has no email on file" });
    }
    try {
      await resend.emails.send({
        from: "BusMate <noreply@updates.busmate.com.au>",
        to: [payload.driverEmail],
        subject: `Schedule update: ${payload.routeName}, Term ${payload.term} ${payload.year}`,
        html: driverScheduleHtml(payload),
      });
      result.sent++;
    } catch (err) {
      console.error("driver-schedule error:", err);
      result.skipped++;
    }
    return NextResponse.json(result);
  }

  // ── stage: student-schedule ───────────────────────────────────────────────
  if (stage === "student-schedule") {
    const jobs = students.map(async (row) => {
      if (!row.studentEmail?.trim()) { result.skipped++; return; }
      try {
        await resend.emails.send({
          from: "BusMate <noreply@updates.busmate.com.au>",
          to: [row.studentEmail],
          subject: `Bus schedule confirmed: ${payload.schoolName}, Term ${payload.term} ${payload.year}`,
          html: studentScheduleHtml(payload, row),
        });
        result.sent++;
      } catch (err) {
        console.error("student-schedule error:", err);
        result.skipped++;
      }
    });
    await Promise.allSettled(jobs);
    return NextResponse.json(result);
  }

  // ── stage: parent-schedule ────────────────────────────────────────────────
  if (stage === "parent-schedule") {
    const seenParentEmails = new Set<string>();
    const jobs = students.map(async (row) => {
      if (!row.parentEmail?.trim() || !row.parentName?.trim()) { result.skipped++; return; }
      const email = row.parentEmail.trim().toLowerCase();
      if (seenParentEmails.has(email)) return; // deduplicate shared parent emails
      seenParentEmails.add(email);
      try {
        await resend.emails.send({
          from: "BusMate <noreply@updates.busmate.com.au>",
          to: [row.parentEmail],
          subject: `Bus schedule confirmed for ${row.name}: ${payload.schoolName}, Term ${payload.term} ${payload.year}`,
          html: parentScheduleHtml(payload, row),
        });
        result.sent++;
      } catch (err) {
        console.error("parent-schedule error:", err);
        result.skipped++;
      }
    });
    await Promise.allSettled(jobs);
    return NextResponse.json(result);
  }

  return NextResponse.json({ error: "Unknown stage" }, { status: 400 });
}

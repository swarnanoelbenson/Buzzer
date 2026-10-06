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

// ── PDF generation (server-side) ──────────────────────────────────────────────

const PDF_COLS = [
  "Student Name", "Grade", "Student Phone", "Student Email",
  "Order AM", "Schedule AM", "Stop AM",
  "Order PM", "Schedule PM", "Stop PM",
  "Parent Name", "Parent Phone", "Parent Email", "Relationship",
];

async function buildPdfBase64(p: GenerateAndNotifyPayload): Promise<string> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const pdfMake = require("pdfmake/build/pdfmake");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const pdfFonts = require("pdfmake/build/vfs_fonts");
  pdfMake.vfs = pdfFonts.vfs;

  const tableBody = [
    PDF_COLS.map(h => ({ text: h, style: "th" })),
    ...p.students.map(r => [
      r.name, r.grade, r.studentPhone, r.studentEmail,
      r.orderAM, r.pickupTime, r.stopAM,
      r.orderPM, r.dropoffTime, r.stopPM,
      r.parentName, r.parentPhone, r.parentEmail, r.relationship,
    ].map(v => ({ text: v || "—", style: "td" }))),
  ];

  const docDef = {
    pageOrientation: "landscape",
    pageMargins: [24, 24, 24, 24],
    content: [
      { text: `BusMate Schedule — ${p.schoolName}`, style: "title" },
      {
        columns: [
          [
            { text: `Route: ${p.routeName}`, style: "meta" },
            { text: `Term ${p.term} · ${p.year}`, style: "meta" },
            { text: `Bus Registration: ${p.busRego || "—"}`, style: "meta" },
          ],
          [
            { text: `Driver: ${p.driverName}`, style: "meta" },
            { text: `Driver Phone: ${p.driverPhone || "—"}`, style: "meta" },
          ],
        ],
        margin: [0, 4, 0, 12],
      },
      {
        table: { headerRows: 1, widths: Array(14).fill("*"), body: tableBody },
        layout: {
          hLineWidth: (i: number) => i === 0 || i === 1 ? 1.5 : 0.5,
          vLineWidth: () => 0.5,
          hLineColor: () => "#e5e7eb",
          vLineColor: () => "#e5e7eb",
          fillColor: (i: number) => i === 0 ? "#2563eb" : i % 2 === 0 ? "#f9fafb" : null,
        },
      },
    ],
    styles: {
      title: { fontSize: 14, bold: true, color: "#111827", margin: [0, 0, 0, 6] },
      meta: { fontSize: 9, color: "#6b7280", margin: [0, 1, 0, 1] },
      th: { fontSize: 7, bold: true, color: "#ffffff", margin: [3, 4, 3, 4] },
      td: { fontSize: 7, color: "#374151", margin: [3, 3, 3, 3] },
    },
  };

  return new Promise((resolve, reject) => {
    const pdf = pdfMake.createPdf(docDef);
    pdf.getBase64((base64: string) => {
      if (!base64) { reject(new Error("pdfmake returned empty base64")); return; }
      resolve(base64);
    });
  });
}

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

  // Generate PDF on the server
  let pdfBase64: string;
  try {
    pdfBase64 = await buildPdfBase64(payload);
  } catch (err) {
    console.error("schedule/generate-and-notify PDF error:", err);
    return NextResponse.json({ error: "PDF generation failed" }, { status: 500 });
  }

  const resend = new Resend(resendKey);

  const pdfFilename = `BusMate_Schedule_${payload.routeName.replace(/\s+/g, "_")}_Term${payload.term}_${payload.year}.pdf`;
  const pdfAttachment = {
    filename: pdfFilename,
    content: pdfBase64,
    type: "application/pdf",
    disposition: "attachment" as const,
  };

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
        from: "BusMate <onboarding@resend.dev>",
        to: [driverEmail],
        ...(ccList.length > 0 ? { cc: ccList } : {}),
        subject: `New schedule ready — ${payload.routeName} Term ${payload.term} ${payload.year}`,
        html: driverHtml(payload),
        attachments: [pdfAttachment],
      });
      result.driver = { sent: true, skipped: false };
    } catch (err) {
      console.error("schedule/generate-and-notify driver error:", err);
      result.driver = { sent: false, skipped: false };
    }
  }

  // ── Student emails ────────────────────────────────────────────────────────
  for (const row of students) {
    if (row.studentEmail) {
      try {
        await resend.emails.send({
          from: "BusMate <onboarding@resend.dev>",
          to: [row.studentEmail],
          subject: `Your schedule is ready — ${payload.schoolName} Term ${payload.term} ${payload.year} 🎉`,
          html: studentHtml(payload, row),
          attachments: [pdfAttachment],
        });
        result.students.sent++;
      } catch (err) {
        console.error("schedule/generate-and-notify student error:", err);
        result.students.skipped++;
      }
    } else {
      result.students.skipped++;
    }
  }

  // ── Parent emails ─────────────────────────────────────────────────────────
  for (const row of students) {
    if (row.parentEmail && row.parentName) {
      try {
        await resend.emails.send({
          from: "BusMate <onboarding@resend.dev>",
          to: [row.parentEmail],
          subject: `${row.name}'s schedule is ready — ${payload.schoolName} Term ${payload.term} ${payload.year} 🎉`,
          html: parentHtml(payload, row),
          attachments: [pdfAttachment],
        });
        result.parents.sent++;
      } catch (err) {
        console.error("schedule/generate-and-notify parent error:", err);
        result.parents.skipped++;
      }
    } else {
      result.parents.skipped++;
    }
  }

  return NextResponse.json(result);
}

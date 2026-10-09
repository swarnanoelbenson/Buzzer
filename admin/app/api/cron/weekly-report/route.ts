import { NextRequest, NextResponse } from "next/server";
import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, Timestamp, WriteBatch } from "firebase-admin/firestore";
import { Resend } from "resend";
import ExcelJS from "exceljs";

// ─── Firebase Admin ───────────────────────────────────────────────────────────

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

// ─── Helpers ──────────────────────────────────────────────────────────────────

function toDate(val: unknown): Date | null {
  if (!val) return null;
  if (val instanceof Timestamp) return val.toDate();
  if (val instanceof Date) return val;
  if (typeof val === "string") return new Date(val);
  return null;
}

function formatTime(val: unknown): string {
  const d = toDate(val);
  if (!d) return "";
  return d.toLocaleTimeString("en-AU", {
    timeZone: "Australia/Sydney",
    hour: "2-digit",
    minute: "2-digit",
    hour12: true,
  });
}

function formatDate(val: unknown): string {
  const d = toDate(val);
  return d ? d.toLocaleDateString("en-AU", { timeZone: "Australia/Sydney" }) : "";
}

/** Returns Mon–Fri dates for the past week (run on Saturday morning AEST). */
function getWeekRange(): { from: Date; to: Date; weekDates: Date[] } {
  const now = new Date();
  const aestOffset = 10 * 60 * 60 * 1000;
  const nowAest = new Date(now.getTime() + aestOffset);

  const dayOfWeek = nowAest.getUTCDay();
  const daysToLastMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  const mondayAest = new Date(nowAest);
  mondayAest.setUTCDate(nowAest.getUTCDate() - daysToLastMonday);
  mondayAest.setUTCHours(0, 0, 0, 0);

  const fridayAest = new Date(mondayAest);
  fridayAest.setUTCDate(mondayAest.getUTCDate() + 4);
  fridayAest.setUTCHours(23, 59, 59, 999);

  // Build Mon–Fri as UTC Dates (midnight AEST = 14:00 UTC day before)
  const weekDates: Date[] = [];
  for (let i = 0; i < 5; i++) {
    const d = new Date(mondayAest);
    d.setUTCDate(mondayAest.getUTCDate() + i);
    weekDates.push(new Date(d.getTime() - aestOffset));
  }

  const from = new Date(mondayAest.getTime() - aestOffset);
  const to = new Date(fridayAest.getTime() - aestOffset);

  return { from, to, weekDates };
}

/** Batch-delete Firestore documents in chunks of 500. */
async function batchDelete(
  db: ReturnType<typeof getFirestore>,
  refs: FirebaseFirestore.DocumentReference[]
): Promise<void> {
  const CHUNK = 500;
  for (let i = 0; i < refs.length; i += CHUNK) {
    const batch: WriteBatch = db.batch();
    refs.slice(i, i + CHUNK).forEach((r) => batch.delete(r));
    await batch.commit();
  }
}

// ─── Types ────────────────────────────────────────────────────────────────────

interface StudentDoc {
  id: string;
  name: string;
  grade: string;
  orderAM?: number;
  orderPM?: number;
  scheduledPickupTime: string;
  scheduledDropoffTime: string;
  stopAddressAM: string;
  stopAddressPM: string;
  authorisedParentIds: string[];
}

interface RouteDoc {
  id: string;
  name: string;
  driverId: string;
  busRegistration?: string;
  studentIds: string[];
}

interface DriverDoc {
  id: string;
  name: string;
  phone: string;
  email?: string;
}

interface ParentDoc {
  id: string;
  name: string;
  phone: string;
  relationship: string;
}

interface NoteRow {
  studentName: string;
  noteText: string;
  type: string;
  fromDate: string;
  toDate: string;
  createdByName: string;
  createdByRole: string;
}

// ─── Knox colours ─────────────────────────────────────────────────────────────

const BLUE_HEADER = "FF2563EB";      // Blue-600 — title / header row bg
const BLUE_LIGHT  = "FFEFF6FF";      // Blue-50  — alternating row shading
const WHITE       = "FFFFFFFF";
const HEADER_TEXT = "FFFFFFFF";      // White text on blue header
const DARK_TEXT   = "FF111827";      // Near-black body text

function headerFill(): ExcelJS.Fill {
  return { type: "pattern", pattern: "solid", fgColor: { argb: BLUE_HEADER } };
}
function lightFill(): ExcelJS.Fill {
  return { type: "pattern", pattern: "solid", fgColor: { argb: BLUE_LIGHT } };
}
function whiteFill(): ExcelJS.Fill {
  return { type: "pattern", pattern: "solid", fgColor: { argb: WHITE } };
}

function thinBorder(): Partial<ExcelJS.Borders> {
  const side: ExcelJS.Border = { style: "thin", color: { argb: "FFD1D5DB" } };
  return { top: side, left: side, bottom: side, right: side };
}

// ─── Excel builder — one workbook per route ────────────────────────────────

/**
 * Builds a single-route Knox-style attendance workbook.
 * Returns the Excel file as a Buffer.
 */
async function buildRouteWorkbook(
  route: RouteDoc,
  students: StudentDoc[],
  driver: DriverDoc | undefined,
  parentMap: Map<string, ParentDoc>,
  dayMap: Map<number, { pickup: Map<string, string>; dropoff: Map<string, string> }>,
  notes: NoteRow[],
  schoolName: string,
  weekDates: Date[]
): Promise<Buffer> {
  const wb = new ExcelJS.Workbook();
  wb.creator = "BusMate";
  wb.created = new Date();

  const DAY_LABELS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];

  const ws = wb.addWorksheet(route.name.replace(/[:\\/?*[\]]/g, "").slice(0, 31), {
    pageSetup: { orientation: "landscape", fitToPage: true, fitToWidth: 1, fitToHeight: 0 },
  });

  // Column widths (A–R = 18 cols)
  ws.columns = [
    { width: 24 }, // A — Name
    { width: 11 }, // B — Year Level
    { width: 17 }, // C — Sched AM
    { width: 17 }, // D — Sched PM
    { width: 34 }, // E — Stop AM
    { width: 34 }, // F — Stop PM
    { width: 13 }, // G — Mon AM
    { width: 13 }, // H — Mon PM
    { width: 13 }, // I — Tue AM
    { width: 13 }, // J — Tue PM
    { width: 13 }, // K — Wed AM
    { width: 13 }, // L — Wed PM
    { width: 13 }, // M — Thu AM
    { width: 13 }, // N — Thu PM
    { width: 13 }, // O — Fri AM
    { width: 13 }, // P — Fri PM
    { width: 19 }, // Q — Parent Contact #
    { width: 26 }, // R — Parent Name
  ];

  // ── Row 1: Title ──────────────────────────────────────────────────────────
  const titleRow = ws.addRow([`${schoolName.toUpperCase()} – STUDENT WEEKLY BUS REPORT`]);
  ws.mergeCells(`A${titleRow.number}:R${titleRow.number}`);
  titleRow.getCell(1).font = { bold: true, size: 14, color: { argb: HEADER_TEXT } };
  titleRow.getCell(1).fill = headerFill();
  titleRow.getCell(1).alignment = { horizontal: "center", vertical: "middle" };
  titleRow.height = 28;

  // ── Row 2: Route + Registration ───────────────────────────────────────────
  const routeRow = ws.addRow([`Route: ${route.name}   |   Registration: ${route.busRegistration ?? "—"}`]);
  ws.mergeCells(`A${routeRow.number}:R${routeRow.number}`);
  routeRow.getCell(1).font = { bold: true, size: 11, color: { argb: DARK_TEXT } };
  routeRow.getCell(1).fill = lightFill();
  routeRow.getCell(1).alignment = { horizontal: "left", vertical: "middle" };
  routeRow.height = 20;

  // ── Row 3: Driver name  (row 4 will have email + phone below) ─────────────
  const driverNameRow = ws.addRow([`Driver: ${driver?.name ?? "—"}`]);
  ws.mergeCells(`A${driverNameRow.number}:R${driverNameRow.number}`);
  driverNameRow.getCell(1).font = { bold: true, size: 11, color: { argb: DARK_TEXT } };
  driverNameRow.getCell(1).fill = whiteFill();
  driverNameRow.getCell(1).alignment = { horizontal: "left", vertical: "middle" };
  driverNameRow.height = 18;

  // ── Row 4: Driver email + phone (below name) ──────────────────────────────
  const driverContactRow = ws.addRow([`Email: ${driver?.email ?? "—"}   |   Phone: ${driver?.phone ?? "—"}`]);
  ws.mergeCells(`A${driverContactRow.number}:R${driverContactRow.number}`);
  driverContactRow.getCell(1).font = { size: 10, color: { argb: "FF6B7280" } };
  driverContactRow.getCell(1).fill = whiteFill();
  driverContactRow.getCell(1).alignment = { horizontal: "left", vertical: "middle" };
  driverContactRow.height = 16;

  // ── Row 5: Blank spacer ───────────────────────────────────────────────────
  ws.addRow([]);

  // ── Row 6: Week day dates (spans AM+PM for each day) ─────────────────────
  const dateRowData: (string | null)[] = [null, null, null, null, null, null];
  for (let d = 0; d < 5; d++) {
    dateRowData.push(`${DAY_LABELS[d]}\n${formatDate(weekDates[d])}`);
    dateRowData.push(null); // PM column — will be merged
  }
  dateRowData.push(null, null); // Parent cols
  const dateRow = ws.addRow(dateRowData);
  dateRow.height = 32;

  // Merge AM+PM pairs for each day
  for (let d = 0; d < 5; d++) {
    const colStart = 7 + d * 2; // G=7
    ws.mergeCells(dateRow.number, colStart, dateRow.number, colStart + 1);
    const cell = dateRow.getCell(colStart);
    cell.fill = headerFill();
    cell.font = { bold: true, size: 10, color: { argb: HEADER_TEXT } };
    cell.alignment = { horizontal: "center", vertical: "middle", wrapText: true };
    cell.border = thinBorder();
  }
  // Style left static columns
  for (let c = 1; c <= 6; c++) {
    dateRow.getCell(c).fill = whiteFill();
  }

  // ── Row 7: Column headers ─────────────────────────────────────────────────
  const headerRow = ws.addRow([
    "Name",
    "Year Level",
    "Sched AM\n(Order / Time)",
    "Sched PM\n(Order / Time)",
    "Stop Location AM",
    "Stop Location PM",
    "Mon AM\n(Actual)",
    "Mon PM\n(Actual)",
    "Tue AM\n(Actual)",
    "Tue PM\n(Actual)",
    "Wed AM\n(Actual)",
    "Wed PM\n(Actual)",
    "Thu AM\n(Actual)",
    "Thu PM\n(Actual)",
    "Fri AM\n(Actual)",
    "Fri PM\n(Actual)",
    "Parent Contact #",
    "Parent Name",
  ]);
  headerRow.height = 36;
  headerRow.eachCell((cell) => {
    cell.fill = headerFill();
    cell.font = { bold: true, size: 10, color: { argb: HEADER_TEXT } };
    cell.alignment = { horizontal: "center", vertical: "middle", wrapText: true };
    cell.border = thinBorder();
  });

  // ── Student rows ──────────────────────────────────────────────────────────
  const sorted = [...students].sort((a, b) => (a.orderAM ?? 99) - (b.orderAM ?? 99));

  sorted.forEach((student, idx) => {
    let parentPhone = "";
    let parentName = "";
    for (const pid of student.authorisedParentIds) {
      const p = parentMap.get(pid);
      if (p) {
        parentPhone = p.phone;
        parentName = `${p.name} (${p.relationship})`;
        break;
      }
    }

    const rowData: (string | number)[] = [
      student.name,
      student.grade,
      `${student.orderAM ?? ""} – ${student.scheduledPickupTime}`,
      `${student.orderPM ?? ""} – ${student.scheduledDropoffTime}`,
      student.stopAddressAM,
      student.stopAddressPM,
    ];

    for (let d = 0; d < 5; d++) {
      const dayTrips = dayMap.get(d);
      rowData.push(dayTrips?.pickup.get(student.id) ?? "");
      rowData.push(dayTrips?.dropoff.get(student.id) ?? "");
    }

    rowData.push(parentPhone, parentName);

    const dataRow = ws.addRow(rowData);
    dataRow.height = 20;

    const fill = idx % 2 === 0 ? whiteFill() : lightFill();
    dataRow.eachCell((cell) => {
      cell.fill = fill;
      cell.font = { size: 10, color: { argb: DARK_TEXT } };
      cell.alignment = { horizontal: "left", vertical: "middle", wrapText: false };
      cell.border = thinBorder();
    });
    // Center the AM/PM time cells
    for (let c = 7; c <= 16; c++) {
      dataRow.getCell(c).alignment = { horizontal: "center", vertical: "middle" };
    }
  });

  // ── Footer row ────────────────────────────────────────────────────────────
  ws.addRow([]);
  const footerRow = ws.addRow(["", "", "AM Arrival →", "PM Departure →", "No Child Left On Bus — Final Check"]);
  footerRow.getCell(3).font = { bold: true, size: 10 };
  footerRow.getCell(4).font = { bold: true, size: 10 };
  footerRow.getCell(5).font = { bold: true, size: 10, color: { argb: "FFB91C1C" } };
  ws.mergeCells(`E${footerRow.number}:R${footerRow.number}`);

  // ── Travel Notes section ──────────────────────────────────────────────────
  if (notes.length > 0) {
    ws.addRow([]);
    const notesTitleRow = ws.addRow(["TRAVEL NOTES"]);
    ws.mergeCells(`A${notesTitleRow.number}:R${notesTitleRow.number}`);
    notesTitleRow.getCell(1).font = { bold: true, size: 11, color: { argb: HEADER_TEXT } };
    notesTitleRow.getCell(1).fill = headerFill();
    notesTitleRow.getCell(1).alignment = { horizontal: "left", vertical: "middle" };
    notesTitleRow.height = 20;

    const notesHeaderRow = ws.addRow(["Student", "Note", "Type", "From", "To", "Created By", "Role"]);
    notesHeaderRow.eachCell((cell) => {
      cell.fill = lightFill();
      cell.font = { bold: true, size: 10 };
      cell.border = thinBorder();
    });

    for (const note of notes) {
      const nr = ws.addRow([
        note.studentName,
        note.noteText,
        note.type,
        note.fromDate,
        note.toDate,
        note.createdByName,
        note.createdByRole,
      ]);
      nr.eachCell((cell) => {
        cell.font = { size: 10 };
        cell.border = thinBorder();
      });
    }
  }

  const arrayBuffer = await wb.xlsx.writeBuffer();
  return Buffer.from(arrayBuffer);
}

// ─── Email HTML ───────────────────────────────────────────────────────────────

function buildEmailHtml(
  schoolName: string,
  weekFrom: Date,
  weekTo: Date,
  routeCount: number,
  tripCount: number,
  noteCount: number
): string {
  const fromStr = weekFrom.toLocaleDateString("en-AU", { timeZone: "Australia/Sydney" });
  const toStr = weekTo.toLocaleDateString("en-AU", { timeZone: "Australia/Sydney" });

  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f9fafb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fafb;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;">
          <tr>
            <td align="center" style="padding-bottom:24px;">
              <div style="display:inline-block;background:#2563eb;border-radius:16px;padding:12px 20px;">
                <span style="color:white;font-size:16px;font-weight:900;letter-spacing:0.15em;">BUSMATE</span>
              </div>
            </td>
          </tr>
          <tr>
            <td style="background:white;border-radius:20px;border:1px solid #f3f4f6;padding:32px;">
              <h2 style="margin:0 0 8px;font-size:18px;font-weight:900;color:#111827;">Weekly Report</h2>
              <p style="margin:0 0 24px;font-size:14px;color:#6b7280;">${schoolName} &mdash; ${fromStr} to ${toStr}</p>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
                <tr>
                  <td style="background:#eff6ff;border-radius:12px;padding:14px 16px;text-align:center;">
                    <div style="font-size:24px;font-weight:900;color:#1d4ed8;">${routeCount}</div>
                    <div style="font-size:11px;color:#6b7280;margin-top:4px;">Routes</div>
                  </td>
                  <td width="8"></td>
                  <td style="background:#f0fdf4;border-radius:12px;padding:14px 16px;text-align:center;">
                    <div style="font-size:24px;font-weight:900;color:#16a34a;">${tripCount}</div>
                    <div style="font-size:11px;color:#6b7280;margin-top:4px;">Trips</div>
                  </td>
                  <td width="8"></td>
                  <td style="background:#fefce8;border-radius:12px;padding:14px 16px;text-align:center;">
                    <div style="font-size:24px;font-weight:900;color:#ca8a04;">${noteCount}</div>
                    <div style="font-size:11px;color:#6b7280;margin-top:4px;">Notes</div>
                  </td>
                </tr>
              </table>

              <p style="margin:0 0 8px;font-size:14px;color:#374151;">Attached is one Excel file per route:</p>
              <ul style="margin:0 0 24px;padding-left:20px;font-size:14px;color:#374151;line-height:1.8;">
                <li>Knox-style weekly attendance with actual pick-up and drop-off times</li>
                <li>Driver contact details and travel notes per route</li>
              </ul>

              <p style="margin:0;font-size:13px;color:#9ca3af;">This data has been archived and removed from the live app. Keep these files for your records.</p>
            </td>
          </tr>
          <tr>
            <td style="padding-top:20px;text-align:center;">
              <p style="margin:0;font-size:11px;color:#d1d5db;">BusMate &middot; Weekly Report</p>
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

// ─── Handler ──────────────────────────────────────────────────────────────────

export async function GET(req: NextRequest) {
  const authHeader = req.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    return NextResponse.json({ error: "Email service not configured." }, { status: 500 });
  }

  const db = getAdminDb();
  const resend = new Resend(resendKey);
  const { from, to, weekDates } = getWeekRange();

  const fromTs = Timestamp.fromDate(from);
  const toTs = Timestamp.fromDate(to);

  const schoolsSnap = await db.collection("schools").get();
  if (schoolsSnap.empty) {
    return NextResponse.json({ success: true, message: "No schools found." });
  }

  // Format dates for file names: DD-MM-YYYY
  const fromStr = from.toLocaleDateString("en-AU", { timeZone: "Australia/Sydney" }).replace(/\//g, "-");
  const toStr = to.toLocaleDateString("en-AU", { timeZone: "Australia/Sydney" }).replace(/\//g, "-");

  const results: { schoolId: string; status: string; error?: string }[] = [];

  for (const schoolDoc of schoolsSnap.docs) {
    const schoolId = schoolDoc.id;
    const schoolData = schoolDoc.data();
    const schoolName: string = schoolData.schoolName ?? "Your School";
    const adminEmail: string | undefined = schoolData.email;

    if (!adminEmail) {
      results.push({ schoolId, status: "skipped", error: "No admin email on school document." });
      continue;
    }

    try {
      // ── Fetch all reference data for this school in parallel ───────────────
      const [routesSnap, studentsSnap, driversSnap, parentsSnap, tripsSnap, notesSnap] =
        await Promise.all([
          db.collection("routes").where("schoolId", "==", schoolId).where("isActive", "==", true).get(),
          db.collection("students").where("schoolId", "==", schoolId).where("isActive", "==", true).get(),
          db.collection("drivers").where("schoolId", "==", schoolId).get(),
          db.collection("parents").where("schoolId", "==", schoolId).get(),
          db.collection("trips").where("schoolId", "==", schoolId).where("date", ">=", fromTs).where("date", "<=", toTs).get(),
          db.collection("passengerNotes").where("schoolId", "==", schoolId).where("createdAt", ">=", fromTs).where("createdAt", "<=", toTs).get(),
        ]);

      // ── Build lookup maps ──────────────────────────────────────────────────
      const driverMap = new Map<string, DriverDoc>();
      for (const d of driversSnap.docs) {
        const data = d.data();
        driverMap.set(d.id, { id: d.id, name: data.name ?? "", phone: data.phone ?? "", email: data.email });
      }

      const parentMap = new Map<string, ParentDoc>();
      for (const p of parentsSnap.docs) {
        const data = p.data();
        parentMap.set(p.id, { id: p.id, name: data.name ?? "", phone: data.phone ?? "", relationship: data.relationship ?? "" });
      }

      const studentsByRoute = new Map<string, StudentDoc[]>();
      for (const s of studentsSnap.docs) {
        const data = s.data();
        const student: StudentDoc = {
          id: s.id,
          name: data.name ?? "",
          grade: data.grade ?? "",
          orderAM: data.orderAM,
          orderPM: data.orderPM,
          scheduledPickupTime: data.scheduledPickupTime ?? "",
          scheduledDropoffTime: data.scheduledDropoffTime ?? "",
          stopAddressAM: data.stopAddressAM ?? "",
          stopAddressPM: data.stopAddressPM ?? "",
          authorisedParentIds: data.authorisedParentIds ?? [],
        };
        const arr = studentsByRoute.get(data.routeId) ?? [];
        arr.push(student);
        studentsByRoute.set(data.routeId, arr);
      }

      // ── Build trip actual-time map ─────────────────────────────────────────
      // tripsByRoute[routeId][dayIndex(0=Mon)] = { pickup: Map<studentId, time>, dropoff: ... }
      const tripsByRoute = new Map<string, Map<number, { pickup: Map<string, string>; dropoff: Map<string, string> }>>();

      for (const tripDoc of tripsSnap.docs) {
        const t = tripDoc.data();
        const tripDate = toDate(t.date);
        if (!tripDate) continue;

        const tripDateAest = new Date(tripDate.getTime() + 10 * 60 * 60 * 1000);
        const dayIndex = tripDateAest.getUTCDay() - 1; // Mon=1 → 0
        if (dayIndex < 0 || dayIndex > 4) continue;

        const routeId: string = t.routeId ?? "";
        if (!tripsByRoute.has(routeId)) tripsByRoute.set(routeId, new Map());
        const routeDays = tripsByRoute.get(routeId)!;
        if (!routeDays.has(dayIndex)) routeDays.set(dayIndex, { pickup: new Map(), dropoff: new Map() });
        const dayEntry = routeDays.get(dayIndex)!;

        const records: Record<string, unknown>[] = Array.isArray(t.studentRecords) ? t.studentRecords : [];
        for (const sr of records) {
          const studentId = sr.id as string;
          if (!studentId) continue;
          const timeStr = formatTime(sr.timestamp);
          if (!timeStr) continue;
          if (t.type === "pickup") {
            dayEntry.pickup.set(studentId, timeStr);
          } else {
            dayEntry.dropoff.set(studentId, timeStr);
          }
        }
      }

      // ── Build notes-by-route map ───────────────────────────────────────────
      const notesByRoute = new Map<string, NoteRow[]>();
      for (const noteDoc of notesSnap.docs) {
        const n = noteDoc.data();
        if (n.isDeleted) continue;
        const routeId: string = n.routeId ?? "";
        const arr = notesByRoute.get(routeId) ?? [];
        arr.push({
          studentName: n.studentName ?? "",
          noteText: n.noteText ?? "",
          type: n.type ?? "",
          fromDate: formatDate(n.fromDate),
          toDate: formatDate(n.toDate),
          createdByName: n.createdByName ?? "",
          createdByRole: n.createdByRole ?? "",
        });
        notesByRoute.set(routeId, arr);
      }

      // ── Build route list ───────────────────────────────────────────────────
      const routes: RouteDoc[] = routesSnap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          name: data.name ?? d.id,
          driverId: data.driverId ?? "",
          busRegistration: data.busRegistration,
          studentIds: data.studentIds ?? [],
        };
      });

      // ── Build one Excel attachment per route ───────────────────────────────
      const attachments: { filename: string; content: Buffer }[] = [];

      for (const route of routes) {
        const students = studentsByRoute.get(route.id) ?? [];
        const driver = driverMap.get(route.driverId);
        const dayMap = tripsByRoute.get(route.id) ?? new Map();
        const notes = notesByRoute.get(route.id) ?? [];

        // Sanitise names for filename (no slashes, colons, etc.)
        const safeSchoolName = schoolName.replace(/[^a-zA-Z0-9 _-]/g, "").replace(/\s+/g, "_").slice(0, 30);
        const safeRouteName = route.name.replace(/[^a-zA-Z0-9 _-]/g, "").replace(/\s+/g, "_").slice(0, 40);
        const filename = `${safeSchoolName}_${safeRouteName}_${fromStr}_to_${toStr}.xlsx`;

        const buffer = await buildRouteWorkbook(
          route,
          students,
          driver,
          parentMap,
          dayMap,
          notes,
          schoolName,
          weekDates
        );

        attachments.push({ filename, content: buffer });
      }

      // ── Send email ─────────────────────────────────────────────────────────
      await resend.emails.send({
        from: "BusMate <reports@resend.dev>",
        to: [adminEmail],
        subject: `BusMate Weekly Report — ${schoolName} (${fromStr} to ${toStr})`,
        html: buildEmailHtml(schoolName, from, to, routes.length, tripsSnap.size, notesSnap.size),
        attachments,
      });

      // ── Delete reported data from Firestore (trips + notes only; activityLog kept in daily backup) ──
      const refsToDelete = [
        ...tripsSnap.docs.map((d) => d.ref),
        ...notesSnap.docs.map((d) => d.ref),
      ];
      if (refsToDelete.length > 0) {
        await batchDelete(db, refsToDelete);
      }

      results.push({ schoolId, status: "ok" });
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`weekly-report error for school ${schoolId}:`, msg);
      results.push({ schoolId, status: "error", error: msg });
    }
  }

  const anyError = results.some((r) => r.status === "error");
  return NextResponse.json({ success: !anyError, results }, { status: anyError ? 207 : 200 });
}

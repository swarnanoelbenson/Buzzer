import { NextRequest, NextResponse } from "next/server";
import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, Timestamp, WriteBatch } from "firebase-admin/firestore";
import { Resend } from "resend";
import * as XLSX from "xlsx";

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

function formatDateTime(val: unknown): string {
  const d = toDate(val);
  if (!d) return "";
  return d.toLocaleString("en-AU", {
    timeZone: "Australia/Sydney",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/** Returns Mon–Fri dates for the current week (run on Friday evening AEST). */
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

// ─── Excel builder (Sheet 1: Attendance, Knox-style) ──────────────────────────

/**
 * Builds the attendance sheet in Knox School template format.
 * One worksheet per route, named by route name.
 * Columns: Name | Grade | Sched AM | Sched PM | Stop AM | Stop PM |
 *          Mon AM | Mon PM | Tue AM | Tue PM | Wed AM | Wed PM | Thu AM | Thu PM | Fri AM | Fri PM |
 *          Parent Contact # | Parent Name
 */
function buildAttendanceWorkbook(
  routes: RouteDoc[],
  studentsByRoute: Map<string, StudentDoc[]>,
  driverMap: Map<string, DriverDoc>,
  parentMap: Map<string, ParentDoc>,
  // tripsByRouteAndDay[routeId][dayIndex(0=Mon)][type] = Map<studentId, timestampString>
  tripsByRouteAndDay: Map<string, Map<number, { pickup: Map<string, string>; dropoff: Map<string, string> }>>,
  notesByRoute: Map<string, { studentName: string; noteText: string }[]>,
  schoolName: string,
  weekDates: Date[]
): Buffer {
  const wb = XLSX.utils.book_new();

  const DAY_LABELS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];

  for (const route of routes) {
    const students = (studentsByRoute.get(route.id) ?? []).sort((a, b) => (a.orderAM ?? 99) - (b.orderAM ?? 99));
    const driver = driverMap.get(route.driverId);
    const dayMap = tripsByRouteAndDay.get(route.id) ?? new Map();
    const notes = notesByRoute.get(route.id) ?? [];

    // ── Header rows (aoa = array of arrays) ──────────────────────────────────
    const aoa: unknown[][] = [];

    // Title
    aoa.push([`${schoolName.toUpperCase()} - STUDENT WEEKLY BUS REPORT`]);
    aoa.push([]);

    // Route info
    aoa.push([`ROUTE: ${route.name}`]);
    aoa.push([`REGISTRATION: ${route.busRegistration ?? ""}`]);
    aoa.push([`DRIVER: ${driver?.name ?? ""}`, "", "", "", `Phone: ${driver?.phone ?? ""}`, "", `Email: ${driver?.email ?? ""}`]);
    aoa.push([]);

    // Week dates row
    const weekRow: unknown[] = ["", "", "", "", "", ""];
    for (let d = 0; d < 5; d++) {
      const label = `${DAY_LABELS[d]} ${formatDate(weekDates[d])}`;
      weekRow.push(label, ""); // spans AM + PM
    }
    weekRow.push("", "");
    aoa.push(weekRow);

    // Column header row
    aoa.push([
      "Name",
      "Year Level",
      "Sched AM\n(Order/Time)",
      "Sched PM\n(Order/Time)",
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

    // ── Student rows ──────────────────────────────────────────────────────────
    for (const student of students) {
      // Find first authorised parent
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

      const row: unknown[] = [
        student.name,
        student.grade,
        `${student.orderAM ?? ""} - ${student.scheduledPickupTime}`,
        `${student.orderPM ?? ""} - ${student.scheduledDropoffTime}`,
        student.stopAddressAM,
        student.stopAddressPM,
      ];

      // Mon–Fri actual times
      for (let d = 0; d < 5; d++) {
        const dayTrips = dayMap.get(d);
        const amTime = dayTrips?.pickup.get(student.id) ?? "";
        const pmTime = dayTrips?.dropoff.get(student.id) ?? "";
        row.push(amTime, pmTime);
      }

      row.push(parentPhone, parentName);
      aoa.push(row);
    }

    // ── Footer row ────────────────────────────────────────────────────────────
    aoa.push([]);
    aoa.push(["", "", "AM Arrival", "PM Departure", "No Child Left On Bus — Final Check"]);

    // ── Travel Notes section ──────────────────────────────────────────────────
    if (notes.length > 0) {
      aoa.push([]);
      aoa.push(["TRAVEL NOTES"]);
      aoa.push(["Student", "Special Travel Notes"]);
      for (const note of notes) {
        aoa.push([note.studentName, note.noteText]);
      }
    }

    // ── Write sheet ───────────────────────────────────────────────────────────
    const ws = XLSX.utils.aoa_to_sheet(aoa);

    // Set column widths
    ws["!cols"] = [
      { wch: 22 }, // Name
      { wch: 10 }, // Grade
      { wch: 16 }, // Sched AM
      { wch: 16 }, // Sched PM
      { wch: 32 }, // Stop AM
      { wch: 32 }, // Stop PM
      { wch: 12 }, // Mon AM
      { wch: 12 }, // Mon PM
      { wch: 12 }, // Tue AM
      { wch: 12 }, // Tue PM
      { wch: 12 }, // Wed AM
      { wch: 12 }, // Wed PM
      { wch: 12 }, // Thu AM
      { wch: 12 }, // Thu PM
      { wch: 12 }, // Fri AM
      { wch: 12 }, // Fri PM
      { wch: 18 }, // Parent Contact
      { wch: 24 }, // Parent Name
    ];

    // Sanitise sheet name (Excel limit: 31 chars, no special chars)
    const sheetName = route.name.replace(/[:\\/?*[\]]/g, "").slice(0, 31);
    XLSX.utils.book_append_sheet(wb, ws, sheetName);
  }

  // ── Sheet: Notes ─────────────────────────────────────────────────────────────
  // (kept as a summary sheet for all routes)
  const notesAoa: unknown[][] = [["Student", "Route", "Type", "Note", "From", "To", "Created By", "Role"]];
  for (const [routeId, notes] of notesByRoute) {
    const route = routes.find((r) => r.id === routeId);
    for (const n of notes as { studentName: string; noteText: string; type?: string; fromDate?: string; toDate?: string; createdByName?: string; createdByRole?: string }[]) {
      notesAoa.push([
        n.studentName,
        route?.name ?? routeId,
        n.type ?? "",
        n.noteText,
        n.fromDate ?? "",
        n.toDate ?? "",
        n.createdByName ?? "",
        n.createdByRole ?? "",
      ]);
    }
  }
  const notesWs = XLSX.utils.aoa_to_sheet(notesAoa);
  notesWs["!cols"] = [{ wch: 22 }, { wch: 22 }, { wch: 10 }, { wch: 50 }, { wch: 14 }, { wch: 14 }, { wch: 20 }, { wch: 12 }];
  XLSX.utils.book_append_sheet(wb, notesWs, "Notes");

  const buffer = XLSX.write(wb, { type: "buffer", bookType: "xlsx" });
  return Buffer.from(buffer);
}

// ─── Activity Log workbook ────────────────────────────────────────────────────

function buildActivityWorkbook(
  logs: FirebaseFirestore.QueryDocumentSnapshot[]
): Buffer {
  const wb = XLSX.utils.book_new();
  const aoa: unknown[][] = [["Timestamp", "Actor", "Role", "Action", "Metadata"]];
  for (const doc of logs) {
    const l = doc.data();
    aoa.push([
      formatDateTime(l.timestamp),
      l.actorName ?? "",
      l.actorRole ?? "",
      l.action ?? "",
      l.metadata ? JSON.stringify(l.metadata) : "",
    ]);
  }
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws["!cols"] = [{ wch: 20 }, { wch: 22 }, { wch: 12 }, { wch: 60 }, { wch: 40 }];
  XLSX.utils.book_append_sheet(wb, ws, "Activity Log");
  const buffer = XLSX.write(wb, { type: "buffer", bookType: "xlsx" });
  return Buffer.from(buffer);
}

// ─── Email HTML ───────────────────────────────────────────────────────────────

function buildEmailHtml(
  schoolName: string,
  weekFrom: Date,
  weekTo: Date,
  routeCount: number,
  tripCount: number,
  noteCount: number,
  logCount: number
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
                  <td width="8"></td>
                  <td style="background:#fdf4ff;border-radius:12px;padding:14px 16px;text-align:center;">
                    <div style="font-size:24px;font-weight:900;color:#9333ea;">${logCount}</div>
                    <div style="font-size:11px;color:#6b7280;margin-top:4px;">Events</div>
                  </td>
                </tr>
              </table>

              <p style="margin:0 0 8px;font-size:14px;color:#374151;">Attached are two Excel files:</p>
              <ul style="margin:0 0 24px;padding-left:20px;font-size:14px;color:#374151;line-height:1.8;">
                <li><strong>Attendance.xlsx</strong> &mdash; one sheet per route, Knox-style weekly attendance with actual pick-up and drop-off times, plus travel notes</li>
                <li><strong>ActivityLog.xlsx</strong> &mdash; all app activity events for the week</li>
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
      const [routesSnap, studentsSnap, driversSnap, parentsSnap, tripsSnap, notesSnap, logsSnap] =
        await Promise.all([
          db.collection("routes").where("schoolId", "==", schoolId).where("isActive", "==", true).get(),
          db.collection("students").where("schoolId", "==", schoolId).where("isActive", "==", true).get(),
          db.collection("drivers").where("schoolId", "==", schoolId).get(),
          db.collection("parents").where("schoolId", "==", schoolId).get(),
          db.collection("trips").where("schoolId", "==", schoolId).where("date", ">=", fromTs).where("date", "<=", toTs).get(),
          db.collection("passengerNotes").where("schoolId", "==", schoolId).where("createdAt", ">=", fromTs).where("createdAt", "<=", toTs).get(),
          db.collection("activityLog").where("schoolId", "==", schoolId).where("timestamp", ">=", fromTs).where("timestamp", "<=", toTs).get(),
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
      // tripsByRouteAndDay[routeId][dayIndex][pickup|dropoff][studentId] = "HH:MM am/pm"
      const tripsByRouteAndDay = new Map<string, Map<number, { pickup: Map<string, string>; dropoff: Map<string, string> }>>();

      for (const tripDoc of tripsSnap.docs) {
        const t = tripDoc.data();
        const tripDate = toDate(t.date);
        if (!tripDate) continue;

        // Find which weekday index this trip falls on (0=Mon…4=Fri)
        const tripDateAest = new Date(tripDate.getTime() + 10 * 60 * 60 * 1000);
        const dayIndex = tripDateAest.getUTCDay() - 1; // Mon=1 → 0
        if (dayIndex < 0 || dayIndex > 4) continue;

        const routeId: string = t.routeId ?? "";
        if (!tripsByRouteAndDay.has(routeId)) tripsByRouteAndDay.set(routeId, new Map());
        const routeDays = tripsByRouteAndDay.get(routeId)!;
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
      const notesByRoute = new Map<string, { studentName: string; noteText: string; type: string; fromDate: string; toDate: string; createdByName: string; createdByRole: string }[]>();
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

      // ── Build Excel files ──────────────────────────────────────────────────
      const attendanceBuffer = buildAttendanceWorkbook(
        routes,
        studentsByRoute,
        driverMap,
        parentMap,
        tripsByRouteAndDay,
        notesByRoute,
        schoolName,
        weekDates
      );
      const activityBuffer = buildActivityWorkbook(logsSnap.docs);

      const fromStr = from.toLocaleDateString("en-AU", { timeZone: "Australia/Sydney" }).replace(/\//g, "-");
      const toStr = to.toLocaleDateString("en-AU", { timeZone: "Australia/Sydney" }).replace(/\//g, "-");

      // ── Send email ─────────────────────────────────────────────────────────
      await resend.emails.send({
        from: "BusMate <reports@resend.dev>",
        to: [adminEmail],
        subject: `BusMate Weekly Report — ${schoolName} (${fromStr} to ${toStr})`,
        html: buildEmailHtml(schoolName, from, to, routes.length, tripsSnap.size, notesSnap.size, logsSnap.size),
        attachments: [
          {
            filename: `BusMate_Attendance_${fromStr}_to_${toStr}.xlsx`,
            content: attendanceBuffer,
          },
          {
            filename: `BusMate_ActivityLog_${fromStr}_to_${toStr}.xlsx`,
            content: activityBuffer,
          },
        ],
      });

      // ── Delete reported data from Firestore ────────────────────────────────
      const refsToDelete = [
        ...tripsSnap.docs.map((d) => d.ref),
        ...notesSnap.docs.map((d) => d.ref),
        ...logsSnap.docs.map((d) => d.ref),
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

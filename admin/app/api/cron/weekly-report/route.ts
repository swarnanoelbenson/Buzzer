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

/** Returns the start of the previous week (Monday 00:00 AEST) as a UTC Date. */
function getWeekRange(): { from: Date; to: Date } {
  // "now" in AEST
  const now = new Date();
  const aestOffset = 10 * 60 * 60 * 1000; // UTC+10
  const nowAest = new Date(now.getTime() + aestOffset);

  // Find last Monday 00:00 AEST
  const dayOfWeek = nowAest.getUTCDay(); // 0=Sun, 5=Fri
  const daysToLastMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  const mondayAest = new Date(nowAest);
  mondayAest.setUTCDate(nowAest.getUTCDate() - daysToLastMonday);
  mondayAest.setUTCHours(0, 0, 0, 0);

  const fridayAest = new Date(mondayAest);
  fridayAest.setUTCDate(mondayAest.getUTCDate() + 4);
  fridayAest.setUTCHours(23, 59, 59, 999);

  // Convert back to UTC
  const from = new Date(mondayAest.getTime() - aestOffset);
  const to = new Date(fridayAest.getTime() - aestOffset);

  return { from, to };
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

// ─── Excel builder ────────────────────────────────────────────────────────────

interface TripRow {
  Date: string;
  Type: string;
  Route: string;
  Driver: string;
  Status: string;
  Student: string;
  "Student Status": string;
  "Pick-up Stop": string;
  "Drop-off Stop": string;
  "Timestamp": string;
}

interface NoteRow {
  "Created At": string;
  "Student": string;
  "Route": string;
  "Type": string;
  "From Date": string;
  "To Date": string;
  "Note": string;
  "Created By": string;
  "Role": string;
}

interface ActivityRow {
  "Timestamp": string;
  "Actor": string;
  "Role": string;
  "Action": string;
  "Metadata": string;
}

function buildExcel(
  trips: FirebaseFirestore.QueryDocumentSnapshot[],
  notes: FirebaseFirestore.QueryDocumentSnapshot[],
  logs: FirebaseFirestore.QueryDocumentSnapshot[]
): Buffer {
  const wb = XLSX.utils.book_new();

  // ── Sheet 1: Attendance ──────────────────────────────────────────────────────
  const attendanceRows: TripRow[] = [];
  for (const doc of trips) {
    const t = doc.data();
    const studentRecords: Record<string, unknown>[] = Array.isArray(t.studentRecords)
      ? t.studentRecords
      : [];

    if (studentRecords.length === 0) {
      // Trip with no student records — still capture the trip
      attendanceRows.push({
        Date: formatDate(t.date),
        Type: t.type ?? "",
        Route: t.routeId ?? "",
        Driver: t.driverId ?? "",
        Status: t.status ?? "",
        Student: "",
        "Student Status": "",
        "Pick-up Stop": "",
        "Drop-off Stop": "",
        Timestamp: "",
      });
    } else {
      for (const sr of studentRecords) {
        attendanceRows.push({
          Date: formatDate(t.date),
          Type: (t.type as string) ?? "",
          Route: (t.routeId as string) ?? "",
          Driver: (t.driverId as string) ?? "",
          Status: (t.status as string) ?? "",
          Student: (sr.studentName as string) ?? "",
          "Student Status": (sr.status as string) ?? "",
          "Pick-up Stop": (sr.stopAddressAM as string) ?? "",
          "Drop-off Stop": (sr.stopAddressPM as string) ?? "",
          Timestamp: formatDateTime(sr.timestamp),
        });
      }
    }
  }
  const ws1 = XLSX.utils.json_to_sheet(attendanceRows.length > 0 ? attendanceRows : [{}]);
  XLSX.utils.book_append_sheet(wb, ws1, "Attendance");

  // ── Sheet 2: Notes ───────────────────────────────────────────────────────────
  const noteRows: NoteRow[] = notes.map((doc) => {
    const n = doc.data();
    return {
      "Created At": formatDateTime(n.createdAt),
      Student: (n.studentName as string) ?? "",
      Route: (n.routeName as string) ?? "",
      Type: (n.type as string) ?? "",
      "From Date": formatDate(n.fromDate),
      "To Date": formatDate(n.toDate),
      Note: (n.noteText as string) ?? "",
      "Created By": (n.createdByName as string) ?? "",
      Role: (n.createdByRole as string) ?? "",
    };
  });
  const ws2 = XLSX.utils.json_to_sheet(noteRows.length > 0 ? noteRows : [{}]);
  XLSX.utils.book_append_sheet(wb, ws2, "Notes");

  // ── Sheet 3: Activity Log ────────────────────────────────────────────────────
  const activityRows: ActivityRow[] = logs.map((doc) => {
    const l = doc.data();
    return {
      Timestamp: formatDateTime(l.timestamp),
      Actor: (l.actorName as string) ?? "",
      Role: (l.actorRole as string) ?? "",
      Action: (l.action as string) ?? "",
      Metadata: l.metadata ? JSON.stringify(l.metadata) : "",
    };
  });
  const ws3 = XLSX.utils.json_to_sheet(activityRows.length > 0 ? activityRows : [{}]);
  XLSX.utils.book_append_sheet(wb, ws3, "Activity Log");

  const buffer = XLSX.write(wb, { type: "buffer", bookType: "xlsx" });
  return Buffer.from(buffer);
}

// ─── Email builder ────────────────────────────────────────────────────────────

function buildEmailHtml(
  schoolName: string,
  weekFrom: Date,
  weekTo: Date,
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
                  <td style="background:#eff6ff;border-radius:12px;padding:14px 20px;text-align:center;">
                    <div style="font-size:28px;font-weight:900;color:#1d4ed8;">${tripCount}</div>
                    <div style="font-size:12px;color:#6b7280;margin-top:4px;">Trip records</div>
                  </td>
                  <td width="12"></td>
                  <td style="background:#f0fdf4;border-radius:12px;padding:14px 20px;text-align:center;">
                    <div style="font-size:28px;font-weight:900;color:#16a34a;">${noteCount}</div>
                    <div style="font-size:12px;color:#6b7280;margin-top:4px;">Passenger notes</div>
                  </td>
                  <td width="12"></td>
                  <td style="background:#fefce8;border-radius:12px;padding:14px 20px;text-align:center;">
                    <div style="font-size:28px;font-weight:900;color:#ca8a04;">${logCount}</div>
                    <div style="font-size:12px;color:#6b7280;margin-top:4px;">Activity events</div>
                  </td>
                </tr>
              </table>

              <p style="margin:0 0 8px;font-size:14px;color:#374151;">Attached are three Excel files:</p>
              <ul style="margin:0 0 24px;padding-left:20px;font-size:14px;color:#374151;line-height:1.8;">
                <li><strong>Attendance.xlsx</strong> &mdash; student pick-up and drop-off records</li>
                <li><strong>Notes.xlsx</strong> &mdash; passenger notes for the week</li>
                <li><strong>ActivityLog.xlsx</strong> &mdash; all app activity events</li>
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
  const { from, to } = getWeekRange();

  const fromTs = Timestamp.fromDate(from);
  const toTs = Timestamp.fromDate(to);

  // Load all schools
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
      // ── Fetch this week's data for this school ─────────────────────────────
      const [tripsSnap, notesSnap, logsSnap] = await Promise.all([
        db
          .collection("trips")
          .where("schoolId", "==", schoolId)
          .where("date", ">=", fromTs)
          .where("date", "<=", toTs)
          .get(),
        db
          .collection("passengerNotes")
          .where("schoolId", "==", schoolId)
          .where("createdAt", ">=", fromTs)
          .where("createdAt", "<=", toTs)
          .get(),
        db
          .collection("activityLog")
          .where("schoolId", "==", schoolId)
          .where("timestamp", ">=", fromTs)
          .where("timestamp", "<=", toTs)
          .get(),
      ]);

      // ── Build Excel ────────────────────────────────────────────────────────
      const excelBuffer = buildExcel(tripsSnap.docs, notesSnap.docs, logsSnap.docs);
      const fromStr = from.toLocaleDateString("en-AU", { timeZone: "Australia/Sydney" }).replace(/\//g, "-");
      const toStr = to.toLocaleDateString("en-AU", { timeZone: "Australia/Sydney" }).replace(/\//g, "-");
      const fileName = `BusMate_WeeklyReport_${fromStr}_to_${toStr}.xlsx`;

      // ── Send email ─────────────────────────────────────────────────────────
      await resend.emails.send({
        from: "BusMate <reports@resend.dev>",
        to: [adminEmail],
        subject: `BusMate Weekly Report — ${schoolName} (${fromStr} to ${toStr})`,
        html: buildEmailHtml(
          schoolName,
          from,
          to,
          tripsSnap.size,
          notesSnap.size,
          logsSnap.size
        ),
        attachments: [
          {
            filename: fileName,
            content: excelBuffer,
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

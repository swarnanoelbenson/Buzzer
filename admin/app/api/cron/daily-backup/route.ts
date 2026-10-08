import { NextRequest, NextResponse } from "next/server";
import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { createClient } from "@supabase/supabase-js";

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

// ─── Supabase ─────────────────────────────────────────────────────────────────

function getSupabase() {
  return createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Convert a Firestore Timestamp, JS Date, or string to a JS Date (or null). */
function toDate(val: unknown): Date | null {
  if (!val) return null;
  if (val instanceof Timestamp) return val.toDate();
  if (val instanceof Date) return val;
  if (typeof val === "string") return new Date(val);
  return null;
}

// ─── Handler ──────────────────────────────────────────────────────────────────

export async function GET(req: NextRequest) {
  // Vercel Cron passes the CRON_SECRET in the Authorization header
  const authHeader = req.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const db = getAdminDb();
  const supabase = getSupabase();

  const errors: string[] = [];

  // ── 1. Backup trips ─────────────────────────────────────────────────────────
  try {
    const tripsSnap = await db.collection("trips").get();
    if (!tripsSnap.empty) {
      const rows = tripsSnap.docs.map((doc) => {
        const d = doc.data();
        return {
          id: doc.id,
          school_id: d.schoolId ?? null,
          route_id: d.routeId ?? null,
          driver_id: d.driverId ?? null,
          substitute_driver_id: d.substituteDriverId ?? null,
          date: toDate(d.date)?.toISOString() ?? null,
          type: d.type ?? null,
          status: d.status ?? null,
          student_records: JSON.stringify(d.studentRecords ?? []),
          started_at: toDate(d.startedAt)?.toISOString() ?? null,
          completed_at: toDate(d.completedAt)?.toISOString() ?? null,
          backed_up_at: new Date().toISOString(),
        };
      });

      const { error } = await supabase
        .from("trips_backup")
        .upsert(rows, { onConflict: "id" });

      if (error) errors.push(`trips: ${error.message}`);
    }
  } catch (e: unknown) {
    errors.push(`trips: ${e instanceof Error ? e.message : String(e)}`);
  }

  // ── 2. Backup passengerNotes ─────────────────────────────────────────────────
  try {
    const notesSnap = await db.collection("passengerNotes").get();
    if (!notesSnap.empty) {
      const rows = notesSnap.docs.map((doc) => {
        const d = doc.data();
        return {
          id: doc.id,
          school_id: d.schoolId ?? null,
          student_id: d.studentId ?? null,
          student_name: d.studentName ?? null,
          route_id: d.routeId ?? null,
          route_name: d.routeName ?? null,
          type: d.type ?? null,
          note_text: d.noteText ?? null,
          from_date: toDate(d.fromDate)?.toISOString() ?? null,
          to_date: toDate(d.toDate)?.toISOString() ?? null,
          created_at: toDate(d.createdAt)?.toISOString() ?? null,
          created_by_id: d.createdById ?? null,
          created_by_name: d.createdByName ?? null,
          created_by_role: d.createdByRole ?? null,
          is_deleted: d.isDeleted ?? false,
          backed_up_at: new Date().toISOString(),
        };
      });

      const { error } = await supabase
        .from("passenger_notes_backup")
        .upsert(rows, { onConflict: "id" });

      if (error) errors.push(`passengerNotes: ${error.message}`);
    }
  } catch (e: unknown) {
    errors.push(`passengerNotes: ${e instanceof Error ? e.message : String(e)}`);
  }

  // ── 3. Backup activityLog ────────────────────────────────────────────────────
  try {
    const logsSnap = await db.collection("activityLog").get();
    if (!logsSnap.empty) {
      const rows = logsSnap.docs.map((doc) => {
        const d = doc.data();
        return {
          id: doc.id,
          school_id: d.schoolId ?? null,
          actor_id: d.actorId ?? null,
          actor_name: d.actorName ?? null,
          actor_role: d.actorRole ?? null,
          action: d.action ?? null,
          timestamp: toDate(d.timestamp)?.toISOString() ?? null,
          metadata: d.metadata ? JSON.stringify(d.metadata) : null,
          backed_up_at: new Date().toISOString(),
        };
      });

      const { error } = await supabase
        .from("activity_log_backup")
        .upsert(rows, { onConflict: "id" });

      if (error) errors.push(`activityLog: ${error.message}`);
    }
  } catch (e: unknown) {
    errors.push(`activityLog: ${e instanceof Error ? e.message : String(e)}`);
  }

  // ── 4. Backup notificationQueue ──────────────────────────────────────────────
  try {
    const queueSnap = await db.collection("notificationQueue").get();
    if (!queueSnap.empty) {
      const rows = queueSnap.docs.map((doc) => {
        const d = doc.data();
        return {
          id: doc.id,
          school_id: d.schoolId ?? null,
          recipient_id: d.recipientId ?? null,
          recipient_role: d.recipientRole ?? null,
          title: d.title ?? null,
          body: d.body ?? null,
          data: d.data ? JSON.stringify(d.data) : null,
          status: d.status ?? null,
          created_at: toDate(d.createdAt)?.toISOString() ?? null,
          sent_at: toDate(d.sentAt)?.toISOString() ?? null,
          backed_up_at: new Date().toISOString(),
        };
      });

      const { error } = await supabase
        .from("notification_queue_backup")
        .upsert(rows, { onConflict: "id" });

      if (error) errors.push(`notificationQueue: ${error.message}`);
    }
  } catch (e: unknown) {
    errors.push(`notificationQueue: ${e instanceof Error ? e.message : String(e)}`);
  }

  if (errors.length > 0) {
    console.error("daily-backup errors:", errors);
    return NextResponse.json({ success: false, errors }, { status: 500 });
  }

  return NextResponse.json({ success: true, backedUpAt: new Date().toISOString() });
}

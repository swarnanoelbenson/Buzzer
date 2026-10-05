"use client";
import { useEffect, useState, useRef } from "react";
import { collection, getDocs, query, where, orderBy, limit, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { ActivityLog, Route, StudentTripRecord, PassengerNote } from "@/lib/types";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";

function firestoreToDate(value: unknown): Date {
  if (!value) return new Date();
  if (value instanceof Date) return value;
  if (value && typeof (value as Timestamp).toDate === "function") return (value as Timestamp).toDate();
  return new Date();
}

// ── Tooltip ────────────────────────────────────────────────────────────────
interface TooltipData {
  x: number;
  y: number;
  stopName: string;
  time: string;
  students: StudentTripRecord[];
  type: "pickup" | "dropoff";
}

// ── Gantt Chart ────────────────────────────────────────────────────────────
interface GanttTrip {
  id: string;
  routeName: string;
  startLocation: string;
  endLocation: string;
  type: "pickup" | "dropoff";
  status: string;
  studentRecords: StudentTripRecord[];
  startedAt?: Date;
}

function GanttChart({ trips }: { trips: GanttTrip[] }) {
  const [tooltip, setTooltip] = useState<TooltipData | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  if (trips.length === 0) {
    return (
      <div className="flex items-start justify-center pt-8 text-[13px] text-gray-900">
        No trips scheduled for this day.
      </div>
    );
  }

  // Separate pickup and dropoff
  const pickupTrips = trips.filter(t => t.type === "pickup");
  const dropoffTrips = trips.filter(t => t.type === "dropoff");

  // Timeline: 6am–9am for pickup, 2pm–5pm for dropoff (can be dynamic)
  const pickupStart = 6 * 60;  // minutes from midnight
  const pickupEnd   = 9 * 60;
  const dropoffStart = 14 * 60;
  const dropoffEnd   = 17 * 60;

  function timeLabel(mins: number): string {
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    const ampm = h >= 12 ? "PM" : "AM";
    const hour = h > 12 ? h - 12 : h === 0 ? 12 : h;
    return `${hour}:${m.toString().padStart(2, "0")} ${ampm}`;
  }

  // Build checkpoint progress for a trip
  function getProgress(trip: GanttTrip): number {
    if (trip.status === "scheduled") return 0;
    if (trip.status === "completed") return 100;
    const total = trip.studentRecords.length;
    if (total === 0) return trip.status === "inProgress" ? 20 : 0;
    const done = trip.studentRecords.filter(r =>
      trip.type === "pickup" ? r.status === "onBus" || r.status === "offBus" : r.status === "offBus"
    ).length;
    // Map done/total to 20–90% (started to just-before-school)
    return 20 + Math.round((done / total) * 70);
  }

  function renderSection(
    sectionTrips: GanttTrip[],
    color: "green" | "orange",
    rangeStart: number,
    rangeEnd: number,
    label: string
  ) {
    const bg = color === "green" ? "bg-green-500" : "bg-orange-500";
    const fill = color === "green" ? "bg-green-500" : "bg-orange-500";
    const dotColor = color === "green" ? "bg-green-500" : "bg-orange-500";
    const totalMins = rangeEnd - rangeStart;

    // Build time axis ticks every 30 min
    const ticks: number[] = [];
    for (let m = rangeStart; m <= rangeEnd; m += 30) ticks.push(m);

    return (
      <div className="mb-4">
        {/* Section header pill */}
        <div className={`inline-flex items-center px-3 py-1 rounded-full text-white text-[11px] font-black tracking-widest uppercase mb-2 ${bg}`}>
          {label}
        </div>

        {/* Time axis */}
        <div className="flex ml-36 mb-1 relative">
          {ticks.map(t => (
            <div
              key={t}
              className="absolute text-[9px] text-gray-900 font-medium -translate-x-1/2"
              style={{ left: `${((t - rangeStart) / totalMins) * 100}%` }}
            >
              {timeLabel(t)}
            </div>
          ))}
        </div>

        <div className="mt-4 space-y-2">
          {sectionTrips.map(trip => {
            const progress = getProgress(trip);
            // Build checkpoint dots: 0%, 20%, then student stops evenly spaced from 20-90%, then 90%=Final Check, 100%=School/Home
            const checkpoints: { pct: number; label: string; records: StudentTripRecord[] }[] = [];
            checkpoints.push({ pct: 0, label: "Start", records: [] });
            checkpoints.push({ pct: 20, label: "Started", records: [] });

            const stopMap: Record<string, StudentTripRecord[]> = {};
            trip.studentRecords.forEach(r => {
              const stopKey = trip.type === "pickup" ? (r.stopAddressAM || r.stopAddressPM) : (r.stopAddressPM || r.stopAddressAM);
              if (!stopMap[stopKey]) stopMap[stopKey] = [];
              stopMap[stopKey].push(r);
            });
            const stops = Object.entries(stopMap);
            const stopCount = stops.length;
            stops.forEach(([addr, recs], i) => {
              const pct = 20 + Math.round(((i + 1) / (stopCount + 1)) * 70);
              checkpoints.push({ pct, label: addr, records: recs });
            });

            checkpoints.push({ pct: 90, label: "Final Check", records: [] });
            checkpoints.push({ pct: 100, label: trip.type === "pickup" ? "School" : "Home", records: [] });

            return (
              <div key={trip.id} className="flex items-center gap-2">
                {/* Y-axis label */}
                <div className="w-36 flex-shrink-0 text-right pr-2">
                  <div className="text-[11px] font-bold text-gray-900 leading-tight truncate">{trip.routeName}</div>
                  <div className="text-[9px] text-gray-900 truncate">{trip.startLocation} → {trip.endLocation}</div>
                </div>

                {/* Bar track */}
                <div className="flex-1 relative h-7 bg-gray-100 rounded-full overflow-visible">
                  {/* Route label inside grey bar */}
                  <div className="absolute inset-0 flex items-center px-3">
                    <span className="text-[9px] text-gray-900 truncate">{trip.routeName}: {trip.startLocation} → {trip.endLocation}</span>
                  </div>

                  {/* Progress fill */}
                  <div
                    className={`absolute top-0 left-0 h-full rounded-full transition-all duration-500 ${fill} opacity-80`}
                    style={{ width: `${progress}%` }}
                  />

                  {/* Checkpoint dots */}
                  {checkpoints.map((cp, ci) => (
                    <div
                      key={ci}
                      className="absolute top-1/2 -translate-y-1/2 -translate-x-1/2 group cursor-pointer z-10"
                      style={{ left: `${cp.pct}%` }}
                      onMouseEnter={(e) => {
                        const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
                        const containerRect = containerRef.current?.getBoundingClientRect();
                        setTooltip({
                          x: rect.left - (containerRect?.left ?? 0) + rect.width / 2,
                          y: rect.top - (containerRect?.top ?? 0),
                          stopName: cp.label,
                          time: trip.startedAt
                            ? new Date(trip.startedAt.getTime() + cp.pct * 60000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
                            : "—",
                          students: cp.records,
                          type: trip.type,
                        });
                      }}
                      onMouseLeave={() => setTooltip(null)}
                    >
                      <div className={`w-3 h-3 rounded-full border-2 border-white ${
                        cp.pct <= progress ? dotColor : "bg-gray-300"
                      } shadow-sm`} />
                    </div>
                  ))}
                </div>

                {/* Status pill */}
                <div className="w-20 flex-shrink-0">
                  <TripStatusPill status={trip.status} />
                </div>
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  return (
    <div ref={containerRef} className="flex-1 overflow-y-auto px-5 py-4 relative">
      {pickupTrips.length > 0 && renderSection(pickupTrips, "green", pickupStart, pickupEnd, "Pickup")}
      {dropoffTrips.length > 0 && renderSection(dropoffTrips, "orange", dropoffStart, dropoffEnd, "Dropoff")}
      {pickupTrips.length === 0 && dropoffTrips.length === 0 && (
        <div className="flex items-center justify-center h-full text-sm text-gray-900">No trips for this day.</div>
      )}

      {/* Tooltip */}
      {tooltip && (
        <div
          className="absolute z-50 bg-gray-900 text-white rounded-xl shadow-xl px-3 py-2.5 pointer-events-none text-[11px]"
          style={{ left: tooltip.x, top: tooltip.y - 90, transform: "translateX(-50%)" }}
        >
          <div className="font-black text-[12px] mb-1">{tooltip.stopName}</div>
          <div className="text-gray-300 mb-1">{tooltip.time}</div>
          {tooltip.students.length > 0 && (
            <>
              <div className="text-gray-900 text-[10px] mb-0.5">
                {tooltip.type === "pickup" ? "Picked" : "Dropped"}: {tooltip.students.filter(s => s.status !== "pending").length}/{tooltip.students.length}
              </div>
              <div className="space-y-0.5 max-h-20 overflow-y-auto">
                {tooltip.students.map((s, i) => (
                  <div key={i} className="flex items-center gap-1.5">
                    <span className={`w-1.5 h-1.5 rounded-full flex-shrink-0 ${
                      s.status === "onBus" || s.status === "offBus" ? "bg-green-400" :
                      s.status === "absent" ? "bg-red-400" : "bg-gray-500"
                    }`} />
                    <span className="text-gray-200">{s.studentName}</span>
                  </div>
                ))}
              </div>
            </>
          )}
          {/* Tooltip arrow */}
          <div className="absolute left-1/2 -translate-x-1/2 bottom-[-5px] w-2.5 h-2.5 bg-gray-900 rotate-45" />
        </div>
      )}
    </div>
  );
}

// ── Main Dashboard ─────────────────────────────────────────────────────────
export default function DashboardPage() {
  const { schoolName } = useAuth();
  const [pickupTotal, setPickupTotal] = useState(0);
  const [pickupDone, setPickupDone] = useState(0);
  const [dropoffTotal, setDropoffTotal] = useState(0);
  const [dropoffDone, setDropoffDone] = useState(0);
  const [recentActivity, setRecentActivity] = useState<ActivityLog[]>([]);
  const [ganttTrips, setGanttTrips] = useState<GanttTrip[]>([]);
  const [passengerNotes, setPassengerNotes] = useState<PassengerNote[]>([]);
  const [loading, setLoading] = useState(true);
  const [viewDate, setViewDate] = useState<Date>(new Date());

  useEffect(() => {
    async function load() {
      const startOfDay = new Date(viewDate); startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(viewDate); endOfDay.setHours(23, 59, 59, 999);

      // Run each query independently — a missing index or empty collection in one
      // won't block the others from resolving.
      const empty = { docs: [] };
      const [tripsSnap, activitySnap, routesSnap, notesSnap] = await Promise.all([
        getDocs(query(collection(db, "trips"), where("date", ">=", startOfDay), where("date", "<=", endOfDay))).catch(() => empty),
        getDocs(query(collection(db, "activityLog"), orderBy("timestamp", "desc"), limit(10))).catch(() => empty),
        getDocs(query(collection(db, "routes"), where("isActive", "==", true))).catch(() => empty),
        getDocs(query(collection(db, "passengerNotes"), where("fromDate", "<=", endOfDay), where("toDate", ">=", startOfDay))).catch(() => empty),
      ]);

      const routeMap: Record<string, Route> = {};
      routesSnap.docs.forEach(d => {
        routeMap[d.id] = {
          id: d.id, ...d.data(),
          startDate: firestoreToDate(d.data().startDate),
          endDate: firestoreToDate(d.data().endDate),
        } as Route;
      });

      // Build gantt trips with route info
      const trips = tripsSnap.docs.map(d => {
        const data = d.data();
        const route = routeMap[data.routeId];
        return {
          id: d.id,
          routeName: route?.name ?? data.routeId ?? "Unknown Route",
          startLocation: route?.scheduledDays?.join(", ") ?? "—",
          endLocation: data.type === "pickup" ? "School" : "Home",
          type: data.type as "pickup" | "dropoff",
          status: data.status ?? "scheduled",
          studentRecords: (data.studentRecords ?? []) as StudentTripRecord[],
          startedAt: data.startedAt ? firestoreToDate(data.startedAt) : undefined,
        } as GanttTrip;
      });
      setGanttTrips(trips);

      // Pickup stats: count students across today's pickup trips
      let pTotal = 0, pDone = 0;
      trips.filter(t => t.type === "pickup").forEach(t => {
        pTotal += t.studentRecords.length;
        pDone += t.studentRecords.filter(r => r.status === "onBus" || r.status === "offBus").length;
      });
      setPickupTotal(pTotal);
      setPickupDone(pDone);

      // Dropoff stats
      let dTotal = 0, dDone = 0;
      trips.filter(t => t.type === "dropoff").forEach(t => {
        dTotal += t.studentRecords.length;
        dDone += t.studentRecords.filter(r => r.status === "offBus").length;
      });
      setDropoffTotal(dTotal);
      setDropoffDone(dDone);

      setRecentActivity(activitySnap.docs.map(d => ({
        id: d.id, ...d.data(),
        timestamp: firestoreToDate(d.data().timestamp),
      } as ActivityLog)));

      setPassengerNotes(notesSnap.docs.map(d => ({
        id: d.id, ...d.data(),
        fromDate: firestoreToDate(d.data().fromDate),
        toDate: firestoreToDate(d.data().toDate),
        createdAt: firestoreToDate(d.data().createdAt),
      } as PassengerNote)));

      setLoading(false);
    }
    setLoading(true);
    load();
  }, [viewDate]);

  // Date display
  const dateStr = viewDate.toLocaleDateString("en-AU", {
    weekday: "long", day: "numeric", month: "long", year: "numeric",
  }).toUpperCase();

  function isToday(d: Date) {
    const t = new Date();
    return d.getFullYear() === t.getFullYear() && d.getMonth() === t.getMonth() && d.getDate() === t.getDate();
  }
  function isTomorrow(d: Date) {
    const t = new Date(); t.setDate(t.getDate() + 1);
    return d.getFullYear() === t.getFullYear() && d.getMonth() === t.getMonth() && d.getDate() === t.getDate();
  }
  function isYesterday(d: Date) {
    const t = new Date(); t.setDate(t.getDate() - 1);
    return d.getFullYear() === t.getFullYear() && d.getMonth() === t.getMonth() && d.getDate() === t.getDate();
  }

  function dateLabelShort() {
    if (isToday(viewDate)) return "TODAY";
    if (isTomorrow(viewDate)) return "TOMORROW";
    if (isYesterday(viewDate)) return "YESTERDAY";
    return viewDate.toLocaleDateString("en-AU", { day: "numeric", month: "short" }).toUpperCase();
  }

  function shiftDay(n: number) {
    const d = new Date(viewDate);
    d.setDate(d.getDate() + n);
    setViewDate(d);
  }

  const pickupPct = pickupTotal > 0 ? Math.round((pickupDone / pickupTotal) * 100) : 0;
  const dropoffPct = dropoffTotal > 0 ? Math.round((dropoffDone / dropoffTotal) * 100) : 0;

  return (
    <div className="h-full flex flex-col gap-4">

      {/* Row 1 — DASHBOARD */}
      <div>
        <h1 className="text-base font-black tracking-widest text-gray-900 uppercase">
          Dashboard
        </h1>
      </div>

      {/* Row 2 — Date */}
      <div>
        <p className="text-[13px] font-black tracking-widest text-gray-900">{dateStr}</p>
      </div>

      {/* Row 3 — Two symmetric containers */}
      <div className="flex gap-5 flex-1 min-h-0">

        {/* LEFT container — Pickup + Dropoff cards + View Log */}
        <div className="flex flex-col gap-4 flex-1 min-w-0">

          {/* Stat row: Pickup + Dropoff */}
          <div className="flex gap-4">
            <PercentCard
              label="PICKUP"
              pct={pickupPct}
              doneLabel={`Picked ${pickupPct}%`}
              pendingLabel={`To Be Picked ${100 - pickupPct}%`}
              color="green"
              loading={loading}
            />
            <PercentCard
              label="DROPOFF"
              pct={dropoffPct}
              doneLabel={`Dropped ${dropoffPct}%`}
              pendingLabel={`To Be Dropped ${100 - dropoffPct}%`}
              color="orange"
              loading={loading}
            />
          </div>

          {/* PASSENGER NOTES */}
          <div className="flex-1 bg-white rounded-2xl border border-gray-100 flex flex-col overflow-hidden shadow-sm">
            <div className="px-5 py-3.5 border-b border-gray-50 flex items-center justify-between flex-shrink-0">
              <span className="text-[13px] font-black tracking-widest text-gray-900 uppercase">Parent Notes</span>
              <Link href="/notes" className="text-[12px] font-bold text-blue-600 hover:underline tracking-wide">VIEW ALL</Link>
            </div>
            <div className="flex-1 overflow-y-auto divide-y divide-gray-50">
              {loading ? (
                <div className="px-5 py-4 text-[11px] text-gray-300">Loading...</div>
              ) : passengerNotes.length === 0 ? (
                <div className="px-5 py-5 text-[13px] text-gray-700 text-center">No notes for this day.</div>
              ) : (
                passengerNotes.map(note => (
                  <div key={note.id} className="px-5 py-2.5 flex items-start gap-3">
                    {/* Type badge */}
                    <span className={`mt-0.5 flex-shrink-0 text-[9px] font-black px-2 py-0.5 rounded-full tracking-widest uppercase ${
                      note.type === "pickup" ? "bg-green-100 text-green-700" : "bg-orange-100 text-orange-700"
                    }`}>
                      {note.type}
                    </span>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-[12px] font-black text-gray-900 truncate">{note.studentName}</span>
                        <span className="text-[10px] text-gray-400 truncate flex-shrink-0">{note.routeName || "—"}</span>
                      </div>
                      <p className="text-[11px] text-gray-700 leading-snug mt-0.5 line-clamp-2">{note.noteText}</p>
                    </div>
                    {/* Date range */}
                    <span className="flex-shrink-0 text-[10px] text-gray-400 font-medium whitespace-nowrap">
                      {note.fromDate.toLocaleDateString("en-AU", { day: "numeric", month: "short" })}
                      {note.toDate.toDateString() !== note.fromDate.toDateString() && (
                        <> – {note.toDate.toLocaleDateString("en-AU", { day: "numeric", month: "short" })}</>
                      )}
                    </span>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* VIEW LOG */}
          <div className="flex-1 bg-white rounded-2xl border border-gray-100 flex flex-col overflow-hidden shadow-sm">
            <div className="px-5 py-3.5 border-b border-gray-50 flex items-center justify-between flex-shrink-0">
              <span className="text-[13px] font-black tracking-widest text-gray-900 uppercase">View Log</span>
              <Link href="/activity" className="text-[12px] font-bold text-blue-600 hover:underline tracking-wide">
                VIEW ALL
              </Link>
            </div>
            <div className="flex-1 overflow-y-auto">
              {loading ? (
                <div className="px-5 py-6 text-sm text-gray-300">Loading...</div>
              ) : recentActivity.length === 0 ? (
                <div className="px-5 py-8 text-[13px] text-gray-700 text-center">No recent activity.</div>
              ) : (
                <div className="divide-y divide-gray-50">
                  {recentActivity.map(log => (
                    <div key={log.id} className="px-5 py-3">
                      <div className="flex items-center gap-2 mb-0.5">
                        <div className={`w-5 h-5 rounded-full flex items-center justify-center text-[9px] font-bold flex-shrink-0 ${
                          log.actorRole === "driver" ? "bg-blue-100 text-blue-700" : "bg-purple-100 text-purple-700"
                        }`}>
                          {log.actorName?.charAt(0) ?? "?"}
                        </div>
                        <span className="text-xs font-bold text-gray-900 truncate">{log.actorName}</span>
                        <span className={`ml-auto text-[9px] font-bold px-1.5 py-0.5 rounded-full flex-shrink-0 ${
                          log.actorRole === "driver" ? "bg-blue-50 text-blue-600" : "bg-purple-50 text-purple-600"
                        }`}>
                          {log.actorRole?.toUpperCase()}
                        </span>
                      </div>
                      <div className="text-[11px] text-gray-700 leading-snug pl-7">{log.action}</div>
                      <div className="text-[10px] text-gray-900 pl-7 mt-0.5">
                        {log.timestamp instanceof Date
                          ? log.timestamp.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
                          : ""}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* RIGHT container — Today's Schedule Gantt */}
        <div className="flex-1 min-w-0 bg-white rounded-2xl border border-gray-100 flex flex-col overflow-hidden shadow-sm">

          {/* Section 1: Date navigation */}
          <div className="px-5 py-3.5 border-b border-gray-50 flex-shrink-0">
            <div className="flex items-center justify-between">
              <button
                onClick={() => shiftDay(-1)}
                className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-gray-100 text-gray-900 transition-colors"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <polyline points="15 18 9 12 15 6" />
                </svg>
              </button>

              <div className="text-center">
                <div className="text-[13px] font-black tracking-widest text-gray-900 uppercase">{dateLabelShort()}</div>
                <div className="text-[12px] font-bold text-gray-900 tracking-wide">{viewDate.toLocaleDateString("en-AU", { day: "numeric", month: "long", year: "numeric" })}</div>
              </div>

              <button
                onClick={() => shiftDay(1)}
                className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-gray-100 text-gray-900 transition-colors"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <polyline points="9 18 15 12 9 6" />
                </svg>
              </button>
            </div>

            {/* Quick nav: Today button */}
            {!isToday(viewDate) && (
              <div className="flex justify-center mt-2">
                <button
                  onClick={() => setViewDate(new Date())}
                  className="text-[10px] font-bold text-blue-600 hover:underline tracking-wide"
                >
                  Back to Today
                </button>
              </div>
            )}
          </div>

          {/* Section 2: Legend pills */}
          <div className="px-5 py-2.5 border-b border-gray-50 flex-shrink-0 flex items-center gap-3">
            <span className="text-[13px] font-black tracking-widest text-gray-900 uppercase">Today&apos;s Schedule</span>
            <div className="flex-1" />
            <span className="inline-flex items-center px-3 py-1 rounded-full bg-green-500 text-white text-[13px] font-black tracking-widest uppercase">
              Pickup
            </span>
            <span className="inline-flex items-center px-3 py-1 rounded-full bg-orange-500 text-white text-[13px] font-black tracking-widest uppercase">
              Dropoff
            </span>
          </div>

          {/* Section 3: Gantt chart */}
          {loading ? (
            <div className="flex-1 flex items-center justify-center text-sm text-gray-300">Loading...</div>
          ) : (
            <GanttChart trips={ganttTrips} />
          )}
        </div>
      </div>
    </div>
  );
}

// ── Percent Stat Card ──────────────────────────────────────────────────────
function PercentCard({
  label, pct, doneLabel, pendingLabel, color, loading,
}: {
  label: string;
  pct: number;
  doneLabel: string;
  pendingLabel: string;
  color: "green" | "orange";
  loading: boolean;
}) {
  const bg = color === "green" ? "bg-green-500" : "bg-orange-500";
  const track = color === "green" ? "bg-green-200" : "bg-orange-200";

  return (
    <div className={`flex-1 rounded-2xl p-4 shadow-sm ${bg}`}>
      <div className="text-[13px] font-black tracking-widest text-white uppercase mb-2">{label}</div>
      {loading ? (
        <div className="text-3xl font-black text-white">—</div>
      ) : (
        <>
          {/* Progress bar with percentage at right end */}
          <div className={`w-full h-7 rounded-full ${track} relative overflow-hidden`}>
            <div
              className="h-full rounded-full bg-white transition-all duration-500"
              style={{ width: `${pct}%` }}
            />
            <span className="absolute inset-y-0 right-3 flex items-center text-[12px] font-black text-white mix-blend-difference tracking-wide">
              {pct}%
            </span>
          </div>
        </>
      )}
    </div>
  );
}

// ── Trip Status Pill ───────────────────────────────────────────────────────
function TripStatusPill({ status }: { status: string }) {
  const map: Record<string, string> = {
    scheduled:  "bg-gray-100 text-gray-700",
    inProgress: "bg-orange-100 text-orange-700",
    completed:  "bg-green-100 text-green-700",
    cancelled:  "bg-red-100 text-red-600",
  };
  const labels: Record<string, string> = {
    scheduled: "Scheduled", inProgress: "In Progress",
    completed: "Completed", cancelled: "Cancelled",
  };
  return (
    <span className={`text-[9px] font-black px-2 py-1 rounded-full tracking-wide ${map[status] ?? map.scheduled}`}>
      {labels[status] ?? status}
    </span>
  );
}

"use client";
import { useEffect, useState } from "react";
import { collection, getDocs, query, orderBy, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Route, Trip, Student } from "@/lib/types";
import PageHeader from "@/components/PageHeader";
import * as XLSX from "xlsx";

// ─── Types ────────────────────────────────────────────────────────────────────

interface TripDay {
  date: string; // "YYYY-MM-DD"
  pickup?: Trip;
  dropoff?: Trip;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
const TERM_MONTHS: Record<number, number[]> = { 1:[1,2,3], 2:[4,5,6], 3:[7,8,9], 4:[10,11,12] };

function toDate(v: unknown): Date {
  if (!v) return new Date();
  if (v instanceof Date) return v;
  if (typeof (v as Timestamp).toDate === "function") return (v as Timestamp).toDate();
  return new Date(v as string);
}

function isoDate(d: Date): string {
  return d.toISOString().split("T")[0];
}

function fmtTime12(d: Date): string {
  return d.toLocaleTimeString("en-AU", { hour: "2-digit", minute: "2-digit", hour12: true });
}

function fmtDateShort(d: Date): string {
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  const yr = String(d.getFullYear()).slice(-2);
  return `${m}-${day}-${yr}`;
}

/** Returns the Monday of the ISO week containing `d`. */
function weekStart(d: Date): Date {
  const copy = new Date(d);
  const dow = copy.getDay(); // 0=Sun
  const diff = dow === 0 ? -6 : 1 - dow;
  copy.setDate(copy.getDate() + diff);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

/** All dates (YYYY-MM-DD) in a given month+year */
function daysInMonth(year: number, month: number): string[] {
  const days: string[] = [];
  const d = new Date(year, month - 1, 1);
  while (d.getMonth() === month - 1) {
    days.push(isoDate(new Date(d)));
    d.setDate(d.getDate() + 1);
  }
  return days;
}

// ─── XLSX generation (mirrors CSVGenerator.swift) ─────────────────────────────

function buildWeeklyXLSX(
  routeName: string,
  students: Student[],
  trips: Trip[],
  weekMon: Date
): void {
  const wb = XLSX.utils.book_new();
  const rows: (string | number | undefined)[][] = [];

  const weekStr = `${fmtDateShort(weekMon)} to ${fmtDateShort(new Date(weekMon.getTime() + 6 * 86400000))}`;

  // Header section
  rows.push([`WEEKLY REPORT - ${weekMon.toLocaleDateString("en-AU", { weekday: "long", year: "numeric", month: "long", day: "numeric" })}`]);
  rows.push([]);
  rows.push(["ROUTE:", routeName]);
  rows.push([]);

  // Column headers — row 1: day groups
  const headerRow1: string[] = ["Name", "Grade"];
  const headerRow2: string[] = ["", ""];
  const weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
  for (const day of weekdays) {
    headerRow1.push(`${day} AM Pickup`, "", `${day} PM Dropoff`, "");
    headerRow2.push("AM Scheduled", "AM Actual", "PM Scheduled", "PM Actual");
  }
  rows.push(headerRow1);
  rows.push(headerRow2);

  // Data rows
  const sortedStudents = [...students].sort((a, b) => a.name.localeCompare(b.name));

  for (const student of sortedStudents) {
    const row: (string | undefined)[] = [student.name, student.grade];

    for (let offset = 0; offset < 5; offset++) {
      const dayDate = new Date(weekMon.getTime() + offset * 86400000);
      const dayStr = isoDate(dayDate);
      const isFuture = dayDate > new Date();

      const pickupTrip = trips.find(t => t.type === "pickup" && (t.date as unknown as string) === dayStr);
      const dropoffTrip = trips.find(t => t.type === "dropoff" && (t.date as unknown as string) === dayStr);

      // AM Scheduled
      row.push(student.scheduledPickupTime ?? "");

      // AM Actual
      if (isFuture) {
        row.push("");
      } else if (pickupTrip) {
        const rec = pickupTrip.studentRecords?.find(r => r.id === student.id);
        if (rec?.status === "onBus" && rec.timestamp) {
          row.push(fmtTime12(toDate(rec.timestamp)));
        } else {
          row.push("Absent");
        }
      } else {
        row.push("");
      }

      // PM Scheduled
      row.push(student.scheduledDropoffTime ?? "");

      // PM Actual
      if (isFuture) {
        row.push("");
      } else if (dropoffTrip) {
        const rec = dropoffTrip.studentRecords?.find(r => r.id === student.id);
        if (rec?.status === "offBus" && rec.timestamp) {
          row.push(fmtTime12(toDate(rec.timestamp)));
        } else {
          row.push("Absent");
        }
      } else {
        row.push("");
      }
    }

    rows.push(row);
  }

  rows.push([]);

  // Journey Start Time row
  const journeyRow: string[] = ["Journey Start Time", ""];
  for (let offset = 0; offset < 5; offset++) {
    const dayStr = isoDate(new Date(weekMon.getTime() + offset * 86400000));
    const pickupTrip = trips.find(t => t.type === "pickup" && (t.date as unknown as string) === dayStr);
    const dropoffTrip = trips.find(t => t.type === "dropoff" && (t.date as unknown as string) === dayStr);
    journeyRow.push(""); // AM sched blank
    journeyRow.push(pickupTrip?.startedAt ? fmtTime12(toDate(pickupTrip.startedAt)) : "");
    journeyRow.push(""); // PM sched blank
    journeyRow.push(dropoffTrip?.startedAt ? fmtTime12(toDate(dropoffTrip.startedAt)) : "");
  }
  rows.push(journeyRow);

  // No Child Left On Bus row
  const finalCheckRow: string[] = ["No Child Left On Bus", ""];
  for (let offset = 0; offset < 5; offset++) {
    const dayStr = isoDate(new Date(weekMon.getTime() + offset * 86400000));
    const pickupTrip = trips.find(t => t.type === "pickup" && (t.date as unknown as string) === dayStr);
    const dropoffTrip = trips.find(t => t.type === "dropoff" && (t.date as unknown as string) === dayStr);
    finalCheckRow.push(""); // AM sched blank
    finalCheckRow.push(pickupTrip?.completedAt ? fmtTime12(toDate(pickupTrip.completedAt)) : "");
    finalCheckRow.push(""); // PM sched blank
    finalCheckRow.push(dropoffTrip?.completedAt ? fmtTime12(toDate(dropoffTrip.completedAt)) : "");
  }
  rows.push(finalCheckRow);
  rows.push([]);

  // Travel Notes
  rows.push(["TRAVEL NOTES", ...Array(21).fill("")]);
  rows.push(["Student Name", "Notes", ...Array(20).fill("")]);
  // (no static notes in admin view — placeholder row)
  rows.push([]);

  const ws = XLSX.utils.aoa_to_sheet(rows);
  XLSX.utils.book_append_sheet(wb, ws, "Weekly Report");

  const sanitized = routeName.replace(/[:/\\?%*|"<> ]/g, "_");
  XLSX.writeFile(wb, `${sanitized}_${weekStr}.xlsx`);
}

function buildSingleSessionXLSX(
  routeName: string,
  students: Student[],
  trip: Trip
): void {
  const wb = XLSX.utils.book_new();
  const rows: (string | undefined)[][] = [];

  const sessionTypeName = trip.type === "pickup" ? "AM Pickup" : "PM Dropoff";
  const tripDate = trip.date;
  const tripDateFormatted = new Date(tripDate + "T00:00:00").toLocaleDateString("en-AU", { weekday: "long", year: "numeric", month: "long", day: "numeric" });

  rows.push([`SESSION REPORT - ${sessionTypeName} - ${tripDateFormatted}`]);
  rows.push([]);
  rows.push(["ROUTE:", routeName]);
  rows.push([]);

  const shortDate = fmtDateShort(new Date(tripDate + "T00:00:00"));
  rows.push(["Name", `${shortDate} AM Pickup`, `${shortDate} PM Dropoff`]);

  const sortedStudents = [...students].sort((a, b) => a.name.localeCompare(b.name));

  for (const student of sortedStudents) {
    const rec = trip.studentRecords?.find(r => r.id === student.id);
    const pickupVal = trip.type === "pickup"
      ? (rec?.status === "onBus" && rec.timestamp ? fmtTime12(toDate(rec.timestamp)) : "Absent")
      : "";
    const dropoffVal = trip.type === "dropoff"
      ? (rec?.status === "offBus" && rec.timestamp ? fmtTime12(toDate(rec.timestamp)) : "Absent")
      : "";
    rows.push([student.name, pickupVal, dropoffVal]);
  }

  rows.push([]);
  const journeyTime = trip.startedAt ? fmtTime12(toDate(trip.startedAt)) : "";
  const finalTime = trip.completedAt ? fmtTime12(toDate(trip.completedAt)) : "";

  rows.push([
    "Journey Start Time",
    trip.type === "pickup" ? journeyTime : "",
    trip.type === "dropoff" ? journeyTime : "",
  ]);
  rows.push([
    "No Child Left On Bus",
    trip.type === "pickup" ? finalTime : "",
    trip.type === "dropoff" ? finalTime : "",
  ]);
  rows.push([]);
  rows.push(["TRAVEL NOTES", "", ""]);
  rows.push(["Student Name", "Notes", ""]);
  rows.push([]);

  const ws = XLSX.utils.aoa_to_sheet(rows);
  XLSX.utils.book_append_sheet(wb, ws, "Session Report");

  const sanitized = routeName.replace(/[:/\\?%*|"<> ]/g, "_");
  const timeStr = trip.startedAt
    ? fmtTime12(toDate(trip.startedAt)).replace(/:/g, "-").replace(/ /g, "_")
    : "00-00_AM";
  const typeTag = trip.type === "pickup" ? "AMPickup" : "PMDropoff";
  XLSX.writeFile(wb, `Session_${sanitized}_${typeTag}_${fmtDateShort(new Date(tripDate + "T00:00:00"))}_${timeStr}.xlsx`);
}

// ─── Calendar component ───────────────────────────────────────────────────────

function RouteCalendar({
  year, month, tripDays, onSelectDate,
}: {
  year: number;
  month: number;
  tripDays: Record<string, TripDay>;
  onSelectDate: (date: string) => void;
}) {
  const days = daysInMonth(year, month);
  const firstDow = new Date(year, month - 1, 1).getDay(); // 0=Sun

  const cells: (string | null)[] = [
    ...Array(firstDow === 0 ? 6 : firstDow - 1).fill(null), // Mon-start padding
    ...days,
  ];

  // Pad to complete grid rows
  while (cells.length % 7 !== 0) cells.push(null);

  return (
    <div>
      {/* Weekday labels */}
      <div className="grid grid-cols-7 mb-1">
        {["Mon","Tue","Wed","Thu","Fri","Sat","Sun"].map(d => (
          <div key={d} className="text-center text-[10px] font-black tracking-widest text-gray-400 uppercase py-1">{d}</div>
        ))}
      </div>

      {/* Day cells */}
      <div className="grid grid-cols-7 gap-1">
        {cells.map((dateStr, i) => {
          if (!dateStr) return <div key={i} />;
          const td = tripDays[dateStr];
          const hasPickup = !!td?.pickup;
          const hasDropoff = !!td?.dropoff;
          const hasAny = hasPickup || hasDropoff;
          const dow = new Date(dateStr + "T00:00:00").getDay();
          const isWeekend = dow === 0 || dow === 6;

          return (
            <button
              key={dateStr}
              onClick={() => hasAny && onSelectDate(dateStr)}
              disabled={!hasAny}
              className={`
                aspect-square flex flex-col items-center justify-center rounded-xl text-xs font-bold transition-all
                ${hasAny
                  ? "cursor-pointer hover:scale-105 hover:shadow-md"
                  : isWeekend ? "opacity-20 cursor-default" : "cursor-default text-gray-300"}
                ${hasPickup && hasDropoff ? "bg-purple-100 text-purple-700 border border-purple-200" : ""}
                ${hasPickup && !hasDropoff ? "bg-green-100 text-green-700 border border-green-200" : ""}
                ${!hasPickup && hasDropoff ? "bg-orange-100 text-orange-700 border border-orange-200" : ""}
                ${!hasAny ? "bg-transparent" : ""}
              `}
            >
              <span>{new Date(dateStr + "T00:00:00").getDate()}</span>
              {hasAny && (
                <div className="flex gap-0.5 mt-0.5">
                  {hasPickup && <span className="w-1 h-1 rounded-full bg-green-500" />}
                  {hasDropoff && <span className="w-1 h-1 rounded-full bg-orange-400" />}
                </div>
              )}
            </button>
          );
        })}
      </div>

      {/* Legend */}
      <div className="flex gap-4 mt-3 text-[10px] font-bold text-gray-500">
        <div className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-green-500" />Pickup</div>
        <div className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-orange-400" />Dropoff</div>
        <div className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-purple-500" />Both</div>
      </div>
    </div>
  );
}

// ─── Day detail panel ─────────────────────────────────────────────────────────

function DayDetail({
  dateStr, tripDay, students, routeName, onClose,
}: {
  dateStr: string;
  tripDay: TripDay;
  students: Student[];
  routeName: string;
  onClose: () => void;
}) {
  const date = new Date(dateStr + "T00:00:00");
  const dateLabel = date.toLocaleDateString("en-AU", { weekday: "long", day: "numeric", month: "long", year: "numeric" });

  const renderRecords = (trip: Trip) =>
    students.map(s => {
      const rec = trip.studentRecords?.find(r => r.id === s.id);
      return (
        <div key={s.id} className="flex items-center justify-between py-1.5 border-b border-gray-50 last:border-0">
          <div>
            <div className="text-xs font-bold text-gray-900">{s.name}</div>
            <div className="text-[10px] text-gray-400">Grade {s.grade}</div>
          </div>
          <div className="text-right">
            {rec?.status === "onBus" || rec?.status === "offBus" ? (
              <span className="text-xs font-bold text-green-600">
                {rec.timestamp ? fmtTime12(toDate(rec.timestamp)) : "Present"}
              </span>
            ) : (
              <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${
                rec?.status === "absent" ? "bg-red-100 text-red-600" : "bg-gray-100 text-gray-400"
              }`}>
                {rec?.status === "absent" ? "Absent" : "—"}
              </span>
            )}
          </div>
        </div>
      );
    });

  return (
    <div className="bg-white rounded-2xl border border-gray-100 p-5 mt-4">
      <div className="flex items-center justify-between mb-4">
        <div>
          <div className="text-xs font-black tracking-widest text-gray-400 uppercase mb-0.5">Selected Date</div>
          <div className="text-sm font-bold text-gray-900">{dateLabel}</div>
        </div>
        <button onClick={onClose} className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center hover:bg-gray-200 transition-colors">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Pickup */}
        {tripDay.pickup && (
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-green-500" />
                <span className="text-xs font-black tracking-widest text-gray-700 uppercase">AM Pickup</span>
              </div>
              <button
                onClick={() => buildSingleSessionXLSX(routeName, students, tripDay.pickup!)}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-green-50 text-green-700 text-[10px] font-black rounded-lg hover:bg-green-100 transition-colors"
              >
                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>
                </svg>
                XLSX
              </button>
            </div>
            <div className="bg-gray-50 rounded-xl px-4 py-2">
              {renderRecords(tripDay.pickup)}
            </div>
            {tripDay.pickup.startedAt && (
              <div className="text-[10px] text-gray-400 mt-1.5 pl-1">
                Journey start: {fmtTime12(toDate(tripDay.pickup.startedAt))}
                {tripDay.pickup.completedAt && <> · Final check: {fmtTime12(toDate(tripDay.pickup.completedAt))}</>}
              </div>
            )}
          </div>
        )}

        {/* Dropoff */}
        {tripDay.dropoff && (
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-orange-400" />
                <span className="text-xs font-black tracking-widest text-gray-700 uppercase">PM Dropoff</span>
              </div>
              <button
                onClick={() => buildSingleSessionXLSX(routeName, students, tripDay.dropoff!)}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-orange-50 text-orange-700 text-[10px] font-black rounded-lg hover:bg-orange-100 transition-colors"
              >
                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>
                </svg>
                XLSX
              </button>
            </div>
            <div className="bg-gray-50 rounded-xl px-4 py-2">
              {renderRecords(tripDay.dropoff)}
            </div>
            {tripDay.dropoff.startedAt && (
              <div className="text-[10px] text-gray-400 mt-1.5 pl-1">
                Journey start: {fmtTime12(toDate(tripDay.dropoff.startedAt))}
                {tripDay.dropoff.completedAt && <> · Final check: {fmtTime12(toDate(tripDay.dropoff.completedAt))}</>}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Weekly XLSX */}
      <div className="mt-4 pt-4 border-t border-gray-100 flex justify-end">
        <button
          onClick={() => {
            const mon = weekStart(new Date(dateStr + "T00:00:00"));
            buildWeeklyXLSX(routeName, students, [
              ...(tripDay.pickup ? [tripDay.pickup] : []),
              ...(tripDay.dropoff ? [tripDay.dropoff] : []),
            ], mon);
          }}
          className="flex items-center gap-2 px-4 py-2 bg-purple-50 text-purple-700 text-xs font-black rounded-xl hover:bg-purple-100 transition-colors"
        >
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>
          </svg>
          DOWNLOAD WEEKLY XLSX
        </button>
      </div>
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function RouteLogPage() {
  const [routes, setRoutes] = useState<Route[]>([]);
  const [trips, setTrips] = useState<Trip[]>([]);
  const [students, setStudents] = useState<Student[]>([]);
  const [loading, setLoading] = useState(true);

  const [years, setYears] = useState<number[]>([]);
  const [selYear, setSelYear] = useState<number | null>(null);
  const [selTerm, setSelTerm] = useState<number | null>(null);
  const [selRouteId, setSelRouteId] = useState<string | null>(null);
  const [selMonth, setSelMonth] = useState<number | null>(null);
  const [selDate, setSelDate] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([
      getDocs(collection(db, "routes")),
      getDocs(query(collection(db, "trips"), orderBy("date", "desc"))),
      getDocs(collection(db, "students")),
    ]).then(([routeSnap, tripSnap, studentSnap]) => {
      const r = routeSnap.docs.map(d => ({ id: d.id, ...d.data() } as Route));
      // Normalize trip.date to "YYYY-MM-DD" string for easy comparisons
      const t = tripSnap.docs.map(d => {
        const data = d.data();
        const dateObj = toDate(data.date);
        return {
          id: d.id,
          ...data,
          date: isoDate(dateObj), // override with normalized string
        } as unknown as Trip;
      });
      const s = studentSnap.docs.map(d => ({ id: d.id, ...d.data() } as Student));

      setRoutes(r);
      setTrips(t);
      setStudents(s);

      // Derive available years from trip dates
      const ys = [...new Set(t.map(trip => new Date(trip.date + "T00:00:00").getFullYear()))].sort((a, b) => b - a);
      setYears(ys);
      if (ys.length) setSelYear(ys[0]);
      setLoading(false);
    });
  }, []);

  // Filtered routes: those that ran in the selected year/term
  const termTrips = trips.filter(t => {
    const d = new Date(t.date + "T00:00:00");
    const yr = d.getFullYear();
    const mo = d.getMonth() + 1;
    if (selYear && yr !== selYear) return false;
    if (selTerm && !TERM_MONTHS[selTerm].includes(mo)) return false;
    return true;
  });

  const activeRouteIds = [...new Set(termTrips.map(t => t.routeId))];
  const filteredRoutes = routes.filter(r => activeRouteIds.includes(r.id));

  // Trips for the selected route in the selected year/term
  const routeTrips = selRouteId ? termTrips.filter(t => t.routeId === selRouteId) : [];

  // Build a map: date → { pickup?, dropoff? }
  const tripDayMap: Record<string, TripDay> = {};
  for (const trip of routeTrips) {
    const tripDateKey = trip.date as unknown as string;
    if (!tripDayMap[tripDateKey]) tripDayMap[tripDateKey] = { date: tripDateKey };
    if (trip.type === "pickup") tripDayMap[tripDateKey].pickup = trip;
    if (trip.type === "dropoff") tripDayMap[tripDateKey].dropoff = trip;
  }

  // Months that have trips for this route
  const availableMonths = selRouteId
    ? [...new Set(routeTrips.map(t => new Date(t.date + "T00:00:00").getMonth() + 1))].sort()
    : [];

  const displayMonth = selMonth ?? (availableMonths[0] ?? (selYear ? (selTerm ? TERM_MONTHS[selTerm][0] : new Date().getMonth() + 1) : new Date().getMonth() + 1));
  const displayYear = selYear ?? new Date().getFullYear();

  const selectedRoute = routes.find(r => r.id === selRouteId);
  const routeStudents = selectedRoute
    ? students.filter(s => selectedRoute.studentIds?.includes(s.id) && s.isActive)
    : [];

  const availableTerms = selYear
    ? [...new Set(trips.filter(t => new Date(t.date + "T00:00:00").getFullYear() === selYear)
        .map(t => Math.ceil((new Date(t.date + "T00:00:00").getMonth() + 1) / 3)))].sort()
    : [];

  return (
    <div className="max-w-5xl mx-auto">
      <PageHeader
        title="VIEW LOG"
        subtitle="Route Log"
        breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "View Log" }, { label: "Route Log" }]}
        accent="purple"
      />

      {/* Year / Term filters */}
      <div className="flex flex-wrap gap-3 mb-6">
        <div className="flex gap-1.5 flex-wrap">
          {years.map(y => (
            <button key={y} onClick={() => { setSelYear(y); setSelTerm(null); setSelRouteId(null); setSelMonth(null); setSelDate(null); }}
              className={`px-3 py-1.5 rounded-lg text-xs font-black tracking-wide transition-colors ${selYear === y ? "bg-purple-600 text-white" : "bg-white border border-gray-200 text-gray-700 hover:bg-gray-50"}`}>
              {y}
            </button>
          ))}
        </div>

        {availableTerms.length > 0 && (
          <div className="flex gap-1.5">
            {availableTerms.map(t => (
              <button key={t} onClick={() => { setSelTerm(selTerm === t ? null : t); setSelRouteId(null); setSelMonth(null); setSelDate(null); }}
                className={`px-3 py-1.5 rounded-lg text-xs font-black tracking-wide transition-colors ${selTerm === t ? "bg-purple-600 text-white" : "bg-white border border-gray-200 text-gray-700 hover:bg-gray-50"}`}>
                Term {t}
              </button>
            ))}
          </div>
        )}
      </div>

      {loading ? (
        <p className="text-sm text-gray-300">Loading...</p>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-[240px_1fr] gap-6">

          {/* Route selector */}
          <div className="space-y-1">
            <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">Routes</div>
            {filteredRoutes.length === 0 ? (
              <p className="text-xs text-gray-400">No routes for this period.</p>
            ) : filteredRoutes.map(route => (
              <button key={route.id}
                onClick={() => { setSelRouteId(route.id); setSelMonth(null); setSelDate(null); }}
                className={`w-full text-left px-4 py-3 rounded-xl text-sm font-bold transition-colors ${selRouteId === route.id ? "bg-purple-600 text-white" : "bg-white border border-gray-100 text-gray-800 hover:bg-gray-50"}`}
              >
                {route.name}
              </button>
            ))}
          </div>

          {/* Calendar + detail */}
          <div>
            {!selRouteId ? (
              <div className="text-center py-16 text-gray-400 text-sm">Select a route to view its calendar.</div>
            ) : (
              <>
                {/* Month tabs */}
                {availableMonths.length > 1 && (
                  <div className="flex gap-1.5 flex-wrap mb-4">
                    {availableMonths.map(m => (
                      <button key={m} onClick={() => { setSelMonth(m); setSelDate(null); }}
                        className={`px-3 py-1.5 rounded-lg text-xs font-black tracking-wide transition-colors ${displayMonth === m ? "bg-purple-600 text-white" : "bg-white border border-gray-200 text-gray-700 hover:bg-gray-50"}`}>
                        {MONTHS[m - 1]}
                      </button>
                    ))}
                  </div>
                )}

                <div className="bg-white rounded-2xl border border-gray-100 p-5">
                  <div className="text-sm font-black text-gray-900 mb-4">
                    {MONTHS[displayMonth - 1]} {displayYear}
                    <span className="ml-2 text-[10px] font-bold text-gray-400 uppercase tracking-widest">
                      {Object.keys(tripDayMap).filter(d => new Date(d + "T00:00:00").getMonth() + 1 === displayMonth).length} trip days
                    </span>
                  </div>

                  <RouteCalendar
                    year={displayYear}
                    month={displayMonth}
                    tripDays={tripDayMap}
                    onSelectDate={d => setSelDate(selDate === d ? null : d)}
                  />
                </div>

                {/* Day detail */}
                {selDate && tripDayMap[selDate] && (
                  <DayDetail
                    dateStr={selDate}
                    tripDay={tripDayMap[selDate]}
                    students={routeStudents}
                    routeName={selectedRoute?.name ?? "Route"}
                    onClose={() => setSelDate(null)}
                  />
                )}
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

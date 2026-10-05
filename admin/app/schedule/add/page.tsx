"use client";
import { useEffect, useState, useRef } from "react";
import { collection, getDocs, addDoc, writeBatch, doc, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Driver } from "@/lib/types";
import PageHeader from "@/components/PageHeader";
import { useRouter } from "next/navigation";

/** Normalise a raw phone string from XLSX to E.164 +61 format.
 *  "0430040000" → "+61430040000"
 *  "+61430040000" → "+61430040000"
 *  "430040000" → "+61430040000"
 */
function normalisePhone(raw: string): string {
  const s = String(raw ?? "").trim();
  if (!s) return "";
  if (s.startsWith("+61")) return s;
  if (s.startsWith("0")) return `+61${s.slice(1)}`;
  return `+61${s}`;
}

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-base text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-200 focus:border-orange-400 transition";
const DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

interface XlsxRow {
  name: string; grade: string;
  orderAM: string; pickupTime: string;
  orderPM: string; dropoffTime: string;
  stopAM: string; stopPM: string;
  parentPhone: string; parentName: string;
  studentPhone: string; relationship: string;
}

export default function AddSchedulePage() {
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [form, setForm] = useState({ routeName: "", driverId: "", term: "1", year: String(new Date().getFullYear()), startDate: "", endDate: "" });
  const [selectedDays, setSelectedDays] = useState<string[]>(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]);
  const [preview, setPreview] = useState<XlsxRow[]>([]);
  const [fileError, setFileError] = useState("");
  const [saving, setSaving] = useState(false);
  const [success, setSuccess] = useState(false);
  const [tripCount, setTripCount] = useState(0);
  const [templateCount, setTemplateCount] = useState(10);

  useEffect(() => {
    getDocs(collection(db, "drivers")).then(snap => {
      setDrivers(snap.docs.filter(d => d.data().isActive).map(d => ({ id: d.id, ...d.data() } as Driver)));
    });
  }, []);

  const set = (k: string, v: string) => setForm(f => ({ ...f, [k]: v }));
  const toggleDay = (day: string) => setSelectedDays(prev => prev.includes(day) ? prev.filter(d => d !== day) : [...prev, day]);

  // Parse uploaded xlsx using SheetJS (loaded via CDN in this simple version via manual parse)
  const handleFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setFileError("");
    setPreview([]);

    // Dynamic import of xlsx
    try {
      const XLSX = await import("xlsx");
      const data = await file.arrayBuffer();
      const wb = XLSX.read(data, { type: "array" });
      const ws = wb.Sheets[wb.SheetNames[0]];
      const rows = XLSX.utils.sheet_to_json<string[]>(ws, { header: 1 }) as string[][];

      // Columns A–L (indices 0–11):
      // A: Student Name | B: Grade | C: Order AM | D: Scheduled AM | E: Order PM | F: Scheduled PM
      // G: STOP Location AM | H: STOP Location PM | I: Parent 1 Phone | J: Parent 1 Name
      // K: Student Phone | L: Relationship
      const parsed: XlsxRow[] = rows.slice(1).filter(r => r[0]).map(r => ({
        name: String(r[0] ?? ""), grade: String(r[1] ?? ""),
        orderAM: String(r[2] ?? ""), pickupTime: String(r[3] ?? ""),
        orderPM: String(r[4] ?? ""), dropoffTime: String(r[5] ?? ""),
        stopAM: String(r[6] ?? ""), stopPM: String(r[7] ?? ""),
        parentPhone: normalisePhone(String(r[8] ?? "")), parentName: String(r[9] ?? ""),
        studentPhone: normalisePhone(String(r[10] ?? "")), relationship: String(r[11] ?? ""),
      }));
      setPreview(parsed);
    } catch {
      setFileError("Could not parse file. Make sure it is a valid .xlsx file.");
    }
  };

  /** Returns all dates in [startDate, endDate] that fall on selectedDays */
  const getScheduledDates = (start: Date, end: Date, days: string[]): Date[] => {
    const dayIndexMap: Record<string, number> = { Sunday: 0, Monday: 1, Tuesday: 2, Wednesday: 3, Thursday: 4, Friday: 5, Saturday: 6 };
    const allowed = new Set(days.map(d => dayIndexMap[d]));
    const dates: Date[] = [];
    const cur = new Date(start);
    while (cur <= end) {
      if (allowed.has(cur.getDay())) dates.push(new Date(cur));
      cur.setDate(cur.getDate() + 1);
    }
    return dates;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.driverId || !form.startDate || !form.endDate) return;
    setSaving(true);

    try {
      const batch = writeBatch(db);
      const startDate = new Date(form.startDate);
      const endDate = new Date(form.endDate);
      const scheduledDates = getScheduledDates(startDate, endDate, selectedDays);

      // 1. Create route doc first so we have the ID for student routeId
      const routeRef = doc(collection(db, "routes"));

      // 2. Create student docs and collect IDs
      const studentIds: string[] = [];
      const studentRecordTemplate: { id: string; studentName: string; stopAddressAM: string; stopAddressPM: string; status: string; timestamp: null }[] = [];

      for (const row of preview) {
        const studentRef = doc(collection(db, "students"));
        const parents = row.parentName || row.parentPhone
          ? [{ name: row.parentName, phone: row.parentPhone, canAccess: true, relationship: row.relationship }]
          : [];
        batch.set(studentRef, {
          name: row.name, grade: row.grade,
          stopAddressAM: row.stopAM, stopAddressPM: row.stopPM,
          routeId: routeRef.id,
          scheduledPickupTime: row.pickupTime, scheduledDropoffTime: row.dropoffTime,
          phone: row.studentPhone, parents, authorisedParentIds: [],
          isActive: true, createdAt: Timestamp.now(),
        });
        studentIds.push(studentRef.id);
        studentRecordTemplate.push({ id: studentRef.id, studentName: row.name, stopAddressAM: row.stopAM, stopAddressPM: row.stopPM, status: "pending", timestamp: null });
      }
      batch.set(routeRef, {
        name: form.routeName.trim(), driverId: form.driverId,
        term: parseInt(form.term), year: parseInt(form.year),
        scheduledDays: selectedDays,
        startDate: Timestamp.fromDate(startDate), endDate: Timestamp.fromDate(endDate),
        studentIds, isActive: true, createdAt: Timestamp.now(),
      });

      // 3. Create pickup + dropoff trip for every scheduled date
      let count = 0;
      for (const date of scheduledDates) {
        for (const type of ["pickup", "dropoff"] as const) {
          const tripRef = doc(collection(db, "trips"));
          batch.set(tripRef, {
            routeId: routeRef.id, driverId: form.driverId,
            date: Timestamp.fromDate(date), type,
            status: "scheduled",
            studentRecords: studentRecordTemplate,
            startedAt: null, completedAt: null,
          });
          count++;
        }
      }

      await batch.commit();
      setTripCount(count);
      setSuccess(true);
      setTimeout(() => router.push("/schedule"), 2000);
    } catch (err) { console.error(err); }
    setSaving(false);
  };

  return (
    <div className="max-w-3xl mx-auto">
      <PageHeader title="SCHEDULE" subtitle="Add Schedule" breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Schedule", href: "/schedule" }, { label: "Add" }]} accent="orange" />

      {success && (
        <div className="mb-6 px-4 py-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-xl">
          Schedule created with {preview.length} students and {tripCount} trips. Redirecting...
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-5">
        {/* Route details */}
        <div className="bg-white rounded-2xl border border-gray-100 p-6 space-y-4">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">Route Details</p>
          <div className="grid grid-cols-2 gap-4">
            <div className="col-span-2"><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Route Name</label><input className={FIELD} required value={form.routeName} onChange={e => set("routeName", e.target.value)} placeholder="e.g. Route A — Parramatta" /></div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Assign Driver</label>
              <select className={FIELD} required value={form.driverId} onChange={e => set("driverId", e.target.value)}>
                <option value="">— select driver —</option>
                {drivers.map(d => <option key={d.id} value={d.id}>{d.name}</option>)}
              </select>
            </div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Term</label>
              <select className={FIELD} value={form.term} onChange={e => set("term", e.target.value)}>
                {["1","2","3","4"].map(t => <option key={t} value={t}>Term {t}</option>)}
              </select>
            </div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Start Date</label><input className={FIELD} type="date" required value={form.startDate} onChange={e => set("startDate", e.target.value)} /></div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">End Date</label><input className={FIELD} type="date" required value={form.endDate} onChange={e => set("endDate", e.target.value)} /></div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Scheduled Days</label>
            <div className="flex flex-wrap gap-2">
              {DAYS.map(day => (
                <button key={day} type="button" onClick={() => toggleDay(day)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${selectedDays.includes(day) ? "bg-orange-500 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"}`}>
                  {day.slice(0, 3)}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Student upload */}
        <div className="bg-white rounded-2xl border border-gray-100 p-6 space-y-4">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">Student List (.xlsx)</p>

          {/* Template download card */}
          <div className="bg-blue-50 rounded-xl p-4">
            <p className="text-sm font-bold text-blue-700 mb-3">How many students on this route?</p>
            <div className="flex items-center gap-3">
              <input
                type="number" min={1} value={templateCount}
                onChange={e => setTemplateCount(Math.max(1, parseInt(e.target.value) || 1))}
                className="w-20 bg-white border border-gray-200 rounded-lg px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-200"
              />
              <button type="button" onClick={async () => {
                const XLSX = await import("xlsx");
                const headers = [["Student Name", "Grade", "Order AM", "Scheduled AM", "Order PM", "Scheduled PM", "STOP Location AM", "STOP Location PM", "Parent 1 Phone", "Parent 1 Name", "Student Phone", "Relationship"]];
                const blankRows = Array.from({ length: templateCount }, () => Array(12).fill(""));
                const ws = XLSX.utils.aoa_to_sheet([...headers, ...blankRows]);
                const wb = XLSX.utils.book_new();
                XLSX.utils.book_append_sheet(wb, ws, "Students");
                XLSX.writeFile(wb, "schedule_template.xlsx");
              }} className="px-4 py-2 bg-blue-600 text-white text-sm font-semibold rounded-lg hover:bg-blue-700 transition-colors">
                Download
              </button>
            </div>
          </div>

          {/* Compact column list */}
          <p className="text-xs text-gray-400">
            Columns: Name · Grade · Order AM · Scheduled AM · Order PM · Scheduled PM · STOP AM · STOP PM · Parent Phone · Parent Name · Student Phone · Relationship
          </p>

          {/* Upload zone */}
          <button type="button" onClick={() => fileRef.current?.click()}
            className="w-full border-2 border-dashed border-orange-200 rounded-xl py-8 text-sm text-orange-400 hover:border-orange-300 hover:text-orange-500 transition-colors">
            {preview.length > 0 ? "Replace file — click to upload again" : "Click to upload .xlsx file"}
          </button>
          {fileError && <p className="text-xs text-red-500">{fileError}</p>}

          {/* Student count stat + preview */}
          {preview.length > 0 && (
            <div className="space-y-3">
              {/* Stat card */}
              <div className="flex items-center gap-4 bg-orange-50 rounded-xl px-4 py-3">
                <div className="w-10 h-10 rounded-xl bg-orange-100 flex items-center justify-center flex-shrink-0">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ea580c" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                  </svg>
                </div>
                <div>
                  <p className="text-[10px] font-black tracking-widest text-orange-400 uppercase">Students on this route</p>
                  <p className="text-2xl font-black text-orange-600 leading-tight">{preview.length}</p>
                </div>
              </div>

              {/* Preview table */}
              <div className="rounded-xl border border-gray-100 overflow-hidden">
                <table className="w-full text-xs">
                  <thead className="bg-gray-50">
                    <tr className="text-gray-400">
                      <th className="px-3 py-2 text-left font-medium">Name</th>
                      <th className="px-3 py-2 text-left font-medium">Grade</th>
                      <th className="px-3 py-2 text-left font-medium">Stop AM</th>
                      <th className="px-3 py-2 text-left font-medium">Stop PM</th>
                      <th className="px-3 py-2 text-left font-medium">Pick-up</th>
                      <th className="px-3 py-2 text-left font-medium">Drop-off</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {preview.slice(0, 5).map((r, i) => (
                      <tr key={i}>
                        <td className="px-3 py-2 text-gray-700 font-medium">{r.name}</td>
                        <td className="px-3 py-2 text-gray-500">{r.grade}</td>
                        <td className="px-3 py-2 text-gray-500">{r.stopAM}</td>
                        <td className="px-3 py-2 text-gray-500">{r.stopPM}</td>
                        <td className="px-3 py-2 text-gray-500">{r.pickupTime}</td>
                        <td className="px-3 py-2 text-gray-500">{r.dropoffTime}</td>
                      </tr>
                    ))}
                    {preview.length > 5 && (
                      <tr><td colSpan={6} className="px-3 py-2 text-gray-400 text-center">…and {preview.length - 5} more</td></tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>

        <div className="flex justify-end gap-3">
          <button type="button" onClick={() => router.push("/schedule")} className="px-6 py-3 text-base text-gray-500 hover:text-gray-700">Cancel</button>
          <button type="submit" disabled={saving || preview.length === 0}
            className="px-6 py-3 bg-orange-500 text-white text-base font-semibold rounded-xl hover:bg-orange-600 disabled:opacity-50 transition-colors">
            {saving ? "Creating schedule..." : "Create Schedule & Generate Trips"}
          </button>
        </div>
      </form>
    </div>
  );
}

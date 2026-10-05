"use client";
import { useEffect, useState, useCallback, useRef } from "react";
import { collection, getDocs, doc, updateDoc, writeBatch, query, orderBy, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Route, Driver } from "@/lib/types";
import PageHeader from "@/components/PageHeader";
import SubstituteDriverModal from "./SubstituteDriverModal";

// ── Helpers ─────────────────────────────────────────────────────────────────

function toDate(v: unknown): Date {
  if (!v) return new Date();
  if (v instanceof Date) return v;
  if (typeof (v as Timestamp).toDate === "function") return (v as Timestamp).toDate();
  return new Date();
}

function toInputDate(d: Date): string {
  return d instanceof Date && !isNaN(d.getTime()) ? d.toISOString().split("T")[0] : "";
}

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 transition";
const LABEL = "block text-[10px] font-black tracking-widest text-gray-400 uppercase mb-1.5";
const DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

type RouteForm = {
  name: string; driverId: string; term: string; year: string;
  startDate: string; endDate: string; busRegistration: string;
};

const EMPTY_FORM: RouteForm = {
  name: "", driverId: "", term: "1", year: String(new Date().getFullYear()),
  startDate: "", endDate: "", busRegistration: "",
};

function routeToForm(r: Route): RouteForm {
  return {
    name: r.name, driverId: r.driverId, term: String(r.term), year: String(r.year),
    startDate: r.startDate instanceof Date ? toInputDate(r.startDate) : "",
    endDate: r.endDate instanceof Date ? toInputDate(r.endDate) : "",
    busRegistration: (r as Route & { busRegistration?: string }).busRegistration ?? "",
  };
}

function formChanged(original: RouteForm, current: RouteForm): boolean {
  return (Object.keys(original) as (keyof RouteForm)[]).some(k => original[k] !== current[k]);
}

const DIFF_FIELDS: { key: keyof RouteForm; label: string }[] = [
  { key: "name",            label: "Route Name" },
  { key: "driverId",        label: "Driver" },
  { key: "busRegistration", label: "Registration" },
  { key: "term",            label: "Term" },
  { key: "year",            label: "Year" },
  { key: "startDate",       label: "Start Date" },
  { key: "endDate",         label: "End Date" },
];

interface XlsxRow {
  name: string; grade: string;
  orderAM: string; pickupTime: string;
  orderPM: string; dropoffTime: string;
  stopAM: string; stopPM: string;
  parentPhone: string; parentName: string;
  studentPhone: string; relationship: string;
}

// ── Overlay ──────────────────────────────────────────────────────────────────

function Overlay({ children }: { children: React.ReactNode }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
      {children}
    </div>
  );
}

// ── Preview Modal ─────────────────────────────────────────────────────────────

function PreviewModal({ route, drivers, onClose, onEdit }: {
  route: Route; drivers: Driver[]; onClose: () => void; onEdit: () => void;
}) {
  const driverName = drivers.find(d => d.id === route.driverId)?.name ?? "—";
  const fields = [
    { label: "Driver",   value: driverName },
    { label: "Term",     value: `Term ${route.term}` },
    { label: "Year",     value: String(route.year) },
    { label: "Days",     value: route.scheduledDays?.join(", ") ?? "—" },
    { label: "Start",    value: route.startDate instanceof Date ? route.startDate.toLocaleDateString("en-AU") : "—" },
    { label: "End",      value: route.endDate instanceof Date ? route.endDate.toLocaleDateString("en-AU") : "—" },
    { label: "Students", value: String(route.studentIds?.length ?? 0) },
    { label: "Status",   value: route.isActive ? "Active" : "Inactive" },
  ];
  return (
    <Overlay>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[90vh] flex flex-col">
        <div className="px-6 py-5 border-b border-gray-100 flex items-center gap-4 flex-shrink-0">
          <div className="w-12 h-12 rounded-full bg-orange-100 flex items-center justify-center text-orange-700 text-lg font-black">
            {route.name.charAt(0)}
          </div>
          <div>
            <div className="text-base font-black text-gray-900">{route.name}</div>
            <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${route.isActive ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500"}`}>
              {route.isActive ? "Active" : "Inactive"}
            </span>
          </div>
          <button onClick={onClose} className="ml-auto text-gray-400 hover:text-gray-600">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div className="overflow-y-auto flex-1 px-6 py-4 space-y-3">
          {fields.map(f => (
            <div key={f.label} className="flex justify-between items-start gap-4">
              <span className="text-[10px] font-black tracking-widest text-gray-400 uppercase flex-shrink-0">{f.label}</span>
              <span className="text-sm font-bold text-gray-900 text-right">{f.value || "—"}</span>
            </div>
          ))}
        </div>
        <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
          <button onClick={onClose} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Close</button>
          <button onClick={onEdit} className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 transition-colors">Edit Route</button>
        </div>
      </div>
    </Overlay>
  );
}

// ── Route Form Fields (shared) ────────────────────────────────────────────────

function RouteFormFields({ form, onChange, drivers, selectedDays, onToggleDay }: {
  form: RouteForm;
  onChange: (key: keyof RouteForm, val: string) => void;
  drivers: Driver[];
  selectedDays: string[];
  onToggleDay: (day: string) => void;
}) {
  const set = (key: keyof RouteForm) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => onChange(key, e.target.value);
  return (
    <div className="grid grid-cols-2 gap-4">
      <div className="col-span-2">
        <label className={LABEL}>Route Name</label>
        <input className={FIELD} required value={form.name} onChange={set("name")} placeholder="e.g. Route A — Parramatta" />
      </div>
      <div>
        <label className={LABEL}>Assign Driver</label>
        <select className={FIELD} required value={form.driverId} onChange={set("driverId")}>
          <option value="">— select driver —</option>
          {drivers.map(d => <option key={d.id} value={d.id}>{d.name}</option>)}
        </select>
      </div>
      <div>
        <label className={LABEL}>Bus Registration</label>
        <input className={FIELD} value={form.busRegistration} onChange={set("busRegistration")} placeholder="e.g. ABC123" />
      </div>
      <div>
        <label className={LABEL}>Term</label>
        <select className={FIELD} value={form.term} onChange={set("term")}>
          {["1","2","3","4"].map(t => <option key={t} value={t}>Term {t}</option>)}
        </select>
      </div>
      <div>
        <label className={LABEL}>Start Date</label>
        <input className={FIELD} type="date" required value={form.startDate} onChange={set("startDate")} />
      </div>
      <div>
        <label className={LABEL}>End Date</label>
        <input className={FIELD} type="date" required value={form.endDate} onChange={set("endDate")} />
      </div>
      <div className="col-span-2">
        <label className={LABEL}>Scheduled Days</label>
        <div className="flex flex-wrap gap-2">
          {DAYS.map(day => (
            <button key={day} type="button" onClick={() => onToggleDay(day)}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-colors ${selectedDays.includes(day) ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"}`}>
              {day.slice(0, 3)}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ── Unsaved Changes Warning Modal ────────────────────────────────────────────

function UnsavedModal({ onSave, onDiscard }: { onSave: () => void; onDiscard: () => void }) {
  return (
    <Overlay>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6">
        <h3 className="text-base font-black text-gray-900 mb-2">Unsaved Changes</h3>
        <p className="text-sm text-gray-500 mb-5">You have unsaved changes. Would you like to save them before leaving?</p>
        <div className="flex justify-end gap-3">
          <button onClick={onDiscard} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Discard</button>
          <button onClick={onSave} className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 transition-colors">Save Changes</button>
        </div>
      </div>
    </Overlay>
  );
}

// ── Before/After Confirm Modal ───────────────────────────────────────────────

function ConfirmEditModal({ original, updated, onConfirm, onBack, saving }: {
  original: RouteForm; updated: RouteForm;
  onConfirm: () => void; onBack: () => void; saving: boolean;
}) {
  const changed = DIFF_FIELDS.filter(f => original[f.key] !== updated[f.key]);
  return (
    <Overlay>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col">
        <div className="px-6 py-5 border-b border-gray-100 flex-shrink-0">
          <h3 className="text-base font-black text-gray-900">Confirm Changes</h3>
          <p className="text-xs text-gray-400 mt-0.5">Review what will be updated before saving.</p>
        </div>
        <div className="overflow-y-auto flex-1 px-6 py-4">
          {changed.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-6">No changes detected.</p>
          ) : (
            <div className="space-y-3">
              <div className="grid grid-cols-[140px_1fr_1fr] gap-3 pb-1 border-b border-gray-100">
                <span className="text-[10px] font-black tracking-widest text-gray-400 uppercase">Field</span>
                <span className="text-[10px] font-black tracking-widest text-gray-400 uppercase">Before</span>
                <span className="text-[10px] font-black tracking-widest text-gray-400 uppercase">After</span>
              </div>
              {changed.map(f => (
                <div key={f.key} className="grid grid-cols-[140px_1fr_1fr] gap-3 items-start py-1.5 border-b border-gray-50">
                  <span className="text-[11px] font-black text-gray-500 uppercase tracking-wide">{f.label}</span>
                  <span className="text-sm text-gray-400 line-through break-words">{original[f.key] || "—"}</span>
                  <span className="text-sm font-bold text-gray-900 break-words">{updated[f.key] || "—"}</span>
                </div>
              ))}
            </div>
          )}
        </div>
        <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
          <button onClick={onBack} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Back</button>
          <button onClick={onConfirm} disabled={saving || changed.length === 0}
            className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors">
            {saving ? "Saving..." : "Confirm Save"}
          </button>
        </div>
      </div>
    </Overlay>
  );
}

// ── Add Schedule Modal ────────────────────────────────────────────────────────

function AddScheduleModal({ drivers, onClose, onAdded }: {
  drivers: Driver[]; onClose: () => void; onAdded: (r: Route) => void;
}) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [form, setForm] = useState<RouteForm>(EMPTY_FORM);
  const [selectedDays, setSelectedDays] = useState<string[]>(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]);
  const [preview, setPreview] = useState<XlsxRow[]>([]);
  const [fileError, setFileError] = useState("");
  const [dateError, setDateError] = useState("");
  const [daysError, setDaysError] = useState("");
  const [saving, setSaving] = useState(false);
  const [showUnsaved, setShowUnsaved] = useState(false);
  const [templateCount, setTemplateCount] = useState("10");

  const isDirty = formChanged(EMPTY_FORM, form) || preview.length > 0;
  const onChange = (key: keyof RouteForm, val: string) => {
    setForm(f => ({ ...f, [key]: val }));
    if (key === "startDate" || key === "endDate") setDateError("");
  };
  const toggleDay = (day: string) => {
    setSelectedDays(p => p.includes(day) ? p.filter(d => d !== day) : [...p, day]);
    setDaysError("");
  };

  const downloadTemplate = async () => {
    const count = Math.max(1, Math.min(200, parseInt(templateCount) || 10));
    const XLSX = await import("xlsx");
    // A: Student Name | B: Grade | C: Student Phone | D: Order AM | E: Scheduled AM | F: Stop Location AM
    // G: Order PM | H: Scheduled PM | I: Stop Location PM | J: Parent 1 Name | K: Parent 1 Phone | L: Relationship
    const headers = ["Student Name", "Grade", "Student Phone", "Order AM", "Scheduled AM", "Stop Location AM", "Order PM", "Scheduled PM", "Stop Location PM", "Parent 1 Name", "Parent 1 Phone", "Relationship"];
    const rows: string[][] = [headers];
    for (let i = 1; i <= count; i++) {
      rows.push([`Student ${i}`, "", "", "", "", "", "", "", "", "", "", ""]);
    }
    const ws = XLSX.utils.aoa_to_sheet(rows);
    ws["!cols"] = [{ wch: 20 }, { wch: 8 }, { wch: 16 }, { wch: 10 }, { wch: 14 }, { wch: 30 }, { wch: 10 }, { wch: 14 }, { wch: 30 }, { wch: 20 }, { wch: 16 }, { wch: 14 }];
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Students");
    XLSX.writeFile(wb, "student_template.xlsx");
  };

  const handleClose = () => {
    if (isDirty) { setShowUnsaved(true); return; }
    onClose();
  };

  const handleFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setFileError(""); setPreview([]);
    try {
      const XLSX = await import("xlsx");
      const data = await file.arrayBuffer();
      const wb = XLSX.read(data, { type: "array" });
      const ws = wb.Sheets[wb.SheetNames[0]];
      const rows = XLSX.utils.sheet_to_json<string[]>(ws, { header: 1 }) as string[][];
      // A: Student Name | B: Grade | C: Student Phone | D: Order AM | E: Scheduled AM | F: Stop Location AM
      // G: Order PM | H: Scheduled PM | I: Stop Location PM | J: Parent 1 Name | K: Parent 1 Phone | L: Relationship
      const normalisePhone = (p: string) => p ? (p.startsWith("+61") ? p : `+61${p.replace(/^0/, "")}`) : "";
      const parsed: XlsxRow[] = rows.slice(1).filter(r => r[0]).map(r => ({
        name: String(r[0] ?? ""), grade: String(r[1] ?? ""),
        studentPhone: normalisePhone(String(r[2] ?? "")),
        orderAM: String(r[3] ?? ""), pickupTime: String(r[4] ?? ""),
        stopAM: String(r[5] ?? ""),
        orderPM: String(r[6] ?? ""), dropoffTime: String(r[7] ?? ""),
        stopPM: String(r[8] ?? ""),
        parentName: String(r[9] ?? ""), parentPhone: normalisePhone(String(r[10] ?? "")),
        relationship: String(r[11] ?? ""),
      }));
      setPreview(parsed);
    } catch {
      setFileError("Could not parse file. Make sure it is a valid .xlsx file.");
    }
  };

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

  const doSave = async () => {
    if (!form.driverId || !form.startDate || !form.endDate) return;

    // Date validation
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const startDate = new Date(form.startDate);
    const endDate = new Date(form.endDate);
    if (startDate < today) {
      setDateError("Start date cannot be in the past.");
      return;
    }
    if (endDate < startDate) {
      setDateError("End date must be after start date.");
      return;
    }
    setDateError("");

    // Days validation
    if (selectedDays.length === 0) {
      setDaysError("Select at least one scheduled day.");
      return;
    }
    setDaysError("");

    setSaving(true);
    try {
      const batch = writeBatch(db);
      const scheduledDates = getScheduledDates(startDate, endDate, selectedDays);

      const studentIds: string[] = [];
      const studentRecordTemplate: { id: string; studentName: string; stopAddressAM: string; stopAddressPM: string; orderAM: number | null; orderPM: number | null; status: string; timestamp: null }[] = [];

      // Create route ref first so we have the ID for student routeId
      const routeRef = doc(collection(db, "routes"));

      for (const row of preview) {
        const studentRef = doc(collection(db, "students"));
        const parents = row.parentName || row.parentPhone
          ? [{ name: row.parentName, phone: row.parentPhone, canAccess: true, relationship: row.relationship || "Guardian" }]
          : [];
        const orderAM = parseInt(row.orderAM) || null;
        const orderPM = parseInt(row.orderPM) || null;
        batch.set(studentRef, {
          name: row.name, grade: row.grade,
          stopAddressAM: row.stopAM, stopAddressPM: row.stopPM,
          orderAM, orderPM,
          routeId: routeRef.id,
          scheduledPickupTime: row.pickupTime, scheduledDropoffTime: row.dropoffTime,
          phone: row.studentPhone || "",
          parents,
          authorisedParentIds: [], isActive: true, createdAt: Timestamp.now(),
        });
        studentIds.push(studentRef.id);
        studentRecordTemplate.push({ id: studentRef.id, studentName: row.name, stopAddressAM: row.stopAM, stopAddressPM: row.stopPM, orderAM, orderPM, status: "pending", timestamp: null });
      }
      batch.set(routeRef, {
        name: form.name.trim(), driverId: form.driverId,
        busRegistration: form.busRegistration.trim(),
        term: parseInt(form.term), year: parseInt(form.year),
        scheduledDays: selectedDays,
        startDate: Timestamp.fromDate(startDate), endDate: Timestamp.fromDate(endDate),
        studentIds, isActive: true, createdAt: Timestamp.now(),
      });

      for (const date of scheduledDates) {
        for (const type of ["pickup", "dropoff"] as const) {
          const tripRef = doc(collection(db, "trips"));
          batch.set(tripRef, {
            routeId: routeRef.id, driverId: form.driverId,
            date: Timestamp.fromDate(date), type, status: "scheduled",
            studentRecords: studentRecordTemplate, startedAt: null, completedAt: null,
          });
        }
      }

      await batch.commit();
      const newRoute: Route = {
        id: routeRef.id, name: form.name.trim(), driverId: form.driverId,
        term: parseInt(form.term), year: parseInt(form.year),
        scheduledDays: selectedDays, startDate, endDate, studentIds, isActive: true,
      };
      onAdded(newRoute);
    } catch (err) { console.error(err); }
    setSaving(false);
  };

  const handleSubmit = (e: React.FormEvent) => { e.preventDefault(); doSave(); };

  return (
    <>
      <Overlay>
        <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col">
          <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
            <div>
              <h3 className="text-base font-black text-gray-900">Add Schedule</h3>
              <p className="text-xs text-gray-400 mt-0.5">Create a new route and generate trips</p>
            </div>
            <button onClick={handleClose} className="text-gray-400 hover:text-gray-600">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
          <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
            <div className="overflow-y-auto flex-1 px-6 py-5 space-y-5">
              <RouteFormFields form={form} onChange={onChange} drivers={drivers} selectedDays={selectedDays} onToggleDay={toggleDay} />
              {dateError && <p className="text-xs text-red-500 -mt-2">{dateError}</p>}
              {daysError && <p className="text-xs text-red-500 -mt-2">{daysError}</p>}
              {/* Student upload */}
              <div className="border-t border-gray-100 pt-4">
                <p className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-3">Student List (.xlsx)</p>
                <div className="bg-blue-50 rounded-xl p-4 mb-3">
                  <p className="text-sm font-bold text-blue-700 mb-3">How many students on this route?</p>
                  <div className="flex items-center gap-3">
                    <input
                      type="number" min="1" max="200"
                      value={templateCount}
                      onChange={e => setTemplateCount(e.target.value)}
                      className="w-20 bg-white border border-gray-200 rounded-lg px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-200"
                    />
                    <button type="button" onClick={downloadTemplate}
                      className="px-4 py-2 bg-blue-600 text-white text-sm font-semibold rounded-lg hover:bg-blue-700 transition-colors">
                      Download
                    </button>
                  </div>
                </div>
                <p className="text-xs text-gray-400 mb-3">
                  Columns: Student Name · Grade · Student Phone · Order AM · Scheduled AM · Stop Location AM · Order PM · Scheduled PM · Stop Location PM · Parent 1 Name · Parent 1 Phone · Relationship
                </p>
                <input ref={fileRef} type="file" accept=".xlsx,.xls" onChange={handleFile} className="hidden" />
                <button type="button" onClick={() => fileRef.current?.click()}
                  className="w-full border-2 border-dashed border-gray-200 rounded-xl py-6 text-sm text-gray-400 hover:border-gray-300 hover:text-gray-500 transition-colors">
                  Click to upload .xlsx file
                </button>
                {fileError && <p className="text-xs text-red-500 mt-2">{fileError}</p>}
                {preview.length > 0 && (
                  <div className="mt-3">
                    <p className="text-xs font-bold text-gray-500 mb-2">{preview.length} students loaded — preview:</p>
                    <div className="rounded-xl border border-gray-100 overflow-hidden">
                      <table className="w-full text-xs">
                        <thead className="bg-gray-50">
                          <tr className="text-gray-400">
                            <th className="px-3 py-2 text-left font-bold">Name</th>
                            <th className="px-3 py-2 text-left font-bold">Grade</th>
                            <th className="px-3 py-2 text-left font-bold">Stop AM</th>
                            <th className="px-3 py-2 text-left font-bold">Stop PM</th>
                            <th className="px-3 py-2 text-left font-bold">Pick-up</th>
                            <th className="px-3 py-2 text-left font-bold">Drop-off</th>
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
                          {preview.length > 5 && <tr><td colSpan={6} className="px-3 py-2 text-gray-400 text-center">…and {preview.length - 5} more</td></tr>}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}
              </div>
            </div>
            <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
              <button type="button" onClick={handleClose} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Cancel</button>
              <button type="submit" disabled={saving || preview.length === 0}
                className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors">
                {saving ? "Creating..." : "Create Schedule & Generate Trips"}
              </button>
            </div>
          </form>
        </div>
      </Overlay>
      {showUnsaved && (
        <UnsavedModal
          onSave={() => { setShowUnsaved(false); doSave(); }}
          onDiscard={() => { setShowUnsaved(false); onClose(); }}
        />
      )}
    </>
  );
}

// ── Edit Schedule Modal ───────────────────────────────────────────────────────

function EditScheduleModal({ route, drivers, onClose, onSaved }: {
  route: Route; drivers: Driver[]; onClose: () => void; onSaved: (r: Route) => void;
}) {
  const original = routeToForm(route);
  const [form, setForm] = useState<RouteForm>(original);
  const [selectedDays, setSelectedDays] = useState<string[]>(route.scheduledDays ?? []);
  const [showUnsaved, setShowUnsaved] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [saving, setSaving] = useState(false);

  const isDirty = formChanged(original, form);
  const onChange = (key: keyof RouteForm, val: string) => setForm(f => ({ ...f, [key]: val }));
  const toggleDay = (day: string) => setSelectedDays(p => p.includes(day) ? p.filter(d => d !== day) : [...p, day]);

  const handleClose = () => {
    if (isDirty) { setShowUnsaved(true); return; }
    onClose();
  };

  const doSave = async () => {
    setSaving(true);
    try {
      await updateDoc(doc(db, "routes", route.id), {
        name: form.name.trim(), driverId: form.driverId, term: parseInt(form.term),
        scheduledDays: selectedDays,
        startDate: form.startDate ? Timestamp.fromDate(new Date(form.startDate)) : null,
        endDate: form.endDate ? Timestamp.fromDate(new Date(form.endDate)) : null,
      });
      const updated: Route = {
        ...route, name: form.name.trim(), driverId: form.driverId,
        term: parseInt(form.term), scheduledDays: selectedDays,
        startDate: form.startDate ? new Date(form.startDate) : route.startDate,
        endDate: form.endDate ? new Date(form.endDate) : route.endDate,
      };
      onSaved(updated);
    } catch (err) { console.error(err); }
    setSaving(false);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!isDirty) return;
    setShowConfirm(true);
  };

  if (showConfirm) {
    return (
      <ConfirmEditModal
        original={original} updated={form}
        onConfirm={doSave}
        onBack={() => setShowConfirm(false)}
        saving={saving}
      />
    );
  }

  return (
    <>
      <Overlay>
        <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col">
          <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
            <div>
              <h3 className="text-base font-black text-gray-900">Edit — {route.name}</h3>
              <p className="text-xs text-gray-400 mt-0.5">Changes shown for confirmation before saving</p>
            </div>
            <button onClick={handleClose} className="text-gray-400 hover:text-gray-600">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
          <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
            <div className="overflow-y-auto flex-1 px-6 py-5">
              <RouteFormFields form={form} onChange={onChange} drivers={drivers} selectedDays={selectedDays} onToggleDay={toggleDay} />
            </div>
            <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
              <button type="button" onClick={handleClose} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Cancel</button>
              <button type="submit" disabled={!isDirty}
                className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 disabled:opacity-40 transition-colors">
                Review Changes
              </button>
            </div>
          </form>
        </div>
      </Overlay>
      {showUnsaved && (
        <UnsavedModal
          onSave={() => { setShowUnsaved(false); setShowConfirm(true); }}
          onDiscard={() => { setShowUnsaved(false); onClose(); }}
        />
      )}
    </>
  );
}

// ── Remove Schedule Modal ─────────────────────────────────────────────────────

function RemoveScheduleModal({ route, onClose, onRemoved }: {
  route: Route; onClose: () => void; onRemoved: (id: string) => void;
}) {
  const [saving, setSaving] = useState(false);

  const confirmRemove = async () => {
    setSaving(true);
    await updateDoc(doc(db, "routes", route.id), { isActive: false });
    setSaving(false);
    onRemoved(route.id);
  };

  return (
    <Overlay>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6">
        <div className="flex items-center gap-3 mb-5">
          <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ef4444" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/>
            </svg>
          </div>
          <div>
            <h3 className="text-base font-black text-gray-900">Remove {route.name}</h3>
            <p className="text-xs text-gray-400">This will deactivate the route and preserve trip history.</p>
          </div>
        </div>
        <div className="bg-gray-50 rounded-xl p-4 mb-4">
          <div className="grid grid-cols-2 gap-4 divide-x divide-gray-200">
            <div>
              <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">Before</div>
              <div className="font-bold text-gray-900 text-sm">{route.name}</div>
              <div className="text-xs text-gray-500">Term {route.term} · {route.year}</div>
              <div className="text-xs text-gray-500">{route.studentIds?.length ?? 0} students</div>
              <span className="inline-block mt-1.5 text-[10px] font-black px-2 py-0.5 rounded-full bg-green-100 text-green-700">Active</span>
            </div>
            <div className="pl-4">
              <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">After</div>
              <div className="font-bold text-gray-900 text-sm">{route.name}</div>
              <div className="text-xs text-gray-500">Term {route.term} · {route.year}</div>
              <div className="text-xs text-gray-500">{route.studentIds?.length ?? 0} students</div>
              <span className="inline-block mt-1.5 text-[10px] font-black px-2 py-0.5 rounded-full bg-gray-100 text-gray-500">Inactive</span>
            </div>
          </div>
        </div>
        <div className="flex justify-end gap-3 mt-4">
          <button onClick={onClose} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Cancel</button>
          <button onClick={confirmRemove} disabled={saving}
            className="px-5 py-2.5 bg-red-500 text-white text-sm font-black rounded-xl hover:bg-red-600 disabled:opacity-50 transition-colors">
            {saving ? "Removing..." : "Confirm Remove"}
          </button>
        </div>
      </div>
    </Overlay>
  );
}

// ── Main Page ─────────────────────────────────────────────────────────────────

type Modal =
  | { type: "add" }
  | { type: "preview"; route: Route }
  | { type: "edit"; route: Route }
  | { type: "remove"; route: Route }
  | { type: "substitute"; route: Route };

export default function SchedulePage() {
  const [routes, setRoutes] = useState<Route[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState<Modal | null>(null);
  const [showInactive, setShowInactive] = useState(false);

  const load = useCallback(() => {
    Promise.all([
      getDocs(query(collection(db, "routes"), orderBy("startDate", "desc"))),
      getDocs(collection(db, "drivers")),
    ]).then(([rSnap, dSnap]) => {
      setRoutes(rSnap.docs.map(d => ({
        id: d.id, ...d.data(),
        startDate: toDate(d.data().startDate),
        endDate: toDate(d.data().endDate),
      } as Route)));
      setDrivers(dSnap.docs.map(d => ({ id: d.id, ...d.data() } as Driver)).filter(d => d.isActive));
      setLoading(false);
    });
  }, []);

  useEffect(() => { load(); }, [load]);

  const closeModal = () => setModal(null);
  const handleAdded = (r: Route) => { setRoutes(prev => [r, ...prev]); closeModal(); };
  const handleSaved = (updated: Route) => { setRoutes(prev => prev.map(r => r.id === updated.id ? updated : r)); closeModal(); };
  const handleRemoved = (id: string) => { setRoutes(prev => prev.map(r => r.id === id ? { ...r, isActive: false } : r)); closeModal(); };

  return (
    <div className="max-w-5xl mx-auto">
      <PageHeader
        title="SCHEDULE"
        subtitle="All Routes"
        breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Schedule" }]}
      />
      <div className="flex items-center justify-between mb-4">
        <button
          onClick={() => setShowInactive(v => !v)}
          className={`px-4 py-2 text-xs font-bold tracking-widest uppercase rounded-xl border transition-colors ${
            showInactive
              ? "bg-gray-900 text-white border-gray-900"
              : "bg-white text-gray-500 border-gray-200 hover:border-gray-400"
          }`}
        >
          {showInactive ? "Hide Inactive" : `Show Inactive (${routes.filter(r => !r.isActive).length})`}
        </button>
        <button
          onClick={() => setModal({ type: "add" })}
          className="px-5 py-2.5 bg-blue-600 text-white text-xs font-bold tracking-widest uppercase rounded-xl hover:bg-blue-700 transition-colors"
        >
          Add Schedule
        </button>
      </div>

      {loading ? (
        <p className="text-sm text-gray-300">Loading...</p>
      ) : routes.filter(r => showInactive || r.isActive).length === 0 ? (
        <div className="text-center py-16 text-gray-400 text-sm">
          No schedules yet.{" "}
          <button onClick={() => setModal({ type: "add" })} className="text-blue-500 hover:underline">Create one</button>.
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
          {/* Table header */}
          <div className="grid grid-cols-[2fr_0.6fr_0.6fr_1fr_0.7fr_90px_100px_110px_80px] px-5 py-3 border-b border-gray-100">
            {["Route", "Term", "Year", "Period", "Students", "Status", "", "", ""].map((h, i) => (
              <span key={i} className="text-xs font-bold tracking-widest text-gray-900 uppercase">{h}</span>
            ))}
          </div>
          {/* Rows */}
          <div className="divide-y divide-gray-50">
            {routes.filter(r => showInactive || r.isActive).map(route => (
              <div key={route.id} className="grid grid-cols-[2fr_0.6fr_0.6fr_1fr_0.7fr_90px_100px_110px_80px] items-center px-5 py-3.5 hover:bg-gray-50 transition-colors">
                {/* Route name */}
                <div className="flex items-center gap-3 min-w-0">
                  <div className="w-8 h-8 rounded-full bg-orange-100 flex items-center justify-center text-orange-700 text-xs font-bold flex-shrink-0">
                    {route.name.charAt(0)}
                  </div>
                  <div className="min-w-0">
                    <div className="text-xs font-bold tracking-widest uppercase text-gray-900 truncate">{route.name}</div>
                    <div className="text-xs text-gray-400 tracking-wide truncate">{route.scheduledDays?.join(", ")}</div>
                  </div>
                </div>
                {/* Term */}
                <span className="text-xs font-bold tracking-widest text-gray-600">T{route.term}</span>
                {/* Year */}
                <span className="text-xs font-bold tracking-widest text-gray-600">{route.year}</span>
                {/* Period */}
                <span className="text-xs font-bold tracking-widest text-gray-600">
                  {route.startDate instanceof Date ? route.startDate.toLocaleDateString("en-AU") : "—"} – {route.endDate instanceof Date ? route.endDate.toLocaleDateString("en-AU") : "—"}
                </span>
                {/* Students */}
                <span className="text-xs font-bold tracking-widest text-gray-600">{route.studentIds?.length ?? 0}</span>
                {/* Status */}
                <div>
                  <span className={`text-xs font-bold tracking-widest uppercase px-2 py-1 rounded-full ${
                    route.isActive ? "bg-green-100 text-green-600" : "bg-gray-100 text-gray-500"
                  }`}>
                    {route.isActive ? "Active" : "Inactive"}
                  </span>
                </div>
                {/* Preview */}
                <div>
                  <button
                    onClick={() => setModal({ type: "preview", route })}
                    className="px-4 py-2 bg-blue-50 text-blue-600 text-xs font-bold rounded-lg hover:bg-blue-100 transition-colors"
                  >
                    Preview
                  </button>
                </div>
                {/* Substitute */}
                <div>
                  {route.isActive && (
                    <button
                      onClick={() => setModal({ type: "substitute", route })}
                      className="px-3 py-2 bg-amber-50 text-amber-700 text-xs font-bold rounded-lg hover:bg-amber-100 transition-colors"
                    >
                      Substitute
                    </button>
                  )}
                </div>
                {/* Remove */}
                <div>
                  {route.isActive && (
                    <button
                      onClick={() => setModal({ type: "remove", route })}
                      className="px-4 py-2 bg-red-50 text-red-600 text-xs font-bold rounded-lg hover:bg-red-100 transition-colors"
                    >
                      Remove
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {modal?.type === "add" && <AddScheduleModal drivers={drivers} onClose={closeModal} onAdded={handleAdded} />}
      {modal?.type === "preview" && (
        <PreviewModal
          route={modal.route}
          drivers={drivers}
          onClose={closeModal}
          onEdit={() => setModal({ type: "edit", route: modal.route })}
        />
      )}
      {modal?.type === "edit" && (
        <EditScheduleModal route={modal.route} drivers={drivers} onClose={closeModal} onSaved={handleSaved} />
      )}
      {modal?.type === "remove" && (
        <RemoveScheduleModal route={modal.route} onClose={closeModal} onRemoved={handleRemoved} />
      )}
      {modal?.type === "substitute" && (
        <SubstituteDriverModal route={modal.route} drivers={drivers} onClose={closeModal} onCompleted={closeModal} />
      )}
    </div>
  );
}

"use client";
import { useEffect, useState, useCallback, useRef } from "react";
import { collection, getDocs, doc, updateDoc, writeBatch, query, where, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
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

// Excel stores times as a decimal fraction of 24 hours (e.g. 0.2916... = 07:00).
// Convert to "07:00 AM" format if the value looks like a fraction, otherwise return as-is.
function xlsxTimeToString(v: unknown): string {
  if (v === null || v === undefined || v === "") return "";
  const str = String(v).trim();
  const num = Number(str);
  if (!isNaN(num) && num >= 0 && num < 1 && str !== "") {
    const totalMinutes = Math.round(num * 24 * 60);
    const h = Math.floor(totalMinutes / 60) % 24;
    const m = totalMinutes % 60;
    const period = h < 12 ? "AM" : "PM";
    const h12 = h % 12 === 0 ? 12 : h % 12;
    return `${String(h12).padStart(2, "0")}:${String(m).padStart(2, "0")} ${period}`;
  }
  return str;
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
  studentPhone: string; studentEmail: string;
  orderAM: string; pickupTime: string; stopAM: string;
  orderPM: string; dropoffTime: string; stopPM: string;
  parentName: string; parentPhone: string;
  parentEmail: string; relationship: string;
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
  const setUpper = (key: keyof RouteForm) => (e: React.ChangeEvent<HTMLInputElement>) => onChange(key, e.target.value.toUpperCase());
  return (
    <div className="grid grid-cols-2 gap-4">
      <div className="col-span-2">
        <label className={LABEL}>Route Name</label>
        <input className={FIELD} required value={form.name} onChange={setUpper("name")} placeholder="e.g. ROUTE A — PARRAMATTA" />
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
        <input className={FIELD} value={form.busRegistration} onChange={setUpper("busRegistration")} placeholder="e.g. ABC123" />
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

const EMPTY_MANUAL_ROW: XlsxRow = {
  name: "", grade: "", studentPhone: "", studentEmail: "",
  orderAM: "", pickupTime: "", stopAM: "",
  orderPM: "", dropoffTime: "", stopPM: "",
  parentName: "", parentPhone: "", parentEmail: "", relationship: "",
};

const RELATIONSHIPS = ["Mother", "Father", "Step Mother", "Step Father", "Guardian"];

// PDF table column headers (used for Step 2 review table)
const PDF_COLS = [
  "Student Name", "Grade", "Student Phone", "Student Email",
  "Order AM", "Schedule AM", "Stop AM",
  "Order PM", "Schedule PM", "Stop PM",
  "Parent Name", "Parent Phone", "Parent Email", "Relationship",
];

// Progress row status for Step 3
type ProgressStatus = "pending" | "sending" | "done" | "error";

interface ProgressRow {
  label: string;
  status: ProgressStatus;
  note?: string;
}

function ProgressRowItem({ row }: { row: ProgressRow }) {
  return (
    <div className={`flex items-center justify-between px-5 py-4 rounded-2xl transition-colors ${
      row.status === "done" ? "bg-green-50 border border-green-200" :
      row.status === "error" ? "bg-red-50 border border-red-200" :
      "bg-gray-50 border border-gray-100"
    }`}>
      <div>
        <p className={`text-sm font-black ${
          row.status === "done" ? "text-green-800" :
          row.status === "error" ? "text-red-700" :
          "text-gray-700"
        }`}>{row.label}</p>
        {row.note && (
          <p className="text-xs text-amber-600 mt-0.5 font-medium">{row.note}</p>
        )}
      </div>
      <div className="flex-shrink-0 ml-4">
        {row.status === "pending" && (
          <div className="w-6 h-6 rounded-full bg-gray-200" />
        )}
        {row.status === "sending" && (
          <div className="w-6 h-6 rounded-full border-2 border-blue-600 border-t-transparent animate-spin" />
        )}
        {row.status === "done" && (
          <div className="w-6 h-6 rounded-full bg-green-500 flex items-center justify-center">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="20 6 9 17 4 12"/>
            </svg>
          </div>
        )}
        {row.status === "error" && (
          <div className="w-6 h-6 rounded-full bg-red-400 flex items-center justify-center">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </div>
        )}
      </div>
    </div>
  );
}

function AddScheduleModal({ schoolId, schoolName, adminEmail, drivers, onClose, onAdded }: {
  schoolId: string; schoolName: string; adminEmail: string; drivers: Driver[]; onClose: () => void; onAdded: (r: Route) => void;
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
  const [manualRow, setManualRow] = useState<XlsxRow>(EMPTY_MANUAL_ROW);
  const [manualError, setManualError] = useState("");

  // ── 3-step flow state ──────────────────────────────────────────────────────
  const [step, setStep] = useState<1 | 2 | 3>(1);
  // Step 3 progress rows — one per pipeline stage
  const [progress, setProgress] = useState<ProgressRow[]>([
    { label: "Student welcome emails", status: "pending" },
    { label: "Parent welcome emails", status: "pending" },
    { label: "Admin notified", status: "pending" },
    { label: "Driver notified", status: "pending" },
    { label: "Schedule sent to students", status: "pending" },
    { label: "Schedule sent to parents", status: "pending" },
  ]);
  const [allDone, setAllDone] = useState(false);
  // Saved route ref so onAdded can be called when user closes Step 3
  const savedRouteRef = useRef<Route | null>(null);

  const setProgressRow = (index: number, patch: Partial<ProgressRow>) =>
    setProgress(prev => prev.map((r, i) => i === index ? { ...r, ...patch } : r));

  const setManual = (key: keyof XlsxRow) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    setManualRow(r => ({ ...r, [key]: e.target.value }));
    setManualError("");
  };

  const addManualStudent = () => {
    if (!manualRow.name.trim()) { setManualError("Student name is required."); return; }
    const normalisePhone = (p: string) => p ? (p.startsWith("+61") ? p : `+61${p.replace(/^0/, "")}`) : "";
    const row: XlsxRow = {
      ...manualRow,
      name: manualRow.name.trim(),
      studentPhone: normalisePhone(manualRow.studentPhone),
      parentPhone: normalisePhone(manualRow.parentPhone),
    };
    setPreview(prev => [...prev, row]);
    setManualRow(EMPTY_MANUAL_ROW);
    setManualError("");
  };

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
    const headers = ["Student Name", "Grade", "Student Phone", "Student Email", "Order AM", "Scheduled AM", "Stop Location AM", "Order PM", "Scheduled PM", "Stop Location PM", "Parent 1 Name", "Parent 1 Phone", "Parent Email", "Relationship"];
    const rows: string[][] = [headers];
    for (let i = 1; i <= count; i++) {
      rows.push(Array(14).fill("").map((_, j) => j === 0 ? `Student ${i}` : "") as string[]);
    }
    const ws = XLSX.utils.aoa_to_sheet(rows);
    ws["!cols"] = [{ wch: 20 }, { wch: 8 }, { wch: 16 }, { wch: 24 }, { wch: 10 }, { wch: 14 }, { wch: 30 }, { wch: 10 }, { wch: 14 }, { wch: 30 }, { wch: 20 }, { wch: 16 }, { wch: 24 }, { wch: 14 }];
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Students");
    XLSX.writeFile(wb, "student_template.xlsx");
  };

  const handleClose = () => {
    if (step === 3 && savedRouteRef.current) {
      onAdded(savedRouteRef.current);
      return;
    }
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
      const normalisePhone = (p: string) => p ? (p.startsWith("+61") ? p : `+61${p.replace(/^0/, "")}`) : "";
      const parsed: XlsxRow[] = rows.slice(1).filter(r => r[0]).map(r => ({
        name: String(r[0] ?? ""), grade: String(r[1] ?? ""),
        studentPhone: normalisePhone(String(r[2] ?? "")),
        studentEmail: String(r[3] ?? "").trim(),
        orderAM: String(r[4] ?? ""), pickupTime: xlsxTimeToString(r[5]),
        stopAM: String(r[6] ?? ""),
        orderPM: String(r[7] ?? ""), dropoffTime: xlsxTimeToString(r[8]),
        stopPM: String(r[9] ?? ""),
        parentName: String(r[10] ?? ""), parentPhone: normalisePhone(String(r[11] ?? "")),
        parentEmail: String(r[12] ?? "").trim(),
        relationship: String(r[13] ?? ""),
      }));
      setPreview(prev => [...prev, ...parsed]);
    } catch {
      setFileError("Could not parse file. Make sure it is a valid .xlsx file.");
    }
  };

  // ── Step navigation ────────────────────────────────────────────────────────

  const goToStep2 = () => {
    // Validate required form fields before proceeding
    if (!form.name.trim() || !form.driverId || !form.startDate || !form.endDate) return;
    if (selectedDays.length === 0) { setDaysError("Select at least one scheduled day."); return; }
    // Compute today's date in Melbourne time
    const melbourneDateStr = new Date().toLocaleDateString("en-AU", { timeZone: "Australia/Melbourne" });
    const [melDay, melMonth, melYear] = melbourneDateStr.split("/").map(Number);
    const today = new Date(melYear, melMonth - 1, melDay); // midnight Melbourne today

    const start = new Date(form.startDate);
    const end = new Date(form.endDate);
    if (start <= today) { setDateError("Start date must be at least tomorrow. Schedules cannot start today or in the past."); return; }
    if (end < start) { setDateError("End date must be after start date."); return; }
    setStep(2);
  };

  // ── Firestore save + notifications (called from Step 2 "Confirm & Schedule") ──

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

  const doConfirm = async () => {
    if (!form.driverId || !form.startDate || !form.endDate) return;
    setSaving(true);
    try {
      const startDate = new Date(form.startDate);
      const endDate = new Date(form.endDate);

      // Duplicate check
      const dupSnap = await getDocs(
        query(
          collection(db, "routes"),
          where("schoolId", "==", schoolId),
          where("name", "==", form.name.trim().toUpperCase()),
          where("term", "==", parseInt(form.term)),
          where("year", "==", parseInt(form.year)),
          where("isActive", "==", true)
        )
      );
      if (!dupSnap.empty) {
        alert(`A route named "${form.name.trim().toUpperCase()}" already exists for Term ${form.term} ${form.year}.`);
        setSaving(false);
        return;
      }

      // Bus rego uniqueness
      if (form.busRegistration.trim()) {
        const regoSnap = await getDocs(
          query(
            collection(db, "routes"),
            where("busRegistration", "==", form.busRegistration.trim().toUpperCase()),
            where("isActive", "==", true)
          )
        );
        if (!regoSnap.empty) {
          alert(`Bus registration "${form.busRegistration.trim().toUpperCase()}" is already assigned to another active route.`);
          setSaving(false);
          return;
        }
      }

      const batch = writeBatch(db);
      const scheduledDates = getScheduledDates(startDate, endDate, selectedDays);
      const studentIds: string[] = [];
      const studentRecordTemplate: { id: string; studentName: string; stopAddressAM: string; stopAddressPM: string; orderAM: number | null; orderPM: number | null; status: string; timestamp: null }[] = [];
      const routeRef = doc(collection(db, "routes"));

      for (const row of preview) {
        const studentRef = doc(collection(db, "students"));
        const orderAM = parseInt(row.orderAM) || null;
        const orderPM = parseInt(row.orderPM) || null;
        const authorisedParentIds: string[] = [];

        if (row.parentName.trim()) {
          const parentRef = doc(collection(db, "parents"));
          batch.set(parentRef, {
            schoolId,
            name: row.parentName.trim(),
            relationship: row.relationship.trim() || "Guardian",
            phone: row.parentPhone.trim() || "",
            email: row.parentEmail.trim() || "",
            fcmToken: null,
            childIds: [studentRef.id],
            isActive: true, profileCompleted: false, passwordSet: false,
            createdAt: Timestamp.now(),
          });
          authorisedParentIds.push(parentRef.id);
        }

        batch.set(studentRef, {
          schoolId,
          name: row.name, grade: row.grade,
          stopAddressAM: row.stopAM, stopAddressPM: row.stopPM,
          orderAM, orderPM,
          routeId: routeRef.id,
          scheduledPickupTime: row.pickupTime, scheduledDropoffTime: row.dropoffTime,
          phone: row.studentPhone.trim() || "",
          email: row.studentEmail.trim() || "",
          authorisedParentIds, isActive: true, passwordSet: false, createdAt: Timestamp.now(),
        });
        studentIds.push(studentRef.id);
        studentRecordTemplate.push({ id: studentRef.id, studentName: row.name, stopAddressAM: row.stopAM, stopAddressPM: row.stopPM, orderAM, orderPM, status: "pending", timestamp: null });
      }

      batch.set(routeRef, {
        schoolId,
        name: form.name.trim().toUpperCase(), driverId: form.driverId,
        busRegistration: form.busRegistration.trim().toUpperCase(),
        term: parseInt(form.term), year: parseInt(form.year),
        scheduledDays: selectedDays,
        startDate: Timestamp.fromDate(startDate), endDate: Timestamp.fromDate(endDate),
        studentIds, isActive: true, createdAt: Timestamp.now(),
      });

      for (const date of scheduledDates) {
        for (const type of ["pickup", "dropoff"] as const) {
          const tripRef = doc(collection(db, "trips"));
          batch.set(tripRef, {
            schoolId,
            routeId: routeRef.id, driverId: form.driverId,
            date: Timestamp.fromDate(date), type, status: "scheduled",
            studentRecords: studentRecordTemplate, startedAt: null, completedAt: null,
          });
        }
      }

      await batch.commit();

      // Store the new route so we can call onAdded when the user closes Step 3
      savedRouteRef.current = {
        id: routeRef.id, schoolId, name: form.name.trim().toUpperCase(), driverId: form.driverId,
        term: parseInt(form.term), year: parseInt(form.year),
        scheduledDays: selectedDays, startDate, endDate, studentIds, isActive: true,
      };

      // Advance to Step 3 progress screen before firing notifications
      setStep(3);
      setSaving(false);

      // ── Sequential notification pipeline ──────────────────────────────────
      const term = parseInt(form.term);
      const year = parseInt(form.year);
      const routeName = form.name.trim().toUpperCase();
      const driver = drivers.find(d => d.id === form.driverId);
      const notifyStudents = preview.map(r => ({
        name: r.name, grade: r.grade,
        studentPhone: r.studentPhone, studentEmail: r.studentEmail,
        orderAM: r.orderAM, pickupTime: r.pickupTime, stopAM: r.stopAM,
        orderPM: r.orderPM, dropoffTime: r.dropoffTime, stopPM: r.stopPM,
        parentName: r.parentName, parentPhone: r.parentPhone,
        parentEmail: r.parentEmail, relationship: r.relationship,
      }));

      const basePayload = {
        schoolId, schoolName, routeName, term, year,
        busRego: form.busRegistration.trim().toUpperCase(),
        driverName: driver?.name ?? "",
        driverPhone: driver?.phone ?? "",
        driverEmail: driver?.email ?? "",
        adminEmail,
        students: notifyStudents,
      };

      type StageResult = { skipped?: boolean | number; sent?: number; skipReason?: string };

      const runStage = async (stage: string, rowIndex: number): Promise<StageResult> => {
        setProgressRow(rowIndex, { status: "sending" });
        try {
          const res = await fetch("/api/schedule/provision-and-notify", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ ...basePayload, stage }),
          });
          const data = await res.json() as StageResult;
          if (data.skipped === true && data.sent === undefined) {
            // No Resend key configured
            setProgressRow(rowIndex, { status: "done" });
            return data;
          }
          setProgressRow(rowIndex, {
            status: "done",
            note: data.skipReason ?? undefined,
          });
          return data;
        } catch (err) {
          console.error(`stage ${stage} error:`, err);
          setProgressRow(rowIndex, { status: "error" });
          return {};
        }
      };

      // Run all 6 stages sequentially
      await runStage("student-welcome", 0);
      await runStage("parent-welcome", 1);
      await runStage("admin-schedule", 2);
      await runStage("driver-schedule", 3);
      await runStage("student-schedule", 4);
      await runStage("parent-schedule", 5);

      setAllDone(true);

      return; // don't run the outer setSaving(false) again
    } catch (err) { console.error(err); }
    setSaving(false);
  };

  // ── Step label helpers ─────────────────────────────────────────────────────
  const stepLabel = step === 1 ? "Route Details" : step === 2 ? "Review Students" : "Sending Notifications";
  const stepSubtitle = step === 1
    ? "Fill in route info and add students"
    : step === 2
    ? `${preview.length} student${preview.length !== 1 ? "s" : ""} ready — review before confirming`
    : "Creating schedule and notifying contacts";

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <>
      <Overlay>
        <div className="bg-white rounded-2xl shadow-2xl w-full max-w-4xl max-h-[92vh] flex flex-col overflow-hidden">

          {/* ── Header ─────────────────────────────────────────────────────── */}
          <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
            <div>
              <div className="flex items-center gap-2 mb-0.5">
                {[1, 2, 3].map(s => (
                  <div key={s} className="flex items-center gap-1.5">
                    <div className={`w-6 h-6 rounded-full flex items-center justify-center text-[10px] font-black transition-colors ${
                      s < step ? "bg-green-500 text-white" :
                      s === step ? "bg-blue-600 text-white" :
                      "bg-gray-100 text-gray-400"
                    }`}>
                      {s < step ? "✓" : s}
                    </div>
                    {s < 3 && <div className={`w-6 h-px ${s < step ? "bg-green-400" : "bg-gray-200"}`} />}
                  </div>
                ))}
              </div>
              <h3 className="text-base font-black text-gray-900">{stepLabel}</h3>
              <p className="text-xs text-gray-400 mt-0.5">{stepSubtitle}</p>
            </div>
            <button onClick={handleClose} className="text-gray-400 hover:text-gray-600 ml-4">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>

          {/* ── Step 1: Route form + students ──────────────────────────────── */}
          {step === 1 && (
            <div className="flex flex-col flex-1 overflow-hidden">
              <div className="overflow-y-auto flex-1 px-6 py-5 space-y-5">
                <RouteFormFields form={form} onChange={onChange} drivers={drivers} selectedDays={selectedDays} onToggleDay={toggleDay} />
                {dateError && <p className="text-xs text-red-500 -mt-2">{dateError}</p>}
                {daysError && <p className="text-xs text-red-500 -mt-2">{daysError}</p>}

                <div className="border-t border-gray-100 pt-4 space-y-5">
                  <p className="text-[10px] font-black tracking-widest text-gray-400 uppercase">Student List</p>

                  {/* Manual Entry */}
                  <div className="bg-gray-50 rounded-xl p-4 space-y-3">
                    <p className="text-xs font-black tracking-widest text-gray-500 uppercase">1 — Manual Entry</p>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="col-span-2">
                        <label className={LABEL}>Student Name</label>
                        <input className={FIELD} value={manualRow.name} onChange={setManual("name")} placeholder="e.g. Jane Smith" />
                      </div>
                      <div>
                        <label className={LABEL}>Grade</label>
                        <input className={FIELD} value={manualRow.grade} onChange={setManual("grade")} placeholder="e.g. Year 6" />
                      </div>
                      <div>
                        <label className={LABEL}>Student Phone</label>
                        <input className={FIELD} value={manualRow.studentPhone} onChange={setManual("studentPhone")} placeholder="e.g. 0412 345 678" />
                      </div>
                      <div className="col-span-2">
                        <label className={LABEL}>Stop Location AM</label>
                        <input className={FIELD} value={manualRow.stopAM} onChange={setManual("stopAM")} placeholder="Morning pick-up address" />
                      </div>
                      <div className="col-span-2">
                        <label className={LABEL}>Stop Location PM</label>
                        <input className={FIELD} value={manualRow.stopPM} onChange={setManual("stopPM")} placeholder="Afternoon drop-off address" />
                      </div>
                      <div>
                        <label className={LABEL}>Order AM</label>
                        <input className={FIELD} type="number" min="1" value={manualRow.orderAM} onChange={setManual("orderAM")} placeholder="1" />
                      </div>
                      <div>
                        <label className={LABEL}>Order PM</label>
                        <input className={FIELD} type="number" min="1" value={manualRow.orderPM} onChange={setManual("orderPM")} placeholder="1" />
                      </div>
                      <div>
                        <label className={LABEL}>Scheduled AM</label>
                        <input className={FIELD} value={manualRow.pickupTime} onChange={setManual("pickupTime")} placeholder="e.g. 08:15 AM" />
                      </div>
                      <div>
                        <label className={LABEL}>Scheduled PM</label>
                        <input className={FIELD} value={manualRow.dropoffTime} onChange={setManual("dropoffTime")} placeholder="e.g. 03:30 PM" />
                      </div>
                    </div>
                    <p className="text-[10px] font-black tracking-widest text-gray-400 uppercase pt-1">Parent / Guardian</p>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="col-span-2">
                        <label className={LABEL}>Parent Name</label>
                        <input className={FIELD} value={manualRow.parentName} onChange={setManual("parentName")} placeholder="e.g. John Smith" />
                      </div>
                      <div>
                        <label className={LABEL}>Parent Phone</label>
                        <input className={FIELD} value={manualRow.parentPhone} onChange={setManual("parentPhone")} placeholder="e.g. 0412 345 678" />
                      </div>
                      <div>
                        <label className={LABEL}>Relationship</label>
                        <select className={FIELD} value={manualRow.relationship} onChange={setManual("relationship")}>
                          <option value="">— select —</option>
                          {RELATIONSHIPS.map(r => <option key={r} value={r}>{r}</option>)}
                        </select>
                      </div>
                    </div>
                    {manualError && <p className="text-xs text-red-500">{manualError}</p>}
                    <button type="button" onClick={addManualStudent}
                      className="w-full py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 transition-colors">
                      + Add Student
                    </button>
                  </div>

                  {/* Upload xlsx */}
                  <div className="space-y-3">
                    <p className="text-xs font-black tracking-widest text-gray-500 uppercase">2 — Upload .xlsx</p>
                    <div className="bg-blue-50 rounded-xl p-4">
                      <p className="text-sm font-bold text-blue-700 mb-3">How many students on this route?</p>
                      <div className="flex items-center gap-3">
                        <input type="number" min="1" max="200" value={templateCount}
                          onChange={e => setTemplateCount(e.target.value)}
                          className="w-20 bg-white border border-gray-200 rounded-lg px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-200" />
                        <button type="button" onClick={downloadTemplate}
                          className="px-4 py-2 bg-blue-600 text-white text-sm font-semibold rounded-lg hover:bg-blue-700 transition-colors">
                          Download Template
                        </button>
                      </div>
                    </div>
                    <p className="text-xs text-gray-400">
                      Columns: Student Name · Grade · Student Phone · Student Email · Order AM · Scheduled AM · Stop Location AM · Order PM · Scheduled PM · Stop Location PM · Parent 1 Name · Parent 1 Phone · Parent Email · Relationship
                    </p>
                    <input ref={fileRef} type="file" accept=".xlsx,.xls" onChange={handleFile} className="hidden" />
                    <button type="button" onClick={() => fileRef.current?.click()}
                      className="w-full border-2 border-dashed border-gray-200 rounded-xl py-6 text-sm text-gray-400 hover:border-gray-300 hover:text-gray-500 transition-colors">
                      Click to upload .xlsx file
                    </button>
                    {fileError && <p className="text-xs text-red-500">{fileError}</p>}
                  </div>

                  {/* Preview list */}
                  {preview.length > 0 && (
                    <div>
                      <p className="text-xs font-bold text-gray-500 mb-2">{preview.length} student{preview.length !== 1 ? "s" : ""} added:</p>
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
                              <th className="px-3 py-2"></th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-gray-50">
                            {preview.map((r, i) => (
                              <tr key={i}>
                                <td className="px-3 py-2 text-gray-700 font-medium">{r.name}</td>
                                <td className="px-3 py-2 text-gray-500">{r.grade}</td>
                                <td className="px-3 py-2 text-gray-500">{r.stopAM}</td>
                                <td className="px-3 py-2 text-gray-500">{r.stopPM}</td>
                                <td className="px-3 py-2 text-gray-500">{r.pickupTime}</td>
                                <td className="px-3 py-2 text-gray-500">{r.dropoffTime}</td>
                                <td className="px-3 py-2">
                                  <button type="button" onClick={() => setPreview(prev => prev.filter((_, j) => j !== i))}
                                    className="text-red-400 hover:text-red-600 transition-colors">
                                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                                  </button>
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  )}
                </div>
              </div>
              <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
                <button type="button" onClick={handleClose} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Cancel</button>
                <button type="button" onClick={goToStep2}
                  disabled={preview.length === 0 || !form.name.trim() || !form.driverId || !form.startDate || !form.endDate}
                  className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors">
                  Continue
                </button>
              </div>
            </div>
          )}

          {/* ── Step 2: Full read-only review table ────────────────────────── */}
          {step === 2 && (
            <div className="flex flex-col flex-1 overflow-hidden">
              {/* Route summary */}
              <div className="px-6 py-3 border-b border-gray-100 bg-gray-50 flex-shrink-0">
                <div className="grid grid-cols-4 gap-x-6 gap-y-1">
                  {[
                    { label: "Route", value: form.name },
                    { label: "Driver", value: drivers.find(d => d.id === form.driverId)?.name ?? "—" },
                    { label: "Bus Rego", value: form.busRegistration || "—" },
                    { label: "Term / Year", value: `Term ${form.term} · ${form.year}` },
                    { label: "Start Date", value: form.startDate ? new Date(form.startDate).toLocaleDateString("en-AU", { day: "2-digit", month: "short", year: "numeric" }) : "—" },
                    { label: "End Date", value: form.endDate ? new Date(form.endDate).toLocaleDateString("en-AU", { day: "2-digit", month: "short", year: "numeric" }) : "—" },
                  ].map(({ label, value }) => (
                    <div key={label}>
                      <p className="text-[9px] font-black tracking-widest text-gray-400 uppercase">{label}</p>
                      <p className="text-xs font-bold text-gray-800 truncate">{value}</p>
                    </div>
                  ))}
                </div>
              </div>
              <div className="overflow-x-auto overflow-y-auto flex-1">
                <table className="text-xs min-w-max w-full">
                  <thead className="bg-blue-600 sticky top-0 z-10">
                    <tr>
                      {PDF_COLS.map(col => (
                        <th key={col} className="px-3 py-3 text-left font-black text-white whitespace-nowrap tracking-wide">{col}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {preview.map((r, i) => (
                      <tr key={i} className={i % 2 === 0 ? "bg-white" : "bg-gray-50"}>
                        <td className="px-3 py-2.5 text-gray-800 font-medium whitespace-nowrap">{r.name || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600 whitespace-nowrap">{r.grade || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600 whitespace-nowrap">{r.studentPhone || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600 whitespace-nowrap">{r.studentEmail || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600 whitespace-nowrap">{r.orderAM || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600 whitespace-nowrap">{r.pickupTime || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600">{r.stopAM || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600 whitespace-nowrap">{r.orderPM || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600 whitespace-nowrap">{r.dropoffTime || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600">{r.stopPM || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600 whitespace-nowrap">{r.parentName || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600 whitespace-nowrap">{r.parentPhone || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600 whitespace-nowrap">{r.parentEmail || "—"}</td>
                        <td className="px-3 py-2.5 text-gray-600 whitespace-nowrap">{r.relationship || "—"}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="px-6 py-4 border-t border-gray-100 flex justify-between gap-3 flex-shrink-0">
                <button type="button" onClick={() => setStep(1)} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">
                  ← Back
                </button>
                <button type="button" onClick={doConfirm} disabled={saving}
                  className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors">
                  {saving ? "Creating schedule…" : "Confirm & Schedule"}
                </button>
              </div>
            </div>
          )}

          {/* ── Step 3: Notification progress screen ───────────────────────── */}
          {step === 3 && (
            <div className="flex flex-col flex-1 overflow-hidden">
              <div className="flex-1 overflow-y-auto px-6 py-8 flex flex-col gap-4">
                {/* Header */}
                <div className="text-center mb-2">
                  <p className="text-sm text-gray-500">Schedule saved. Sending notifications…</p>
                </div>
                {/* Progress rows */}
                <div className="flex flex-col gap-3">
                  {progress.map((row, i) => (
                    <ProgressRowItem key={i} row={row} />
                  ))}
                </div>
                {/* Success banner */}
                {allDone && (
                  <div className="mt-4 flex items-center gap-3 bg-blue-50 border border-blue-200 rounded-2xl px-5 py-4">
                    <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center flex-shrink-0">
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                        <polyline points="20 6 9 17 4 12"/>
                      </svg>
                    </div>
                    <div>
                      <p className="text-sm font-black text-blue-900">Schedule created successfully</p>
                      <p className="text-xs text-blue-600 mt-0.5">All notifications have been sent. Close to return to the dashboard.</p>
                    </div>
                  </div>
                )}
              </div>
              <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
                <button
                  type="button"
                  onClick={handleClose}
                  disabled={!allDone}
                  className="px-6 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors"
                >
                  {allDone ? "Done" : "Please wait…"}
                </button>
              </div>
            </div>
          )}

        </div>
      </Overlay>
      {showUnsaved && (
        <UnsavedModal
          onSave={() => { setShowUnsaved(false); doConfirm(); }}
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
  const { schoolId, schoolName, user } = useAuth();
  const [routes, setRoutes] = useState<Route[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState<Modal | null>(null);
  const [showInactive, setShowInactive] = useState(false);
  const [searchText, setSearchText] = useState("");
  const [sortBy, setSortBy] = useState<"name" | "term" | "year" | "students">("year");
  const [sortDir, setSortDir] = useState<"asc" | "desc">("desc");
  const [filterTerm, setFilterTerm] = useState<number | null>(null);

  const load = useCallback(() => {
    if (!schoolId) return;
    Promise.all([
      getDocs(query(collection(db, "routes"), where("schoolId", "==", schoolId))),
      getDocs(query(collection(db, "drivers"), where("schoolId", "==", schoolId))),
    ]).then(([rSnap, dSnap]) => {
      const loadedRoutes = rSnap.docs.map(d => ({
        id: d.id, ...d.data(),
        startDate: toDate(d.data().startDate),
        endDate: toDate(d.data().endDate),
      } as Route));
      // Sort client-side — avoids needing a Firestore composite index
      loadedRoutes.sort((a, b) => b.startDate.getTime() - a.startDate.getTime());
      setRoutes(loadedRoutes);
      setDrivers(dSnap.docs.map(d => ({ id: d.id, ...d.data() } as Driver)).filter(d => d.isActive));
    }).catch(err => {
      console.error("schedule load error:", err);
    }).finally(() => {
      setLoading(false);
    });
  }, [schoolId]);

  useEffect(() => { load(); }, [load]);

  const closeModal = () => setModal(null);
  const handleAdded = (r: Route) => { setRoutes(prev => [r, ...prev]); closeModal(); };
  const handleSaved = (updated: Route) => { setRoutes(prev => prev.map(r => r.id === updated.id ? updated : r)); closeModal(); };
  const handleRemoved = (id: string) => { setRoutes(prev => prev.map(r => r.id === id ? { ...r, isActive: false } : r)); closeModal(); };

  const handleSort = (col: typeof sortBy) => {
    if (sortBy === col) setSortDir(d => d === "asc" ? "desc" : "asc");
    else { setSortBy(col); setSortDir("asc"); }
  };

  const getDriverName = (driverId: string) => drivers.find(d => d.id === driverId)?.name ?? "";

  const q = searchText.trim().toLowerCase();
  const displayedRoutes = [...routes]
    .filter(r => showInactive || r.isActive)
    .filter(r => filterTerm === null || r.term === filterTerm)
    .filter(r => {
      if (!q) return true;
      return (
        r.name.toLowerCase().includes(q) ||
        getDriverName(r.driverId).toLowerCase().includes(q) ||
        String(r.term).includes(q) ||
        String(r.year).includes(q)
      );
    })
    .sort((a, b) => {
      let cmp = 0;
      if (sortBy === "name") cmp = a.name.localeCompare(b.name);
      else if (sortBy === "term") cmp = a.term - b.term;
      else if (sortBy === "year") cmp = a.year - b.year;
      else if (sortBy === "students") cmp = (a.studentIds?.length ?? 0) - (b.studentIds?.length ?? 0);
      return sortDir === "asc" ? cmp : -cmp;
    });

  return (
    <div className="max-w-5xl mx-auto">
      <PageHeader
        title="SCHEDULE"
        subtitle="All Routes"
        breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Schedule" }]}
      />
      <div className="flex flex-col gap-3 mb-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
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
            {/* Term filter pills */}
            {[1, 2, 3, 4].map(t => (
              <button
                key={t}
                onClick={() => setFilterTerm(f => f === t ? null : t)}
                className={`px-3 py-1.5 text-xs font-bold tracking-widest uppercase rounded-xl border transition-colors ${
                  filterTerm === t
                    ? "bg-blue-600 text-white border-blue-600"
                    : "bg-white text-gray-500 border-gray-200 hover:border-gray-400"
                }`}
              >
                T{t}
              </button>
            ))}
          </div>
          <button
            onClick={() => setModal({ type: "add" })}
            className="px-5 py-2.5 bg-blue-600 text-white text-xs font-bold tracking-widest uppercase rounded-xl hover:bg-blue-700 transition-colors"
          >
            Add Schedule
          </button>
        </div>
        <div className="relative">
          <svg className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></svg>
          <input
            type="text"
            placeholder="Search by route name, driver, term or year…"
            value={searchText}
            onChange={e => setSearchText(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 text-sm bg-white border border-gray-200 rounded-xl text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 transition"
          />
          {searchText && (
            <button onClick={() => setSearchText("")} className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          )}
        </div>
      </div>

      {loading ? (
        <p className="text-sm text-gray-300">Loading...</p>
      ) : displayedRoutes.length === 0 ? (
        <div className="text-center py-16 text-gray-400 text-sm">
          {q || filterTerm !== null ? "No schedules match your filters." : "No schedules yet."}{" "}
          {!q && filterTerm === null && <button onClick={() => setModal({ type: "add" })} className="text-blue-500 hover:underline">Create one</button>}
          {!q && filterTerm === null && "."}
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
          {/* Table header */}
          <div className="grid grid-cols-[2fr_0.6fr_0.6fr_1fr_0.7fr_90px_100px_110px_80px] px-5 py-3 border-b border-gray-100">
            {(
              [
                { label: "Route",    col: "name" as const },
                { label: "Term",     col: "term" as const },
                { label: "Year",     col: "year" as const },
                { label: "Period",   col: null },
                { label: "Students", col: "students" as const },
                { label: "Status",   col: null },
                { label: "",         col: null },
                { label: "",         col: null },
                { label: "",         col: null },
              ] as { label: string; col: typeof sortBy | null }[]
            ).map(({ label, col }, i) =>
              col ? (
                <button key={i} onClick={() => handleSort(col)}
                  className="flex items-center gap-1 text-xs font-bold tracking-widest text-gray-900 uppercase hover:text-blue-600 transition-colors text-left">
                  {label}
                  <svg width="10" height="10" viewBox="0 0 10 10" fill="none" className="flex-shrink-0 opacity-50">
                    {sortBy === col && sortDir === "asc"  && <path d="M5 2l4 6H1z" fill="currentColor"/>}
                    {sortBy === col && sortDir === "desc" && <path d="M5 8l4-6H1z" fill="currentColor"/>}
                    {sortBy !== col && <><path d="M5 1.5l3 4H2z" fill="currentColor" opacity=".4"/><path d="M5 8.5l3-4H2z" fill="currentColor" opacity=".4"/></>}
                  </svg>
                </button>
              ) : (
                <span key={i} className="text-xs font-bold tracking-widest text-gray-900 uppercase">{label}</span>
              )
            )}
          </div>
          {/* Rows */}
          <div className="divide-y divide-gray-50">
            {displayedRoutes.map(route => (
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

      {modal?.type === "add" && <AddScheduleModal schoolId={schoolId} schoolName={schoolName} adminEmail={user?.email ?? ""} drivers={drivers} onClose={closeModal} onAdded={handleAdded} />}
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

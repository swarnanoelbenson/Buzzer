"use client";
import { useEffect, useState, Suspense } from "react";
import { collection, getDocs, doc, updateDoc, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Route, Driver } from "@/lib/types";
import PageHeader from "@/components/PageHeader";
import { useRouter, useSearchParams } from "next/navigation";

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-200 focus:border-orange-400 transition";
const DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

function toDate(v: unknown): Date {
  if (!v) return new Date();
  if (v instanceof Date) return v;
  if (typeof (v as Timestamp).toDate === "function") return (v as Timestamp).toDate();
  return new Date();
}

function toInputDate(d: Date) { return d.toISOString().split("T")[0]; }

function ModifyScheduleForm() {
  const router = useRouter();
  const params = useSearchParams();
  const preId = params.get("id") ?? "";

  const [routes, setRoutes] = useState<Route[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [selected, setSelected] = useState<Route | null>(null);
  const [form, setForm] = useState({ name: "", driverId: "", term: "1", startDate: "", endDate: "" });
  const [selectedDays, setSelectedDays] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    Promise.all([getDocs(collection(db, "routes")), getDocs(collection(db, "drivers"))]).then(([rSnap, dSnap]) => {
      const list = rSnap.docs.map(d => ({ id: d.id, ...d.data(), startDate: toDate(d.data().startDate), endDate: toDate(d.data().endDate) } as Route));
      setRoutes(list);
      setDrivers(dSnap.docs.map(d => ({ id: d.id, ...d.data() } as Driver)));
      if (preId) { const r = list.find(r => r.id === preId); if (r) select(r); }
    });
  }, []);

  const select = (r: Route) => {
    setSelected(r);
    setForm({ name: r.name, driverId: r.driverId, term: String(r.term), startDate: r.startDate instanceof Date ? toInputDate(r.startDate) : "", endDate: r.endDate instanceof Date ? toInputDate(r.endDate) : "" });
    setSelectedDays(r.scheduledDays ?? []);
  };

  const set = (k: string, v: string) => setForm(f => ({ ...f, [k]: v }));
  const toggleDay = (day: string) => setSelectedDays(p => p.includes(day) ? p.filter(d => d !== day) : [...p, day]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selected) return;
    setSaving(true);
    await updateDoc(doc(db, "routes", selected.id), {
      name: form.name.trim(), driverId: form.driverId, term: parseInt(form.term),
      scheduledDays: selectedDays,
      startDate: form.startDate ? Timestamp.fromDate(new Date(form.startDate)) : null,
      endDate: form.endDate ? Timestamp.fromDate(new Date(form.endDate)) : null,
    });
    setSaving(false); setSuccess(true);
    setTimeout(() => router.push("/schedule"), 1200);
  };

  return (
    <div className="max-w-2xl mx-auto">
      <PageHeader title="SCHEDULE" subtitle="Modify Schedule" breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Schedule", href: "/schedule" }, { label: "Modify" }]} accent="orange" />
      {success && <div className="mb-6 px-4 py-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-xl">Saved. Redirecting...</div>}

      <div className="bg-white rounded-2xl border border-gray-100 p-5 mb-5">
        <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Select Route</label>
        <select className={FIELD} value={selected?.id ?? ""} onChange={e => { const r = routes.find(r => r.id === e.target.value); if (r) select(r); }}>
          <option value="">— choose a route —</option>
          {routes.map(r => <option key={r.id} value={r.id}>{r.name} (Term {r.term})</option>)}
        </select>
      </div>

      {selected && (
        <form onSubmit={handleSubmit} className="bg-white rounded-2xl border border-gray-100 p-6 space-y-5">
          <div className="grid grid-cols-2 gap-4">
            <div className="col-span-2"><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Route Name</label><input className={FIELD} required value={form.name} onChange={e => set("name", e.target.value)} /></div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Driver</label>
              <select className={FIELD} value={form.driverId} onChange={e => set("driverId", e.target.value)}>
                <option value="">— select —</option>
                {drivers.map(d => <option key={d.id} value={d.id}>{d.name}</option>)}
              </select>
            </div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Term</label>
              <select className={FIELD} value={form.term} onChange={e => set("term", e.target.value)}>
                {["1","2","3","4"].map(t => <option key={t} value={t}>Term {t}</option>)}
              </select>
            </div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Start Date</label><input className={FIELD} type="date" value={form.startDate} onChange={e => set("startDate", e.target.value)} /></div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">End Date</label><input className={FIELD} type="date" value={form.endDate} onChange={e => set("endDate", e.target.value)} /></div>
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
          <div className="flex justify-end gap-3 pt-2">
            <button type="button" onClick={() => router.push("/schedule")} className="px-6 py-3 text-base text-gray-500 hover:text-gray-700">Cancel</button>
            <button type="submit" disabled={saving} className="px-6 py-3 bg-orange-500 text-white text-base font-semibold rounded-xl hover:bg-orange-600 disabled:opacity-50 transition-colors">{saving ? "Saving..." : "Save Changes"}</button>
          </div>
        </form>
      )}
    </div>
  );
}

export default function ModifySchedulePage() { return <Suspense><ModifyScheduleForm /></Suspense>; }

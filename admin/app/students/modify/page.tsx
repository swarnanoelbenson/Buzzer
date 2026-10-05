"use client";
import { useEffect, useState, Suspense } from "react";
import { collection, getDocs, doc, updateDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Student, Route } from "@/lib/types";
import PageHeader from "@/components/PageHeader";
import { useRouter, useSearchParams } from "next/navigation";

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-base text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-green-200 focus:border-green-400 transition";

function ModifyStudentForm() {
  const router = useRouter();
  const params = useSearchParams();
  const preId = params.get("id") ?? "";

  const [students, setStudents] = useState<Student[]>([]);
  const [routes, setRoutes] = useState<Route[]>([]);
  const [selected, setSelected] = useState<Student | null>(null);
  const [form, setForm] = useState({ name: "", grade: "", stopAddress: "", routeId: "", scheduledPickupTime: "", scheduledDropoffTime: "" });
  const [saving, setSaving] = useState(false);
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    Promise.all([getDocs(collection(db, "students")), getDocs(collection(db, "routes"))]).then(([sSnap, rSnap]) => {
      const list = sSnap.docs.map(d => ({ id: d.id, ...d.data() } as Student));
      setStudents(list);
      setRoutes(rSnap.docs.map(d => ({ id: d.id, ...d.data() } as Route)));
      if (preId) { const s = list.find(s => s.id === preId); if (s) select(s); }
    });
  }, []);

  const select = (s: Student) => {
    setSelected(s);
    setForm({ name: s.name, grade: s.grade, stopAddress: s.stopAddress, routeId: s.routeId, scheduledPickupTime: s.scheduledPickupTime, scheduledDropoffTime: s.scheduledDropoffTime });
  };

  const set = (k: string, v: string) => setForm(f => ({ ...f, [k]: v }));

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selected) return;
    setSaving(true);
    await updateDoc(doc(db, "students", selected.id), { name: form.name.trim(), grade: form.grade.trim(), stopAddress: form.stopAddress.trim(), routeId: form.routeId, scheduledPickupTime: form.scheduledPickupTime, scheduledDropoffTime: form.scheduledDropoffTime });
    setSaving(false); setSuccess(true);
    setTimeout(() => router.push("/students"), 1200);
  };

  return (
    <div className="max-w-2xl mx-auto">
      <PageHeader title="STUDENTS" subtitle="Modify Student" breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Students", href: "/students" }, { label: "Modify" }]} accent="green" />
      {success && <div className="mb-6 px-4 py-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-xl">Saved. Redirecting...</div>}

      <div className="bg-white rounded-2xl border border-gray-100 p-5 mb-5">
        <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Select Student</label>
        <select className={FIELD} value={selected?.id ?? ""} onChange={e => { const s = students.find(s => s.id === e.target.value); if (s) select(s); }}>
          <option value="">— choose a student —</option>
          {students.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
      </div>

      {selected && (
        <form onSubmit={handleSubmit} className="bg-white rounded-2xl border border-gray-100 p-6 space-y-5">
          <div className="grid grid-cols-2 gap-4">
            <div className="col-span-2"><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Full Name</label><input className={FIELD} required value={form.name} onChange={e => set("name", e.target.value)} /></div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Grade</label><input className={FIELD} required value={form.grade} onChange={e => set("grade", e.target.value)} /></div>
            <div className="col-span-2"><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Stop Address</label><input className={FIELD} required value={form.stopAddress} onChange={e => set("stopAddress", e.target.value)} /></div>
            <div className="col-span-2"><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Route</label>
              <select className={FIELD} value={form.routeId} onChange={e => set("routeId", e.target.value)}>
                <option value="">— select a route —</option>
                {routes.map(r => <option key={r.id} value={r.id}>{r.name}</option>)}
              </select>
            </div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Pick-up Time</label><input className={FIELD} value={form.scheduledPickupTime} onChange={e => set("scheduledPickupTime", e.target.value)} /></div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Drop-off Time</label><input className={FIELD} value={form.scheduledDropoffTime} onChange={e => set("scheduledDropoffTime", e.target.value)} /></div>
          </div>
          <div className="flex justify-end gap-3 pt-2">
            <button type="button" onClick={() => router.push("/students")} className="px-6 py-3 text-base text-gray-500 hover:text-gray-700">Cancel</button>
            <button type="submit" disabled={saving} className="px-6 py-3 bg-green-600 text-white text-base font-semibold rounded-xl hover:bg-green-700 disabled:opacity-50 transition-colors">{saving ? "Saving..." : "Save Changes"}</button>
          </div>
        </form>
      )}
    </div>
  );
}

export default function ModifyStudentPage() { return <Suspense><ModifyStudentForm /></Suspense>; }

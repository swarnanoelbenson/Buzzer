"use client";
import { useEffect, useState } from "react";
import { collection, addDoc, getDocs, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Route } from "@/lib/types";
import PageHeader from "@/components/PageHeader";
import PhoneInput from "@/components/PhoneInput";
import { useRouter } from "next/navigation";

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-base text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-green-200 focus:border-green-400 transition";

export default function AddStudentPage() {
  const router = useRouter();
  const [routes, setRoutes] = useState<Route[]>([]);
  const [saving, setSaving] = useState(false);
  const [success, setSuccess] = useState(false);
  const [form, setForm] = useState({
    name: "", grade: "", stopAddressAM: "", stopAddressPM: "", routeId: "",
    scheduledPickupTime: "", scheduledDropoffTime: "",
    parentOneName: "", parentOnePhone: "",
    parentTwoName: "", parentTwoPhone: "",
    studentPhone: "",
  });

  useEffect(() => {
    getDocs(collection(db, "routes")).then(snap => {
      setRoutes(snap.docs.map(d => ({ id: d.id, ...d.data() } as Route)));
    });
  }, []);

  const set = (key: string, val: string) => setForm(f => ({ ...f, [key]: val }));

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await addDoc(collection(db, "students"), {
        name: form.name.trim(),
        grade: form.grade.trim(),
        stopAddressAM: form.stopAddressAM.trim(),
        stopAddressPM: form.stopAddressPM.trim(),
        routeId: form.routeId,
        scheduledPickupTime: form.scheduledPickupTime,
        scheduledDropoffTime: form.scheduledDropoffTime,
        phone: form.studentPhone.trim() ? `+61${form.studentPhone.trim()}` : "",
        authorisedParentIds: [],
        isActive: true,
        createdAt: Timestamp.now(),
        // Store parent info for later parent profile creation
        parentInfo: [
          { name: form.parentOneName.trim(), phone: form.parentOnePhone.trim() ? `+61${form.parentOnePhone.trim()}` : "" },
          form.parentTwoName ? { name: form.parentTwoName.trim(), phone: form.parentTwoPhone.trim() ? `+61${form.parentTwoPhone.trim()}` : "" } : null,
        ].filter(Boolean),
      });
      setSuccess(true);
      setTimeout(() => router.push("/students"), 1200);
    } catch (err) { console.error(err); }
    setSaving(false);
  };

  return (
    <div className="max-w-2xl mx-auto">
      <PageHeader title="STUDENTS" subtitle="Add Student" breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Students", href: "/students" }, { label: "Add" }]} accent="green" />

      {success && <div className="mb-6 px-4 py-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-xl">Student added. Redirecting...</div>}

      <form onSubmit={handleSubmit} className="bg-white rounded-2xl border border-gray-100 p-6 space-y-5">
        <div className="grid grid-cols-2 gap-4">
          <div className="col-span-2"><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Full Name</label><input className={FIELD} required value={form.name} onChange={e => set("name", e.target.value)} placeholder="e.g. Liam Chen" /></div>
          <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Grade</label><input className={FIELD} required value={form.grade} onChange={e => set("grade", e.target.value)} placeholder="Year 5" /></div>
          <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Student Phone</label><PhoneInput className={FIELD} value={form.studentPhone} onChange={v => set("studentPhone", v)} /></div>
          <div className="col-span-2"><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Stop Address AM (Morning Pick-up)</label><input className={FIELD} required value={form.stopAddressAM} onChange={e => set("stopAddressAM", e.target.value)} placeholder="12 Oak St, Parramatta NSW 2150" /></div>
          <div className="col-span-2"><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Stop Address PM (Afternoon Drop-off)</label><input className={FIELD} required value={form.stopAddressPM} onChange={e => set("stopAddressPM", e.target.value)} placeholder="12 Oak St, Parramatta NSW 2150" /></div>
          <div className="col-span-2"><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Assigned Route</label>
            <select className={FIELD} value={form.routeId} onChange={e => set("routeId", e.target.value)}>
              <option value="">— select a route —</option>
              {routes.map(r => <option key={r.id} value={r.id}>{r.name}</option>)}
            </select>
          </div>
          <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Scheduled Pick-up Time</label><input className={FIELD} required value={form.scheduledPickupTime} onChange={e => set("scheduledPickupTime", e.target.value)} placeholder="08:00 AM" /></div>
          <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Scheduled Drop-off Time</label><input className={FIELD} required value={form.scheduledDropoffTime} onChange={e => set("scheduledDropoffTime", e.target.value)} placeholder="03:30 PM" /></div>

          <div className="col-span-2 border-t border-gray-100 pt-4">
            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Parent / Guardian Details</p>
          </div>
          <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Parent 1 Name</label><input className={FIELD} value={form.parentOneName} onChange={e => set("parentOneName", e.target.value)} placeholder="Emma Chen" /></div>
          <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Parent 1 Phone</label><PhoneInput className={FIELD} value={form.parentOnePhone} onChange={v => set("parentOnePhone", v)} /></div>
          <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Parent 2 Name (optional)</label><input className={FIELD} value={form.parentTwoName} onChange={e => set("parentTwoName", e.target.value)} placeholder="James Chen" /></div>
          <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Parent 2 Phone (optional)</label><PhoneInput className={FIELD} value={form.parentTwoPhone} onChange={v => set("parentTwoPhone", v)} /></div>
        </div>

        <div className="flex justify-end gap-3 pt-2">
          <button type="button" onClick={() => router.push("/students")} className="px-6 py-3 text-base text-gray-500 hover:text-gray-700">Cancel</button>
          <button type="submit" disabled={saving} className="px-6 py-3 bg-green-600 text-white text-base font-semibold rounded-xl hover:bg-green-700 disabled:opacity-50 transition-colors">{saving ? "Saving..." : "Add Student"}</button>
        </div>
      </form>
    </div>
  );
}

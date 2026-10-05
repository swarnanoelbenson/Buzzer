"use client";
import { useEffect, useState, Suspense } from "react";
import { collection, getDocs, doc, updateDoc, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Driver } from "@/lib/types";
import PageHeader from "@/components/PageHeader";
import PhoneInput, { stripPrefix } from "@/components/PhoneInput";
import { useRouter, useSearchParams } from "next/navigation";

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-base text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 transition";

function toDate(v: unknown): Date {
  if (!v) return new Date();
  if (v instanceof Date) return v;
  if (typeof (v as Timestamp).toDate === "function") return (v as Timestamp).toDate();
  return new Date();
}

function toInputDate(d: Date): string {
  return d.toISOString().split("T")[0];
}

function ModifyDriverForm() {
  const router = useRouter();
  const params = useSearchParams();
  const preselectedId = params.get("id") ?? "";

  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [selected, setSelected] = useState<Driver | null>(null);
  const [form, setForm] = useState({ name: "", phone: "", age: "", gender: "Male", address: "", childrenCheck: "", driversLicense: "", licenseExpiry: "" });
  const [saving, setSaving] = useState(false);
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    getDocs(collection(db, "drivers")).then(snap => {
      const list = snap.docs.map(d => ({ id: d.id, ...d.data(), licenseExpiry: toDate(d.data().licenseExpiry), createdAt: toDate(d.data().createdAt) } as Driver));
      setDrivers(list);
      if (preselectedId) {
        const found = list.find(d => d.id === preselectedId);
        if (found) selectDriver(found);
      }
    });
  }, []);

  const selectDriver = (d: Driver) => {
    setSelected(d);
    setForm({
      name: d.name, phone: stripPrefix(d.phone), age: String(d.age),
      gender: d.gender, address: d.address, childrenCheck: d.childrenCheck,
      driversLicense: d.driversLicense,
      licenseExpiry: d.licenseExpiry instanceof Date ? toInputDate(d.licenseExpiry) : "",
    });
  };

  const set = (key: string, val: string) => setForm(f => ({ ...f, [key]: val }));

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selected) return;
    setSaving(true);
    await updateDoc(doc(db, "drivers", selected.id), {
      name: form.name.trim(), phone: form.phone.trim() ? `+61${form.phone.trim()}` : "", age: parseInt(form.age) || 0,
      gender: form.gender, address: form.address.trim(),
      childrenCheck: form.childrenCheck.trim(), driversLicense: form.driversLicense.trim(),
      licenseExpiry: form.licenseExpiry ? Timestamp.fromDate(new Date(form.licenseExpiry)) : null,
    });
    setSaving(false);
    setSuccess(true);
    setTimeout(() => router.push("/drivers"), 1200);
  };

  return (
    <div className="max-w-2xl mx-auto">
      <PageHeader title="DRIVERS" subtitle="Modify Driver" breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Drivers", href: "/drivers" }, { label: "Modify" }]} accent="blue" />

      {success && <div className="mb-6 px-4 py-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-xl">Saved. Redirecting...</div>}

      {/* Driver selector */}
      <div className="bg-white rounded-2xl border border-gray-100 p-5 mb-5">
        <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Select Driver</label>
        <select className={FIELD} value={selected?.id ?? ""} onChange={e => { const d = drivers.find(d => d.id === e.target.value); if (d) selectDriver(d); }}>
          <option value="">— choose a driver —</option>
          {drivers.map(d => <option key={d.id} value={d.id}>{d.name}</option>)}
        </select>
      </div>

      {selected && (
        <form onSubmit={handleSubmit} className="bg-white rounded-2xl border border-gray-100 p-6 space-y-5">
          <div className="grid grid-cols-2 gap-4">
            <div className="col-span-2">
              <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Full Name</label>
              <input className={FIELD} required value={form.name} onChange={e => set("name", e.target.value)} />
            </div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Phone</label><PhoneInput className={FIELD} required value={form.phone} onChange={v => set("phone", v)} /></div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Age</label><input className={FIELD} type="number" value={form.age} onChange={e => set("age", e.target.value)} /></div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Gender</label><select className={FIELD} value={form.gender} onChange={e => set("gender", e.target.value)}>{["Male","Female","Prefer not to say"].map(g => <option key={g}>{g}</option>)}</select></div>
<div className="col-span-2"><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Address</label><input className={FIELD} value={form.address} onChange={e => set("address", e.target.value)} /></div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">WWC Check</label><input className={FIELD} value={form.childrenCheck} onChange={e => set("childrenCheck", e.target.value)} /></div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Driver&apos;s Licence</label><input className={FIELD} value={form.driversLicense} onChange={e => set("driversLicense", e.target.value)} /></div>
            <div><label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Licence Expiry</label><input className={FIELD} type="date" value={form.licenseExpiry} onChange={e => set("licenseExpiry", e.target.value)} /></div>
          </div>
          <div className="flex justify-end gap-3 pt-2">
            <button type="button" onClick={() => router.push("/drivers")} className="px-6 py-3 text-base text-gray-500 hover:text-gray-700">Cancel</button>
            <button type="submit" disabled={saving} className="px-6 py-3 bg-blue-600 text-white text-base font-semibold rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors">{saving ? "Saving..." : "Save Changes"}</button>
          </div>
        </form>
      )}
    </div>
  );
}

export default function ModifyDriverPage() {
  return <Suspense><ModifyDriverForm /></Suspense>;
}

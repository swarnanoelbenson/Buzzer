"use client";
import { useState } from "react";
import { collection, addDoc, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import PageHeader from "@/components/PageHeader";
import PhoneInput from "@/components/PhoneInput";
import { useRouter } from "next/navigation";

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-base text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 transition";

export default function AddDriverPage() {
  const router = useRouter();
  const [saving, setSaving] = useState(false);
  const [success, setSuccess] = useState(false);
  const [ageError, setAgeError] = useState("");
  const [form, setForm] = useState({
    name: "", phone: "", age: "", gender: "Male", address: "",
    childrenCheck: "", driversLicense: "", licenseExpiry: "",
    busRegistration: "",
  });

  const set = (key: string, val: string) => setForm(f => ({ ...f, [key]: val }));

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const age = parseInt(form.age) || 0;
    if (age < 21) {
      setAgeError("Driver must be at least 21 years old.");
      return;
    }
    setAgeError("");
    setSaving(true);
    try {
      await addDoc(collection(db, "drivers"), {
        name: form.name.trim(),
        phone: form.phone.trim() ? `+61${form.phone.trim()}` : "",
        age: parseInt(form.age) || 0,
        gender: form.gender,
        address: form.address.trim(),
        childrenCheck: form.childrenCheck.trim(),
        driversLicense: form.driversLicense.trim(),
        licenseExpiry: form.licenseExpiry ? Timestamp.fromDate(new Date(form.licenseExpiry)) : null,
        busRegistration: form.busRegistration.trim(),
        imageUrl: "",
        isActive: true,
        createdAt: Timestamp.now(),
      });
      setSuccess(true);
      setTimeout(() => router.push("/drivers"), 1200);
    } catch (err) {
      console.error(err);
    }
    setSaving(false);
  };

  return (
    <div className="max-w-2xl mx-auto">
      <PageHeader
        title="DRIVERS"
        subtitle="Add Driver"
        breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Drivers", href: "/drivers" }, { label: "Add" }]}
      />

      {success && (
        <div className="mb-6 px-4 py-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-xl">
          Driver added successfully. Redirecting...
        </div>
      )}

      <form onSubmit={handleSubmit} className="bg-white rounded-2xl border border-gray-100 p-6 space-y-5">
        <div className="grid grid-cols-2 gap-4">
          <div className="col-span-2">
            <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Full Name</label>
            <input className={FIELD} required value={form.name} onChange={e => set("name", e.target.value)} placeholder="e.g. John Mitchell" />
          </div>
          <div>
            <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Phone Number</label>
            <PhoneInput className={FIELD} required value={form.phone} onChange={v => set("phone", v)} />
          </div>
          <div>
            <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Age</label>
            <input
              className={`${FIELD} ${ageError ? "border-red-400 focus:border-red-400 focus:ring-red-200" : ""}`}
              type="number"
              required
              min={21}
              value={form.age}
              onChange={e => { set("age", e.target.value); if (ageError) setAgeError(""); }}
              placeholder="45"
            />
            {ageError && <p className="mt-1 text-xs text-red-600 font-medium">{ageError}</p>}
          </div>
          <div>
            <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Gender</label>
            <select className={FIELD} value={form.gender} onChange={e => set("gender", e.target.value)}>
              {["Male", "Female", "Prefer not to say"].map(g => <option key={g}>{g}</option>)}
            </select>
          </div>
          <div>
            <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Bus Registration</label>
            <input className={FIELD} required value={form.busRegistration} onChange={e => set("busRegistration", e.target.value)} placeholder="BUS001" />
          </div>
          <div className="col-span-2">
            <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Residential Address</label>
            <input className={FIELD} required value={form.address} onChange={e => set("address", e.target.value)} placeholder="14 Wattle St, Parramatta NSW 2150" />
          </div>

          <div className="col-span-2 border-t border-gray-100 pt-4">
            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Credentials & Licencing</p>
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Working with Children Check</label>
            <input className={FIELD} required value={form.childrenCheck} onChange={e => set("childrenCheck", e.target.value)} placeholder="WWC1234567E" />
          </div>
          <div>
            <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Driver&apos;s Licence Number</label>
            <input className={FIELD} required value={form.driversLicense} onChange={e => set("driversLicense", e.target.value)} placeholder="NSW12345678" />
          </div>
          <div>
            <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Licence Expiry Date</label>
            <input className={FIELD} type="date" required value={form.licenseExpiry} onChange={e => set("licenseExpiry", e.target.value)} />
          </div>
        </div>

        <div className="flex justify-end gap-3 pt-2">
          <button type="button" onClick={() => router.push("/drivers")} className="px-6 py-3 text-base text-gray-500 hover:text-gray-700 transition-colors">
            Cancel
          </button>
          <button
            type="submit"
            disabled={saving}
            className="px-6 py-3 bg-blue-600 text-white text-base font-semibold rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors"
          >
            {saving ? "Saving..." : "Add Driver"}
          </button>
        </div>
      </form>
    </div>
  );
}

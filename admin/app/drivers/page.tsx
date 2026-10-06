"use client";
import { useEffect, useState, useCallback, useRef } from "react";
import { collection, getDocs, doc, addDoc, updateDoc, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
import type { Driver } from "@/lib/types";
import PageHeader from "@/components/PageHeader";
import PhoneInput, { stripPrefix } from "@/components/PhoneInput";

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

type FormState = {
  name: string; phone: string; age: string; gender: string;
  address: string; childrenCheck: string; driversLicense: string;
  licenseExpiry: string;
};

const EMPTY_FORM: FormState = {
  name: "", phone: "", age: "", gender: "Male",
  address: "", childrenCheck: "", driversLicense: "",
  licenseExpiry: "",
};

function driverToForm(d: Driver): FormState {
  return {
    name: d.name, phone: stripPrefix(d.phone), age: String(d.age),
    gender: d.gender, address: d.address,
    childrenCheck: d.childrenCheck, driversLicense: d.driversLicense,
    licenseExpiry: d.licenseExpiry instanceof Date ? toInputDate(d.licenseExpiry) : "",
  };
}

function formChanged(original: FormState, current: FormState): boolean {
  return (Object.keys(original) as (keyof FormState)[]).some(k => original[k] !== current[k]);
}

const DIFF_FIELDS: { key: keyof FormState; label: string }[] = [
  { key: "name",            label: "Full Name" },
  { key: "phone",           label: "Phone" },
  { key: "age",             label: "Age" },
  { key: "gender",          label: "Gender" },
  { key: "address",         label: "Address" },
  { key: "childrenCheck",   label: "WWC Check" },
  { key: "driversLicense",  label: "Driver's Licence" },
  { key: "licenseExpiry",   label: "Licence Expiry" },
];

// ── Overlay backdrop ─────────────────────────────────────────────────────────

function Overlay({ children }: { children: React.ReactNode }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
      {children}
    </div>
  );
}

// ── Preview Modal ─────────────────────────────────────────────────────────────

function PreviewModal({ driver, onClose, onEdit }: { driver: Driver; onClose: () => void; onEdit: () => void }) {
  const fields = [
    { label: "Phone",            value: driver.phone },
    { label: "Age",              value: String(driver.age) },
    { label: "Gender",           value: driver.gender },
    { label: "Address",          value: driver.address },
    { label: "WWC Check",        value: driver.childrenCheck },
    { label: "Driver's Licence", value: driver.driversLicense },
    { label: "Licence Expiry",   value: driver.licenseExpiry instanceof Date ? driver.licenseExpiry.toLocaleDateString("en-AU") : "—" },
    { label: "Status",           value: driver.isActive ? "Active" : "Inactive" },
  ];

  return (
    <Overlay>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[90vh] flex flex-col">
        <div className="px-6 py-5 border-b border-gray-100 flex items-center gap-4 flex-shrink-0">
          <div className="w-12 h-12 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 text-lg font-black">
            {driver.name.charAt(0)}
          </div>
          <div>
            <div className="text-base font-black text-gray-900">{driver.name}</div>
            <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${driver.isActive ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500"}`}>
              {driver.isActive ? "Active" : "Inactive"}
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
          <button onClick={onEdit} className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 transition-colors">Edit Driver</button>
        </div>
      </div>
    </Overlay>
  );
}

// ── Driver Form fields (shared) ───────────────────────────────────────────────

function DriverForm({ form, onChange }: { form: FormState; onChange: (key: keyof FormState, val: string) => void }) {
  const set = (key: keyof FormState) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => onChange(key, e.target.value);
  return (
    <div className="grid grid-cols-2 gap-4">
      <div className="col-span-2">
        <label className={LABEL}>Full Name</label>
        <input className={FIELD} required value={form.name} onChange={set("name")} placeholder="e.g. John Mitchell" />
      </div>
      <div>
        <label className={LABEL}>Phone Number</label>
        <PhoneInput className={FIELD} required value={form.phone} onChange={v => onChange("phone", v)} />
      </div>
      <div>
        <label className={LABEL}>Age</label>
        <input className={FIELD} type="number" required value={form.age} onChange={set("age")} placeholder="45" />
      </div>
      <div>
        <label className={LABEL}>Gender</label>
        <select className={FIELD} value={form.gender} onChange={set("gender")}>
          {["Male", "Female", "Prefer not to say"].map(g => <option key={g}>{g}</option>)}
        </select>
      </div>
      <div className="col-span-2">
        <label className={LABEL}>Residential Address</label>
        <input className={FIELD} required value={form.address} onChange={set("address")} placeholder="14 Wattle St, Parramatta NSW 2150" />
      </div>
      <div className="col-span-2 border-t border-gray-100 pt-3">
        <p className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-3">Credentials &amp; Licensing</p>
      </div>
      <div>
        <label className={LABEL}>Working with Children Check</label>
        <input className={FIELD} required value={form.childrenCheck} onChange={set("childrenCheck")} placeholder="WWC1234567E" />
      </div>
      <div>
        <label className={LABEL}>Driver&apos;s Licence Number</label>
        <input className={FIELD} required value={form.driversLicense} onChange={set("driversLicense")} placeholder="NSW12345678" />
      </div>
      <div>
        <label className={LABEL}>Licence Expiry Date</label>
        <input className={FIELD} type="date" required value={form.licenseExpiry} onChange={set("licenseExpiry")} />
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
  original: FormState; updated: FormState;
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
                <span className="text-[10px] font-black tracking-widests text-gray-400 uppercase">Before</span>
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

// ── Add Driver Modal ──────────────────────────────────────────────────────────

function AddDriverModal({ onClose, onAdded }: { onClose: () => void; onAdded: (d: Driver) => void }) {
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [showUnsaved, setShowUnsaved] = useState(false);
  const [ageError, setAgeError] = useState("");
  const [licenceWarning, setLicenceWarning] = useState("");

  const isDirty = formChanged(EMPTY_FORM, form);
  const onChange = (key: keyof FormState, val: string) => {
    setForm(f => ({ ...f, [key]: val }));
    if (key === "age") setAgeError("");
    if (key === "licenseExpiry") setLicenceWarning("");
  };

  const handleClose = () => {
    if (isDirty) { setShowUnsaved(true); return; }
    onClose();
  };

  const doSave = async () => {
    const age = parseInt(form.age) || 0;
    if (age < 21) { setAgeError("Driver must be at least 21 years old."); return; }
    setAgeError("");
    if (form.licenseExpiry && new Date(form.licenseExpiry) < new Date()) {
      setLicenceWarning("Licence expiry date is in the past.");
    }
    setSaving(true);
    try {
      const ref = await addDoc(collection(db, "drivers"), {
        name: form.name.trim(), phone: form.phone.trim() ? `+61${form.phone.trim()}` : "",
        age: parseInt(form.age) || 0, gender: form.gender,
        address: form.address.trim(), childrenCheck: form.childrenCheck.trim(),
        driversLicense: form.driversLicense.trim(),
        licenseExpiry: form.licenseExpiry ? Timestamp.fromDate(new Date(form.licenseExpiry)) : null,
        imageUrl: "", isActive: true, createdAt: Timestamp.now(),
      });
      const newDriver: Driver = {
        id: ref.id, name: form.name.trim(), phone: form.phone.trim() ? `+61${form.phone.trim()}` : "",
        age: parseInt(form.age) || 0, gender: form.gender,
        address: form.address.trim(), childrenCheck: form.childrenCheck.trim(),
        driversLicense: form.driversLicense.trim(),
        licenseExpiry: form.licenseExpiry ? new Date(form.licenseExpiry) : new Date(),
        isActive: true, createdAt: new Date(),
      };
      onAdded(newDriver);
    } catch (err) { console.error(err); }
    setSaving(false);
  };

  const handleSubmit = (e: React.FormEvent) => { e.preventDefault(); doSave(); };

  return (
    <>
      <Overlay>
        <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col">
          <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
            <div>
              <h3 className="text-base font-black text-gray-900">Add Driver</h3>
              <p className="text-xs text-gray-400 mt-0.5">Fill in all required fields</p>
            </div>
            <button onClick={handleClose} className="text-gray-400 hover:text-gray-600">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
          <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
            <div className="overflow-y-auto flex-1 px-6 py-5 space-y-3">
              <DriverForm form={form} onChange={onChange} />
              {ageError && <p className="text-xs text-red-500">{ageError}</p>}
              {licenceWarning && <p className="text-xs text-amber-600">{licenceWarning}</p>}
            </div>
            <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
              <button type="button" onClick={handleClose} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Cancel</button>
              <button type="submit" disabled={saving} className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors">
                {saving ? "Saving..." : "Add Driver"}
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

// ── Edit Driver Modal ─────────────────────────────────────────────────────────

function EditDriverModal({ driver, onClose, onSaved }: {
  driver: Driver; onClose: () => void; onSaved: (d: Driver) => void;
}) {
  const original = driverToForm(driver);
  const [form, setForm] = useState<FormState>(original);
  const [showUnsaved, setShowUnsaved] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [ageError, setAgeError] = useState("");
  const [licenceWarning, setLicenceWarning] = useState("");

  const isDirty = formChanged(original, form);
  const onChange = (key: keyof FormState, val: string) => {
    setForm(f => ({ ...f, [key]: val }));
    if (key === "age") setAgeError("");
    if (key === "licenseExpiry") setLicenceWarning("");
  };

  const handleClose = () => {
    if (isDirty) { setShowUnsaved(true); return; }
    onClose();
  };

  const doSave = async () => {
    setSaving(true);
    try {
      await updateDoc(doc(db, "drivers", driver.id), {
        name: form.name.trim(), phone: form.phone.trim() ? `+61${form.phone.trim()}` : "",
        age: parseInt(form.age) || 0, gender: form.gender,
        address: form.address.trim(), childrenCheck: form.childrenCheck.trim(),
        driversLicense: form.driversLicense.trim(),
        licenseExpiry: form.licenseExpiry ? Timestamp.fromDate(new Date(form.licenseExpiry)) : null,
      });
      const updated: Driver = {
        ...driver, name: form.name.trim(), phone: form.phone.trim() ? `+61${form.phone.trim()}` : "",
        age: parseInt(form.age) || 0, gender: form.gender,
        address: form.address.trim(), childrenCheck: form.childrenCheck.trim(),
        driversLicense: form.driversLicense.trim(),
        licenseExpiry: form.licenseExpiry ? new Date(form.licenseExpiry) : driver.licenseExpiry,
      };
      onSaved(updated);
    } catch (err) { console.error(err); }
    setSaving(false);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!isDirty) return;
    const age = parseInt(form.age) || 0;
    if (age < 21) { setAgeError("Driver must be at least 21 years old."); return; }
    setAgeError("");
    if (form.licenseExpiry && new Date(form.licenseExpiry) < new Date()) {
      setLicenceWarning("Licence expiry date is in the past.");
    } else {
      setLicenceWarning("");
    }
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
              <h3 className="text-base font-black text-gray-900">Edit — {driver.name}</h3>
              <p className="text-xs text-gray-400 mt-0.5">Changes shown for confirmation before saving</p>
            </div>
            <button onClick={handleClose} className="text-gray-400 hover:text-gray-600">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
          <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
            <div className="overflow-y-auto flex-1 px-6 py-5 space-y-3">
              <DriverForm form={form} onChange={onChange} />
              {ageError && <p className="text-xs text-red-500">{ageError}</p>}
              {licenceWarning && <p className="text-xs text-amber-600">{licenceWarning}</p>}
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

// ── Remove Driver Modal ───────────────────────────────────────────────────────

function RemoveDriverModal({ driver, onClose, onRemoved, user }: {
  driver: Driver; onClose: () => void; onRemoved: (id: string) => void;
  user: { uid?: string; displayName?: string | null; email?: string | null } | null;
}) {
  const [reason, setReason] = useState("");
  const [saving, setSaving] = useState(false);

  const confirmRemove = async () => {
    setSaving(true);
    const now = new Date();
    await updateDoc(doc(db, "drivers", driver.id), { isActive: false });
    await addDoc(collection(db, "adminLog"), {
      type: "remove_driver", tag: "REMOVE DRIVER",
      actorId: user?.uid ?? "admin",
      actorName: user?.displayName ?? user?.email ?? "Admin",
      targetId: driver.id, targetName: driver.name,
      details: `Driver removed: ${driver.name} (${driver.phone})`,
      reason: reason.trim() || "No reason provided",
      timestamp: Timestamp.now(),
      year: now.getFullYear(),
      term: Math.ceil((now.getMonth() + 1) / 3),
      month: now.getMonth() + 1,
    });
    setSaving(false);
    onRemoved(driver.id);
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
            <h3 className="text-base font-black text-gray-900">Remove {driver.name}</h3>
            <p className="text-xs text-gray-400">This will deactivate the driver and log the action.</p>
          </div>
        </div>
        <div className="bg-gray-50 rounded-xl p-4 mb-4">
          <div className="grid grid-cols-2 gap-4 divide-x divide-gray-200">
            <div>
              <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">Before</div>
              <div className="font-bold text-gray-900 text-sm">{driver.name}</div>
              <div className="text-xs text-gray-500">{driver.phone}</div>
              <span className="inline-block mt-1.5 text-[10px] font-black px-2 py-0.5 rounded-full bg-green-100 text-green-700">Active</span>
            </div>
            <div className="pl-4">
              <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">After</div>
              <div className="font-bold text-gray-900 text-sm">{driver.name}</div>
              <div className="text-xs text-gray-500">{driver.phone}</div>
              <span className="inline-block mt-1.5 text-[10px] font-black px-2 py-0.5 rounded-full bg-gray-100 text-gray-500">Inactive</span>
            </div>
          </div>
        </div>
        <label className={LABEL}>Reason for Removal</label>
        <textarea
          rows={3}
          className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-red-200 focus:border-red-400 transition resize-none"
          placeholder="Why is this driver being removed? (saved to admin log)"
          value={reason}
          onChange={e => setReason(e.target.value)}
        />
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

// ── Reactivate Driver Modal ───────────────────────────────────────────────────

function ReactivateDriverModal({ driver, onClose, onReactivated, user }: {
  driver: Driver; onClose: () => void; onReactivated: (updated: Driver) => void;
  user: { uid?: string; displayName?: string | null; email?: string | null } | null;
}) {
  const original = driverToForm(driver);
  const [form, setForm] = useState<FormState>(original);
  const [saving, setSaving] = useState(false);

  const onChange = (key: keyof FormState, val: string) => setForm(f => ({ ...f, [key]: val }));

  const handleReactivate = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    const now = new Date();
    try {
      await updateDoc(doc(db, "drivers", driver.id), {
        isActive: true,
        name: form.name.trim(), phone: form.phone.trim() ? `+61${form.phone.trim()}` : "",
        age: parseInt(form.age) || 0, gender: form.gender,
        address: form.address.trim(), childrenCheck: form.childrenCheck.trim(),
        driversLicense: form.driversLicense.trim(),
        licenseExpiry: form.licenseExpiry ? Timestamp.fromDate(new Date(form.licenseExpiry)) : null,
      });
      await addDoc(collection(db, "adminLog"), {
        type: "reactivate_driver", tag: "REACTIVATE DRIVER",
        actorId: user?.uid ?? "admin",
        actorName: user?.displayName ?? user?.email ?? "Admin",
        targetId: driver.id, targetName: form.name.trim(),
        details: `Driver reactivated: ${form.name.trim()} (+61${form.phone.trim()})`,
        timestamp: Timestamp.now(),
        year: now.getFullYear(),
        term: Math.ceil((now.getMonth() + 1) / 3),
        month: now.getMonth() + 1,
      });
      const updated: Driver = {
        ...driver, isActive: true,
        name: form.name.trim(), phone: form.phone.trim() ? `+61${form.phone.trim()}` : "",
        age: parseInt(form.age) || 0, gender: form.gender,
        address: form.address.trim(), childrenCheck: form.childrenCheck.trim(),
        driversLicense: form.driversLicense.trim(),
        licenseExpiry: form.licenseExpiry ? new Date(form.licenseExpiry) : driver.licenseExpiry,
      };
      onReactivated(updated);
    } catch (err) { console.error(err); }
    setSaving(false);
  };

  return (
    <Overlay>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col">
        <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
          <div>
            <h3 className="text-base font-black text-gray-900">Reactivate — {driver.name}</h3>
            <p className="text-xs text-gray-400 mt-0.5">Review and update details before reactivating</p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <form onSubmit={handleReactivate} className="flex flex-col flex-1 overflow-hidden">
          <div className="overflow-y-auto flex-1 px-6 py-5">
            <DriverForm form={form} onChange={onChange} />
          </div>
          <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
            <button type="button" onClick={onClose} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Cancel</button>
            <button type="submit" disabled={saving}
              className="px-5 py-2.5 bg-green-600 text-white text-sm font-black rounded-xl hover:bg-green-700 disabled:opacity-50 transition-colors">
              {saving ? "Reactivating..." : "Confirm Reactivate"}
            </button>
          </div>
        </form>
      </div>
    </Overlay>
  );
}

// ── Main Page ─────────────────────────────────────────────────────────────────

type Modal =
  | { type: "add" }
  | { type: "preview"; driver: Driver }
  | { type: "edit"; driver: Driver }
  | { type: "remove"; driver: Driver }
  | { type: "reactivate"; driver: Driver };

// Redact a string by replacing all characters with bullets, preserving length capped at 8
function redact(val: string) {
  if (!val) return "—";
  return "•".repeat(Math.min(val.length, 8));
}

export default function DriversPage() {
  const { user } = useAuth();
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState<Modal | null>(null);
  const [showInactive, setShowInactive] = useState(false);
  const [searchText, setSearchText] = useState("");
  const [sortBy, setSortBy] = useState<"name" | "expiry">("name");
  const [sortDir, setSortDir] = useState<"asc" | "desc">("asc");
  // Track which row is revealed + activity-based auto-hide
  const [revealedId, setRevealedId] = useState<string | null>(null);
  const revealTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const load = useCallback(() => {
    getDocs(collection(db, "drivers")).then(snap => {
      setDrivers(snap.docs.map(d => ({
        id: d.id, ...d.data(),
        licenseExpiry: toDate(d.data().licenseExpiry),
        createdAt: toDate(d.data().createdAt),
      } as Driver)));
      setLoading(false);
    });
  }, []);

  useEffect(() => { load(); }, [load]);

  // Auto-hide revealed row after 15 minutes of browser inactivity.
  // Any mouse/keyboard activity resets the idle countdown.
  const REVEAL_IDLE_MS = 15 * 60 * 1000; // 15 minutes
  const ACTIVITY_EVENTS = ["mousemove", "mousedown", "keydown", "click"] as const;

  const clearRevealTimer = useCallback(() => {
    if (revealTimerRef.current) { clearTimeout(revealTimerRef.current); revealTimerRef.current = null; }
  }, []);

  const resetRevealTimer = useCallback(() => {
    clearRevealTimer();
    revealTimerRef.current = setTimeout(() => {
      setRevealedId(null);
    }, REVEAL_IDLE_MS);
  }, [clearRevealTimer]);

  // Attach/detach activity listeners whenever a row is revealed
  useEffect(() => {
    if (!revealedId) {
      clearRevealTimer();
      ACTIVITY_EVENTS.forEach(e => window.removeEventListener(e, resetRevealTimer));
      return;
    }
    resetRevealTimer();
    ACTIVITY_EVENTS.forEach(e => window.addEventListener(e, resetRevealTimer, { passive: true }));
    return () => {
      clearRevealTimer();
      ACTIVITY_EVENTS.forEach(e => window.removeEventListener(e, resetRevealTimer));
    };
  }, [revealedId, resetRevealTimer, clearRevealTimer]);

  const handleRowClick = (id: string) => {
    // Toggle: clicking revealed row hides it
    setRevealedId(prev => prev === id ? null : id);
  };

  const closeModal = () => setModal(null);

  const handleAdded = (d: Driver) => { setDrivers(prev => [d, ...prev]); closeModal(); };
  const handleSaved = (updated: Driver) => { setDrivers(prev => prev.map(d => d.id === updated.id ? updated : d)); closeModal(); };
  const handleRemoved = (id: string) => { setDrivers(prev => prev.map(d => d.id === id ? { ...d, isActive: false } : d)); closeModal(); };
  const handleReactivated = (updated: Driver) => { setDrivers(prev => prev.map(d => d.id === updated.id ? updated : d)); closeModal(); };

  const handleSort = (col: typeof sortBy) => {
    if (sortBy === col) setSortDir(d => d === "asc" ? "desc" : "asc");
    else { setSortBy(col); setSortDir("asc"); }
  };

  // Sort: active first, then by chosen column
  const sorted = [...drivers].sort((a, b) => {
    if (a.isActive !== b.isActive) return a.isActive ? -1 : 1;
    let cmp = 0;
    if (sortBy === "name") cmp = a.name.localeCompare(b.name);
    else if (sortBy === "expiry") {
      const aT = a.licenseExpiry instanceof Date ? a.licenseExpiry.getTime() : 0;
      const bT = b.licenseExpiry instanceof Date ? b.licenseExpiry.getTime() : 0;
      cmp = aT - bT;
    }
    return sortDir === "asc" ? cmp : -cmp;
  });
  const q = searchText.trim().toLowerCase();
  const displayed = (showInactive ? sorted : sorted.filter(d => d.isActive)).filter(d => {
    if (!q) return true;
    return d.name.toLowerCase().includes(q) || d.phone.toLowerCase().includes(q);
  });
  const inactiveCount = drivers.filter(d => !d.isActive).length;

  return (
    <div className="max-w-5xl mx-auto">
      <PageHeader
        title="DRIVERS"
        subtitle="All Drivers"
        breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Drivers" }]}
      />
      <div className="flex flex-col gap-3 mb-4">
        <div className="flex items-center justify-between">
          {/* Show inactive toggle */}
          <button
            onClick={() => setShowInactive(v => !v)}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold tracking-widest uppercase transition-colors ${
              showInactive ? "bg-orange-100 text-orange-600" : "bg-gray-100 text-gray-500 hover:bg-gray-200"
            }`}
          >
            <span className={`w-2 h-2 rounded-full ${showInactive ? "bg-orange-500" : "bg-gray-400"}`} />
            {showInactive ? "Hiding Inactive" : `Show Inactive${inactiveCount > 0 ? ` (${inactiveCount})` : ""}`}
          </button>
          <button
            onClick={() => setModal({ type: "add" })}
            className="px-5 py-2.5 bg-blue-600 text-white text-xs font-bold tracking-widest uppercase rounded-xl hover:bg-blue-700 transition-colors"
          >
            Add Driver
          </button>
        </div>
        <div className="relative">
          <svg className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></svg>
          <input
            type="text"
            placeholder="Search by name or phone…"
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
      ) : displayed.length === 0 ? (
        <div className="text-center py-16 text-gray-400 text-sm">
          {q ? `No drivers match "${searchText}".` : "No drivers yet."}{" "}
          {!q && <button onClick={() => setModal({ type: "add" })} className="text-blue-500 hover:underline">Add one</button>}
          {!q && "."}
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
          {/* Table header */}
          <div className="grid grid-cols-[2fr_1fr_1fr_100px_100px_100px] px-5 py-3 border-b border-gray-100">
            {(
              [
                { label: "Driver",      col: "name" as const },
                { label: "Phone",       col: null },
                { label: "Lic. Expiry", col: "expiry" as const },
                { label: "Status",      col: null },
                { label: "",            col: null },
                { label: "",            col: null },
              ] as { label: string; col: typeof sortBy | null }[]
            ).map(({ label, col }, i) =>
              col ? (
                <button key={i} onClick={() => handleSort(col)}
                  className="flex items-center gap-1 text-xs font-bold tracking-widests text-gray-900 uppercase hover:text-blue-600 transition-colors text-left">
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
            {displayed.map(driver => {
              const revealed = revealedId === driver.id;
              return (
                <div
                  key={driver.id}
                  onClick={() => handleRowClick(driver.id)}
                  className={`grid grid-cols-[2fr_1fr_1fr_100px_100px_100px] items-center px-5 py-3.5 cursor-pointer transition-colors ${
                    !driver.isActive ? "opacity-60" : ""
                  } ${revealed ? "bg-blue-50/40" : "hover:bg-gray-50"}`}
                >
                  {/* Name + address sub-line */}
                  <div className="flex items-center gap-3 min-w-0">
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 ${driver.isActive ? "bg-blue-100 text-blue-700" : "bg-gray-100 text-gray-400"}`}>
                      {driver.name.charAt(0)}
                    </div>
                    <div className="min-w-0">
                      <div className="text-xs font-bold tracking-widest uppercase text-gray-900 truncate">{driver.name}</div>
                      <div className="text-xs text-gray-400 tracking-wide truncate">
                        {revealed ? driver.address : redact(driver.address)}
                      </div>
                    </div>
                  </div>
                  {/* Phone */}
                  <span className="text-xs font-bold tracking-widest text-gray-600">
                    {revealed ? driver.phone : redact(driver.phone)}
                  </span>
                  {/* License expiry */}
                  <span className="text-xs font-bold tracking-widest text-gray-600">
                    {driver.licenseExpiry instanceof Date ? driver.licenseExpiry.toLocaleDateString("en-AU") : "—"}
                  </span>
                  {/* Status badge */}
                  <div>
                    <span className={`text-xs font-bold tracking-widest uppercase px-2 py-1 rounded-full ${
                      driver.isActive ? "bg-green-100 text-green-600" : "bg-orange-100 text-orange-500"
                    }`}>
                      {driver.isActive ? "Active" : "Inactive"}
                    </span>
                  </div>
                  {/* Preview */}
                  <div onClick={e => e.stopPropagation()}>
                    <button
                      onClick={() => setModal({ type: "preview", driver })}
                      className="px-4 py-2 bg-blue-50 text-blue-600 text-xs font-bold rounded-lg hover:bg-blue-100 transition-colors"
                    >
                      Preview
                    </button>
                  </div>
                  {/* Remove / Reactivate */}
                  <div onClick={e => e.stopPropagation()}>
                    {driver.isActive ? (
                      <button
                        onClick={() => setModal({ type: "remove", driver })}
                        className="px-4 py-2 bg-red-50 text-red-600 text-xs font-bold rounded-lg hover:bg-red-100 transition-colors"
                      >
                        Remove
                      </button>
                    ) : (
                      <button
                        onClick={() => setModal({ type: "reactivate", driver })}
                        className="px-4 py-2 bg-green-50 text-green-700 text-xs font-bold rounded-lg hover:bg-green-100 transition-colors"
                      >
                        Reactivate
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {modal?.type === "add" && <AddDriverModal onClose={closeModal} onAdded={handleAdded} />}
      {modal?.type === "preview" && (
        <PreviewModal
          driver={modal.driver}
          onClose={closeModal}
          onEdit={() => setModal({ type: "edit", driver: modal.driver })}
        />
      )}
      {modal?.type === "edit" && (
        <EditDriverModal driver={modal.driver} onClose={closeModal} onSaved={handleSaved} />
      )}
      {modal?.type === "remove" && (
        <RemoveDriverModal driver={modal.driver} onClose={closeModal} onRemoved={handleRemoved} user={user} />
      )}
      {modal?.type === "reactivate" && (
        <ReactivateDriverModal driver={modal.driver} onClose={closeModal} onReactivated={handleReactivated} user={user} />
      )}
    </div>
  );
}

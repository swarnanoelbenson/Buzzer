"use client";
import { useEffect, useState, useCallback } from "react";
import { collection, getDocs, doc, addDoc, updateDoc, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
import type { Student, Route, ParentContact } from "@/lib/types";
import PageHeader from "@/components/PageHeader";
import PhoneInput, { stripPrefix } from "@/components/PhoneInput";

// ── Helpers ─────────────────────────────────────────────────────────────────

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 transition";
const LABEL = "block text-[10px] font-black tracking-widest text-gray-400 uppercase mb-1.5";

type FormState = {
  name: string; grade: string; stopAddress: string; routeId: string;
  scheduledPickupTime: string; scheduledDropoffTime: string;
  studentPhone: string;
  parents: ParentContact[];
};

const EMPTY_FORM: FormState = {
  name: "", grade: "", stopAddress: "", routeId: "",
  scheduledPickupTime: "", scheduledDropoffTime: "",
  studentPhone: "",
  parents: [{ name: "", phone: "", canAccess: true, relationship: "" }],
};

function studentToForm(s: Student): FormState {
  return {
    name: s.name, grade: s.grade, stopAddress: s.stopAddress,
    routeId: s.routeId ?? "",
    scheduledPickupTime: s.scheduledPickupTime,
    scheduledDropoffTime: s.scheduledDropoffTime,
    studentPhone: "",
    parents: s.parents && s.parents.length > 0
      ? s.parents.map(p => ({ ...p, phone: stripPrefix(p.phone) }))
      : [{ name: "", phone: "", canAccess: true, relationship: "" }],
  };
}

function formChanged(original: FormState, current: FormState): boolean {
  const simpleKeys: (keyof FormState)[] = ["name", "grade", "stopAddress", "routeId", "scheduledPickupTime", "scheduledDropoffTime", "studentPhone"];
  if (simpleKeys.some(k => original[k] !== current[k])) return true;
  if (original.parents.length !== current.parents.length) return true;
  return original.parents.some((p, i) =>
    p.name !== current.parents[i].name ||
    p.phone !== current.parents[i].phone ||
    p.canAccess !== current.parents[i].canAccess ||
    p.relationship !== current.parents[i].relationship
  );
}

const DIFF_FIELDS: { key: keyof Omit<FormState, "parents">; label: string }[] = [
  { key: "name",                 label: "Full Name" },
  { key: "grade",                label: "Grade" },
  { key: "stopAddress",          label: "Stop Address" },
  { key: "routeId",              label: "Route" },
  { key: "scheduledPickupTime",  label: "Pick-up Time" },
  { key: "scheduledDropoffTime", label: "Drop-off Time" },
];

// ── Overlay ──────────────────────────────────────────────────────────────────

function Overlay({ children }: { children: React.ReactNode }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
      {children}
    </div>
  );
}

// ── Preview Modal ─────────────────────────────────────────────────────────────

function PreviewModal({ student, onClose, onEdit }: { student: Student; onClose: () => void; onEdit: () => void }) {
  const fields = [
    { label: "Grade",        value: student.grade },
    { label: "Stop Address", value: student.stopAddress },
    { label: "Pick-up",      value: student.scheduledPickupTime },
    { label: "Drop-off",     value: student.scheduledDropoffTime },
    { label: "Status",       value: student.isActive ? "Active" : "Inactive" },
  ];
  return (
    <Overlay>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[90vh] flex flex-col">
        <div className="px-6 py-5 border-b border-gray-100 flex items-center gap-4 flex-shrink-0">
          <div className="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center text-green-700 text-lg font-black">
            {student.name.charAt(0)}
          </div>
          <div>
            <div className="text-base font-black text-gray-900">{student.name}</div>
            <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${student.isActive ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500"}`}>
              {student.isActive ? "Active" : "Inactive"}
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
          {/* Parents section */}
          {student.parents && student.parents.length > 0 && (
            <div className="pt-2 border-t border-gray-100">
              <p className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-3">Parents / Guardians</p>
              <div className="space-y-2">
                {student.parents.map((p, i) => (
                  <div key={i} className="flex items-center justify-between bg-gray-50 rounded-xl px-3 py-2.5">
                    <div>
                      <div className="text-sm font-bold text-gray-900">{p.name || "—"}</div>
                      <div className="text-xs text-gray-500">{p.phone || "—"}</div>
                    </div>
                    <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${p.canAccess ? "bg-green-100 text-green-700" : "bg-red-50 text-red-500"}`}>
                      {p.canAccess ? "Access Granted" : "Access Denied"}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
        <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
          <button onClick={onClose} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Close</button>
          <button onClick={onEdit} className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 transition-colors">Edit Student</button>
        </div>
      </div>
    </Overlay>
  );
}

// ── Student Form ──────────────────────────────────────────────────────────────

function StudentForm({ form, onChange, onParentChange, onAddParent, onRemoveParent, routes, showParents }: {
  form: FormState;
  onChange: (key: keyof Omit<FormState, "parents">, val: string) => void;
  onParentChange: (index: number, field: keyof ParentContact, val: string | boolean) => void;
  onAddParent: () => void;
  onRemoveParent: (index: number) => void;
  routes: Route[];
  showParents: boolean;
}) {
  const set = (key: keyof Omit<FormState, "parents">) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => onChange(key, e.target.value);
  return (
    <div className="grid grid-cols-2 gap-4">
      <div className="col-span-2">
        <label className={LABEL}>Full Name</label>
        <input className={FIELD} required value={form.name} onChange={set("name")} placeholder="e.g. Liam Chen" />
      </div>
      <div>
        <label className={LABEL}>Grade</label>
        <input className={FIELD} required value={form.grade} onChange={set("grade")} placeholder="Year 5" />
      </div>
      <div>
        <label className={LABEL}>Student Phone</label>
        <PhoneInput className={FIELD} value={form.studentPhone} onChange={v => onChange("studentPhone", v)} />
      </div>

      {/* Student app login info */}
      <div className="col-span-2 border-t border-gray-100 pt-3">
        <div className="bg-indigo-50/60 rounded-xl px-3 py-2.5 flex items-start gap-2">
          <svg className="w-3.5 h-3.5 text-indigo-400 mt-0.5 flex-shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12 19.79 19.79 0 0 1 1.61 3.41 2 2 0 0 1 3.6 1.22h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L7.91 8.91a16 16 0 0 0 6.16 6.16l.96-.96a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
          <p className="text-[10px] text-indigo-600 font-bold leading-relaxed">
            Student logs in with their phone number via SMS OTP. An SMS will be sent to the student when their profile is saved.
          </p>
        </div>
      </div>
      <div className="col-span-2">
        <label className={LABEL}>Stop Address</label>
        <input className={FIELD} required value={form.stopAddress} onChange={set("stopAddress")} placeholder="12 Oak St, Parramatta NSW 2150" />
      </div>
      <div className="col-span-2">
        <label className={LABEL}>Assigned Route</label>
        <select className={FIELD} value={form.routeId} onChange={set("routeId")}>
          <option value="">— select a route —</option>
          {routes.map(r => <option key={r.id} value={r.id}>{r.name}</option>)}
        </select>
      </div>
      <div>
        <label className={LABEL}>Scheduled Pick-up Time</label>
        <input className={FIELD} required value={form.scheduledPickupTime} onChange={set("scheduledPickupTime")} placeholder="08:00 AM" />
      </div>
      <div>
        <label className={LABEL}>Scheduled Drop-off Time</label>
        <input className={FIELD} required value={form.scheduledDropoffTime} onChange={set("scheduledDropoffTime")} placeholder="03:30 PM" />
      </div>

      {/* Parents / Guardians */}
      <div className="col-span-2 border-t border-gray-100 pt-3">
        <div className="flex items-center justify-between mb-3">
          <p className="text-[10px] font-black tracking-widest text-gray-400 uppercase">Parents / Guardians</p>
          {showParents && (
            <button
              type="button"
              onClick={onAddParent}
              className="text-[10px] font-black tracking-widest text-blue-600 hover:text-blue-800 uppercase"
            >
              + Add Parent
            </button>
          )}
        </div>
        <div className="space-y-3">
          {form.parents.map((parent, i) => (
            <div key={i} className="bg-gray-50 rounded-xl p-3 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-[10px] font-black tracking-widest text-gray-400 uppercase">
                  {i === 0 ? "Primary Guardian" : `Guardian ${i + 1}`}
                </span>
                {i > 0 && (
                  <button
                    type="button"
                    onClick={() => onRemoveParent(i)}
                    className="text-[10px] font-black tracking-widest text-red-400 hover:text-red-600 uppercase"
                  >
                    Remove
                  </button>
                )}
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className={LABEL}>Name</label>
                  <input
                    className={FIELD}
                    value={parent.name}
                    onChange={e => onParentChange(i, "name", e.target.value)}
                    placeholder="Emma Chen"
                  />
                </div>
                <div>
                  <label className={LABEL}>Phone</label>
                  <PhoneInput
                    className={FIELD}
                    value={parent.phone}
                    onChange={v => onParentChange(i, "phone", v)}
                  />
                </div>
                <div className="col-span-2">
                  <label className={LABEL}>Relationship</label>
                  <select
                    className={FIELD}
                    value={parent.relationship ?? ""}
                    onChange={e => onParentChange(i, "relationship", e.target.value)}
                  >
                    <option value="">— select —</option>
                    <option>Mother</option>
                    <option>Father</option>
                    <option>Step Mother</option>
                    <option>Step Father</option>
                    <option>Guardian</option>
                  </select>
                </div>
              </div>
              {/* Access toggle */}
              <div className="flex items-center justify-between pt-1">
                <span className="text-[10px] font-black tracking-widests text-gray-500 uppercase">App Access</span>
                <button
                  type="button"
                  onClick={() => onParentChange(i, "canAccess", !parent.canAccess)}
                  className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${parent.canAccess ? "bg-green-500" : "bg-gray-300"}`}
                >
                  <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform ${parent.canAccess ? "translate-x-4" : "translate-x-1"}`} />
                </button>
                <span className={`text-[10px] font-black ml-2 ${parent.canAccess ? "text-green-600" : "text-gray-400"}`}>
                  {parent.canAccess ? "Granted" : "Denied"}
                </span>
              </div>
              {/* Parent app login info */}
              {parent.canAccess && (
                <div className="bg-orange-50/60 rounded-xl px-2.5 py-2 flex items-start gap-2 mt-1">
                  <svg className="w-3 h-3 text-orange-400 mt-0.5 flex-shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12 19.79 19.79 0 0 1 1.61 3.41 2 2 0 0 1 3.6 1.22h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L7.91 8.91a16 16 0 0 0 6.16 6.16l.96-.96a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
                  <p className="text-[10px] text-orange-600 font-bold leading-relaxed">
                    Parent logs in with their phone number via SMS OTP. An SMS will be sent to this parent when the profile is saved.
                  </p>
                </div>
              )}
            </div>
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
  original: FormState; updated: FormState;
  onConfirm: () => void; onBack: () => void; saving: boolean;
}) {
  const changed = DIFF_FIELDS.filter(f => original[f.key] !== updated[f.key]);
  // Check parent changes too
  const parentsChanged = JSON.stringify(original.parents) !== JSON.stringify(updated.parents);
  const hasChanges = changed.length > 0 || parentsChanged;

  return (
    <Overlay>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col">
        <div className="px-6 py-5 border-b border-gray-100 flex-shrink-0">
          <h3 className="text-base font-black text-gray-900">Confirm Changes</h3>
          <p className="text-xs text-gray-400 mt-0.5">Review what will be updated before saving.</p>
        </div>
        <div className="overflow-y-auto flex-1 px-6 py-4">
          {!hasChanges ? (
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
              {parentsChanged && (
                <div className="py-1.5 border-b border-gray-50">
                  <span className="text-[11px] font-black text-gray-500 uppercase tracking-wide block mb-2">Parents / Guardians</span>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-1.5">Before</div>
                      {original.parents.map((p, i) => (
                        <div key={i} className="text-xs text-gray-400 line-through">{p.name || "—"} · {p.canAccess ? "Access" : "No access"}</div>
                      ))}
                    </div>
                    <div>
                      <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-1.5">After</div>
                      {updated.parents.map((p, i) => (
                        <div key={i} className="text-xs font-bold text-gray-900">{p.name || "—"} · {p.canAccess ? "Access" : "No access"}</div>
                      ))}
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
        <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
          <button onClick={onBack} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Back</button>
          <button onClick={onConfirm} disabled={saving || !hasChanges}
            className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors">
            {saving ? "Saving..." : "Confirm Save"}
          </button>
        </div>
      </div>
    </Overlay>
  );
}

// ── Shared form state helpers ─────────────────────────────────────────────────

function useStudentForm(initial: FormState) {
  const [form, setForm] = useState<FormState>(initial);

  const onChange = (key: keyof Omit<FormState, "parents">, val: string) =>
    setForm(f => ({ ...f, [key]: val }));

  const onParentChange = (index: number, field: keyof ParentContact, val: string | boolean) =>
    setForm(f => ({
      ...f,
      parents: f.parents.map((p, i) => i === index ? { ...p, [field]: val } : p),
    }));

  const onAddParent = () =>
    setForm(f => ({ ...f, parents: [...f.parents, { name: "", phone: "", canAccess: true, relationship: "" }] }));

  const onRemoveParent = (index: number) =>
    setForm(f => ({ ...f, parents: f.parents.filter((_, i) => i !== index) }));

  return { form, setForm, onChange, onParentChange, onAddParent, onRemoveParent };
}

// ── Add Student Modal ─────────────────────────────────────────────────────────

function AddStudentModal({ routes, onClose, onAdded }: { routes: Route[]; onClose: () => void; onAdded: (s: Student) => void }) {
  const { form, onChange, onParentChange, onAddParent, onRemoveParent } = useStudentForm(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [showUnsaved, setShowUnsaved] = useState(false);

  const isDirty = formChanged(EMPTY_FORM, form);

  const handleClose = () => {
    if (isDirty) { setShowUnsaved(true); return; }
    onClose();
  };

  const doSave = async () => {
    setSaving(true);
    try {
      const validParents = form.parents.filter(p => p.name.trim());

      // 1. Create the student document first (so we have its ID)
      const ref = await addDoc(collection(db, "students"), {
        name: form.name.trim(), grade: form.grade.trim(),
        stopAddress: form.stopAddress.trim(), routeId: form.routeId,
        scheduledPickupTime: form.scheduledPickupTime,
        scheduledDropoffTime: form.scheduledDropoffTime,
        phone: form.studentPhone.trim() ? `+61${form.studentPhone.trim()}` : "",
        authorisedParentIds: [],
        parents: validParents.map(p => ({ ...p, phone: p.phone.trim() ? `+61${p.phone.trim()}` : "" })),
        isActive: true, createdAt: Timestamp.now(),
      });
      const studentId = ref.id;

      // 2. For each parent with app access, create a /parents/{id} document.
      //    Parents authenticate via phone OTP — phone number is their login credential.
      const authorisedParentIds: string[] = [];
      for (const p of validParents) {
        if (!p.canAccess || !p.name.trim()) continue;
        const parentRef = await addDoc(collection(db, "parents"), {
          name: p.name.trim(),
          relationship: p.relationship ?? "",
          phone: p.phone.trim() ? `+61${p.phone.trim()}` : "",
          fcmToken: null,
          childIds: [studentId],
          isActive: true,
          profileCompleted: false,
          createdAt: Timestamp.now(),
        });
        authorisedParentIds.push(parentRef.id);
      }

      // 3. Write authorisedParentIds back to the student doc
      if (authorisedParentIds.length > 0) {
        await updateDoc(doc(db, "students", studentId), { authorisedParentIds });
      }

      // TODO: Send SMS to student (form.studentPhone) and each parent phone when SMS provider is wired up

      const newStudent: Student = {
        id: studentId, name: form.name.trim(), grade: form.grade.trim(),
        stopAddress: form.stopAddress.trim(), routeId: form.routeId,
        scheduledPickupTime: form.scheduledPickupTime,
        scheduledDropoffTime: form.scheduledDropoffTime,
        parents: validParents,
        authorisedParentIds, isActive: true, createdAt: new Date(),
      };
      onAdded(newStudent);
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
              <h3 className="text-base font-black text-gray-900">Add Student</h3>
              <p className="text-xs text-gray-400 mt-0.5">Fill in all required fields</p>
            </div>
            <button onClick={handleClose} className="text-gray-400 hover:text-gray-600">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
          <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
            <div className="overflow-y-auto flex-1 px-6 py-5">
              <StudentForm
                form={form} onChange={onChange}
                onParentChange={onParentChange} onAddParent={onAddParent} onRemoveParent={onRemoveParent}
                routes={routes} showParents={true}
              />
            </div>
            <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
              <button type="button" onClick={handleClose} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Cancel</button>
              <button type="submit" disabled={saving} className="px-5 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors">
                {saving ? "Saving..." : "Add Student"}
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

// ── Edit Student Modal ────────────────────────────────────────────────────────

function EditStudentModal({ student, routes, onClose, onSaved }: {
  student: Student; routes: Route[]; onClose: () => void; onSaved: (s: Student) => void;
}) {
  const original = studentToForm(student);
  const { form, onChange, onParentChange, onAddParent, onRemoveParent } = useStudentForm(original);
  const [showUnsaved, setShowUnsaved] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [saving, setSaving] = useState(false);

  const isDirty = formChanged(original, form);

  const handleClose = () => {
    if (isDirty) { setShowUnsaved(true); return; }
    onClose();
  };

  const doSave = async () => {
    setSaving(true);
    try {
      const validParents = form.parents.filter(p => p.name.trim()).map(p => ({ ...p, phone: p.phone.trim() ? `+61${p.phone.trim()}` : "" }));
      await updateDoc(doc(db, "students", student.id), {
        name: form.name.trim(), grade: form.grade.trim(),
        stopAddress: form.stopAddress.trim(), routeId: form.routeId,
        scheduledPickupTime: form.scheduledPickupTime,
        scheduledDropoffTime: form.scheduledDropoffTime,
        parents: validParents,
      });
      const updated: Student = {
        ...student, name: form.name.trim(), grade: form.grade.trim(),
        stopAddress: form.stopAddress.trim(), routeId: form.routeId,
        scheduledPickupTime: form.scheduledPickupTime,
        scheduledDropoffTime: form.scheduledDropoffTime,
        parents: validParents,
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
              <h3 className="text-base font-black text-gray-900">Edit — {student.name}</h3>
              <p className="text-xs text-gray-400 mt-0.5">Changes shown for confirmation before saving</p>
            </div>
            <button onClick={handleClose} className="text-gray-400 hover:text-gray-600">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
          <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
            <div className="overflow-y-auto flex-1 px-6 py-5">
              <StudentForm
                form={form} onChange={onChange}
                onParentChange={onParentChange} onAddParent={onAddParent} onRemoveParent={onRemoveParent}
                routes={routes} showParents={true}
              />
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

// ── Remove Student Modal ──────────────────────────────────────────────────────

function RemoveStudentModal({ student, onClose, onRemoved, user }: {
  student: Student; onClose: () => void; onRemoved: (id: string) => void;
  user: { uid?: string; displayName?: string | null; email?: string | null } | null;
}) {
  const [reason, setReason] = useState("");
  const [saving, setSaving] = useState(false);

  const confirmRemove = async () => {
    setSaving(true);
    const now = new Date();
    await updateDoc(doc(db, "students", student.id), { isActive: false });
    await addDoc(collection(db, "adminLog"), {
      type: "remove_student", tag: "REMOVE STUDENT",
      actorId: user?.uid ?? "admin",
      actorName: user?.displayName ?? user?.email ?? "Admin",
      targetId: student.id, targetName: student.name,
      details: `Student removed: ${student.name} (Grade ${student.grade}, Stop: ${student.stopAddress})`,
      reason: reason.trim() || "No reason provided",
      timestamp: Timestamp.now(),
      year: now.getFullYear(),
      term: Math.ceil((now.getMonth() + 1) / 3),
      month: now.getMonth() + 1,
    });
    setSaving(false);
    onRemoved(student.id);
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
            <h3 className="text-base font-black text-gray-900">Remove {student.name}</h3>
            <p className="text-xs text-gray-400">This will deactivate the student and log the action.</p>
          </div>
        </div>
        <div className="bg-gray-50 rounded-xl p-4 mb-4">
          <div className="grid grid-cols-2 gap-4 divide-x divide-gray-200">
            <div>
              <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">Before</div>
              <div className="font-bold text-gray-900 text-sm">{student.name}</div>
              <div className="text-xs text-gray-500">Grade {student.grade}</div>
              <div className="text-xs text-gray-500">{student.stopAddress}</div>
              <span className="inline-block mt-1.5 text-[10px] font-black px-2 py-0.5 rounded-full bg-green-100 text-green-700">Active</span>
            </div>
            <div className="pl-4">
              <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">After</div>
              <div className="font-bold text-gray-900 text-sm">{student.name}</div>
              <div className="text-xs text-gray-500">Grade {student.grade}</div>
              <div className="text-xs text-gray-500">{student.stopAddress}</div>
              <span className="inline-block mt-1.5 text-[10px] font-black px-2 py-0.5 rounded-full bg-gray-100 text-gray-500">Inactive</span>
            </div>
          </div>
        </div>
        <label className={LABEL}>Reason for Removal</label>
        <textarea
          rows={3}
          className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-red-200 focus:border-red-400 transition resize-none"
          placeholder="Why is this student being removed? (saved to admin log)"
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

// ── Reactivate Student Modal ──────────────────────────────────────────────────

function ReactivateStudentModal({ student, routes, onClose, onReactivated, user }: {
  student: Student; routes: Route[]; onClose: () => void; onReactivated: (s: Student) => void;
  user: { uid?: string; displayName?: string | null; email?: string | null } | null;
}) {
  const original = studentToForm(student);
  const { form, onChange, onParentChange, onAddParent, onRemoveParent } = useStudentForm(original);
  const [saving, setSaving] = useState(false);

  const handleReactivate = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    const now = new Date();
    const validParents = form.parents.filter(p => p.name.trim()).map(p => ({ ...p, phone: p.phone.trim() ? `+61${p.phone.trim()}` : "" }));
    await updateDoc(doc(db, "students", student.id), {
      isActive: true,
      name: form.name.trim(), grade: form.grade.trim(),
      stopAddress: form.stopAddress.trim(), routeId: form.routeId,
      scheduledPickupTime: form.scheduledPickupTime,
      scheduledDropoffTime: form.scheduledDropoffTime,
      parents: validParents,
    });
    await addDoc(collection(db, "adminLog"), {
      type: "reactivate_student", tag: "REACTIVATE STUDENT",
      actorId: user?.uid ?? "admin",
      actorName: user?.displayName ?? user?.email ?? "Admin",
      targetId: student.id, targetName: form.name.trim(),
      details: `Student reactivated: ${form.name.trim()} (Grade ${form.grade.trim()})`,
      timestamp: Timestamp.now(),
      year: now.getFullYear(),
      term: Math.ceil((now.getMonth() + 1) / 3),
      month: now.getMonth() + 1,
    });
    const updated: Student = {
      ...student, isActive: true,
      name: form.name.trim(), grade: form.grade.trim(),
      stopAddress: form.stopAddress.trim(), routeId: form.routeId,
      scheduledPickupTime: form.scheduledPickupTime,
      scheduledDropoffTime: form.scheduledDropoffTime,
      parents: validParents, // already has +61 prefix from above
    };
    setSaving(false);
    onReactivated(updated);
  };

  return (
    <Overlay>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col">
        <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
          <div>
            <h3 className="text-base font-black text-gray-900">Reactivate — {student.name}</h3>
            <p className="text-xs text-gray-400 mt-0.5">Review and update details before reactivating</p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <form onSubmit={handleReactivate} className="flex flex-col flex-1 overflow-hidden">
          <div className="overflow-y-auto flex-1 px-6 py-5">
            <StudentForm
              form={form} onChange={onChange}
              onParentChange={onParentChange} onAddParent={onAddParent} onRemoveParent={onRemoveParent}
              routes={routes} showParents={true}
            />
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
  | { type: "preview"; student: Student }
  | { type: "edit"; student: Student }
  | { type: "remove"; student: Student }
  | { type: "reactivate"; student: Student };

// Redact a string by replacing all characters with bullets, preserving length capped at 8
function redact(val: string) {
  if (!val) return "—";
  return "•".repeat(Math.min(val.length, 8));
}

export default function StudentsPage() {
  const { user } = useAuth();
  const [students, setStudents] = useState<Student[]>([]);
  const [routes, setRoutes] = useState<Route[]>([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState<Modal | null>(null);
  const [showInactive, setShowInactive] = useState(false);
  // Track which row is revealed + its auto-hide timer
  const [revealedId, setRevealedId] = useState<string | null>(null);
  const [revealTimer, setRevealTimer] = useState<ReturnType<typeof setTimeout> | null>(null);

  const load = useCallback(() => {
    Promise.all([
      getDocs(collection(db, "students")),
      getDocs(collection(db, "routes")),
    ]).then(([sSnap, rSnap]) => {
      setStudents(sSnap.docs.map(d => ({ id: d.id, ...d.data() } as Student)));
      setRoutes(rSnap.docs.map(d => ({ id: d.id, ...d.data() } as Route)));
      setLoading(false);
    });
  }, []);

  useEffect(() => { load(); }, [load]);

  // Clear timer on unmount
  useEffect(() => { return () => { if (revealTimer) clearTimeout(revealTimer); }; }, [revealTimer]);

  const handleRowClick = (id: string) => {
    if (revealTimer) clearTimeout(revealTimer);
    if (revealedId === id) {
      setRevealedId(null);
      setRevealTimer(null);
      return;
    }
    setRevealedId(id);
    const timer = setTimeout(() => {
      setRevealedId(null);
      setRevealTimer(null);
    }, 5 * 60 * 1000); // 5 minutes
    setRevealTimer(timer);
  };

  const closeModal = () => setModal(null);
  const handleAdded = (s: Student) => { setStudents(prev => [s, ...prev]); closeModal(); };
  const handleSaved = (updated: Student) => { setStudents(prev => prev.map(s => s.id === updated.id ? updated : s)); closeModal(); };
  const handleRemoved = (id: string) => { setStudents(prev => prev.map(s => s.id === id ? { ...s, isActive: false } : s)); closeModal(); };
  const handleReactivated = (updated: Student) => { setStudents(prev => prev.map(s => s.id === updated.id ? updated : s)); closeModal(); };

  // Sort active first, then alphabetically within each group
  const sorted = [...students].sort((a, b) => {
    if (a.isActive === b.isActive) return a.name.localeCompare(b.name);
    return a.isActive ? -1 : 1;
  });
  const inactiveCount = students.filter(s => !s.isActive).length;
  const displayed = showInactive ? sorted : sorted.filter(s => s.isActive);

  return (
    <div className="max-w-5xl mx-auto">
      <PageHeader
        title="STUDENTS"
        subtitle="All Students"
        breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Students" }]}
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
          {showInactive ? "Hide Inactive" : `Show Inactive (${inactiveCount})`}
        </button>
        <button
          onClick={() => setModal({ type: "add" })}
          className="px-5 py-2.5 bg-blue-600 text-white text-xs font-bold tracking-widest uppercase rounded-xl hover:bg-blue-700 transition-colors"
        >
          Add Student
        </button>
      </div>

      {loading ? (
        <p className="text-sm text-gray-300">Loading...</p>
      ) : displayed.length === 0 ? (
        <div className="text-center py-16 text-gray-400 text-sm">
          No students yet.{" "}
          <button onClick={() => setModal({ type: "add" })} className="text-blue-500 hover:underline">Add one</button>.
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
          {/* Table header */}
          <div className="grid grid-cols-[2fr_0.7fr_1.2fr_0.8fr_0.8fr_90px_100px_110px] px-5 py-3 border-b border-gray-100">
            {["Student", "Grade", "Stop Address", "Pick-up", "Drop-off", "Status", "", ""].map((h, i) => (
              <span key={i} className="text-xs font-bold tracking-widest text-gray-900 uppercase">{h}</span>
            ))}
          </div>
          {/* Rows */}
          <div className="divide-y divide-gray-50">
            {displayed.map(student => {
              const revealed = revealedId === student.id;
              const isInactive = !student.isActive;
              return (
                <div
                  key={student.id}
                  onClick={() => handleRowClick(student.id)}
                  className={`grid grid-cols-[2fr_0.7fr_1.2fr_0.8fr_0.8fr_90px_100px_110px] items-center px-5 py-3.5 cursor-pointer transition-colors ${
                    isInactive ? "opacity-60" : ""
                  } ${revealed ? "bg-blue-50/40" : "hover:bg-gray-50"}`}
                >
                  {/* Name */}
                  <div className="flex items-center gap-3 min-w-0">
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 ${
                      isInactive ? "bg-gray-100 text-gray-400" : "bg-green-100 text-green-700"
                    }`}>
                      {student.name.charAt(0)}
                    </div>
                    <div className="min-w-0">
                      <div className="text-xs font-bold tracking-widest uppercase text-gray-900 truncate">{student.name}</div>
                      {revealed && student.parents && student.parents.length > 0 && (
                        <div className="text-[10px] text-gray-400 truncate">
                          {student.parents.map(p => p.name).filter(Boolean).join(", ")}
                        </div>
                      )}
                    </div>
                  </div>
                  {/* Grade */}
                  <span className="text-xs font-bold tracking-widest text-gray-600">{student.grade}</span>
                  {/* Stop Address */}
                  <span className="text-xs font-bold tracking-widest text-gray-600 truncate">
                    {revealed ? student.stopAddress : redact(student.stopAddress)}
                  </span>
                  {/* Pick-up */}
                  <span className="text-xs font-bold tracking-widest text-gray-600">
                    {revealed ? student.scheduledPickupTime : redact(student.scheduledPickupTime)}
                  </span>
                  {/* Drop-off */}
                  <span className="text-xs font-bold tracking-widest text-gray-600">
                    {revealed ? student.scheduledDropoffTime : redact(student.scheduledDropoffTime)}
                  </span>
                  {/* Status */}
                  <div>
                    <span className={`text-xs font-bold tracking-widest uppercase px-2 py-1 rounded-full ${
                      student.isActive ? "bg-green-100 text-green-600" : "bg-gray-100 text-gray-500"
                    }`}>
                      {student.isActive ? "Active" : "Inactive"}
                    </span>
                  </div>
                  {/* Preview */}
                  <div onClick={e => e.stopPropagation()}>
                    <button
                      onClick={() => setModal({ type: "preview", student })}
                      className="px-4 py-2 bg-blue-50 text-blue-600 text-xs font-bold rounded-lg hover:bg-blue-100 transition-colors"
                    >
                      Preview
                    </button>
                  </div>
                  {/* Remove / Reactivate */}
                  <div onClick={e => e.stopPropagation()}>
                    {student.isActive ? (
                      <button
                        onClick={() => setModal({ type: "remove", student })}
                        className="px-4 py-2 bg-red-50 text-red-600 text-xs font-bold rounded-lg hover:bg-red-100 transition-colors"
                      >
                        Remove
                      </button>
                    ) : (
                      <button
                        onClick={() => setModal({ type: "reactivate", student })}
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

      {modal?.type === "add" && <AddStudentModal routes={routes} onClose={closeModal} onAdded={handleAdded} />}
      {modal?.type === "preview" && (
        <PreviewModal
          student={modal.student}
          onClose={closeModal}
          onEdit={() => setModal({ type: "edit", student: modal.student })}
        />
      )}
      {modal?.type === "edit" && (
        <EditStudentModal student={modal.student} routes={routes} onClose={closeModal} onSaved={handleSaved} />
      )}
      {modal?.type === "remove" && (
        <RemoveStudentModal student={modal.student} onClose={closeModal} onRemoved={handleRemoved} user={user} />
      )}
      {modal?.type === "reactivate" && (
        <ReactivateStudentModal student={modal.student} routes={routes} onClose={closeModal} onReactivated={handleReactivated} user={user} />
      )}
    </div>
  );
}

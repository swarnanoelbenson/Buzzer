"use client";
import { useEffect, useState } from "react";
import { collection, getDocs, doc, updateDoc, addDoc, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
import type { Student } from "@/lib/types";
import PageHeader from "@/components/PageHeader";

export default function RemoveStudentPage() {
  const { user } = useAuth();
  const [students, setStudents] = useState<Student[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalStudent, setModalStudent] = useState<Student | null>(null);
  const [reason, setReason] = useState("");
  const [saving, setSaving] = useState(false);
  const [done, setDone] = useState<string[]>([]);

  useEffect(() => {
    getDocs(collection(db, "students")).then(snap => {
      setStudents(snap.docs.map(d => ({ id: d.id, ...d.data() } as Student)));
      setLoading(false);
    });
  }, []);

  const openModal = (s: Student) => { setModalStudent(s); setReason(""); };
  const closeModal = () => { setModalStudent(null); setReason(""); };

  const confirmRemove = async () => {
    if (!modalStudent) return;
    setSaving(true);
    const now = new Date();
    await updateDoc(doc(db, "students", modalStudent.id), { isActive: false });
    await addDoc(collection(db, "adminLog"), {
      type: "remove_student",
      tag: "REMOVE STUDENT",
      actorId: user?.uid ?? "admin",
      actorName: user?.displayName ?? user?.email ?? "Admin",
      targetId: modalStudent.id,
      targetName: modalStudent.name,
      details: `Student removed: ${modalStudent.name} (Grade ${modalStudent.grade}, Stop: ${modalStudent.stopAddress})`,
      reason: reason.trim() || "No reason provided",
      timestamp: Timestamp.now(),
      year: now.getFullYear(),
      term: Math.ceil((now.getMonth() + 1) / 3),
      month: now.getMonth() + 1,
    });
    setDone(p => [...p, modalStudent.id]);
    setSaving(false);
    closeModal();
  };

  const active = students.filter(s => s.isActive && !done.includes(s.id));

  return (
    <div className="max-w-2xl mx-auto">
      <PageHeader
        title="STUDENTS" subtitle="Remove Student"
        breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Students", href: "/students" }, { label: "Remove" }]}
        accent="green"
      />
      <p className="text-sm text-gray-500 mb-6">Students are deactivated to preserve trip history.</p>

      {loading ? <p className="text-sm text-gray-300">Loading...</p> : (
        <div className="space-y-3">
          {active.map(s => (
            <div key={s.id} className="bg-white rounded-2xl border border-gray-100 px-5 py-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-green-100 flex items-center justify-center text-green-700 text-sm font-bold">{s.name.charAt(0)}</div>
                <div>
                  <div className="text-sm font-bold text-gray-900">{s.name}</div>
                  <div className="text-xs text-gray-400">Grade {s.grade} · {s.stopAddress}</div>
                </div>
              </div>
              <button onClick={() => openModal(s)} className="px-4 py-2 bg-red-50 text-red-600 text-sm font-bold rounded-lg hover:bg-red-100 transition-colors">
                Remove
              </button>
            </div>
          ))}
          {active.length === 0 && <p className="text-sm text-gray-400 text-center py-8">No active students to remove.</p>}
        </div>
      )}

      {/* Remove modal */}
      {modalStudent && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 p-6">
            <div className="flex items-center gap-3 mb-5">
              <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ef4444" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/>
                </svg>
              </div>
              <div>
                <h3 className="text-base font-black text-gray-900">Remove {modalStudent.name}</h3>
                <p className="text-xs text-gray-400">This will deactivate the student and log the action.</p>
              </div>
            </div>

            {/* Before / After */}
            <div className="bg-gray-50 rounded-xl p-4 mb-4">
              <div className="grid grid-cols-2 gap-4 divide-x divide-gray-200">
                <div>
                  <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">Before</div>
                  <div className="font-bold text-gray-900 text-sm">{modalStudent.name}</div>
                  <div className="text-xs text-gray-500">Grade {modalStudent.grade}</div>
                  <div className="text-xs text-gray-500">{modalStudent.stopAddress}</div>
                  <div className="text-xs text-gray-500">Pickup: {modalStudent.scheduledPickupTime}</div>
                  <span className="inline-block mt-1.5 text-[10px] font-black px-2 py-0.5 rounded-full bg-green-100 text-green-700">Active</span>
                </div>
                <div className="pl-4">
                  <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">After</div>
                  <div className="font-bold text-gray-900 text-sm">{modalStudent.name}</div>
                  <div className="text-xs text-gray-500">Grade {modalStudent.grade}</div>
                  <div className="text-xs text-gray-500">{modalStudent.stopAddress}</div>
                  <div className="text-xs text-gray-500">Pickup: {modalStudent.scheduledPickupTime}</div>
                  <span className="inline-block mt-1.5 text-[10px] font-black px-2 py-0.5 rounded-full bg-gray-100 text-gray-500">Inactive</span>
                </div>
              </div>
            </div>

            <label className="block text-xs font-black tracking-widest text-gray-500 uppercase mb-1.5">Reason for Removal</label>
            <textarea
              rows={3}
              className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-red-200 focus:border-red-400 transition resize-none"
              placeholder="Why is this student being removed? (saved to admin log)"
              value={reason}
              onChange={e => setReason(e.target.value)}
            />

            <div className="flex justify-end gap-3 mt-4">
              <button onClick={closeModal} className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700">Cancel</button>
              <button onClick={confirmRemove} disabled={saving}
                className="px-5 py-2.5 bg-red-500 text-white text-sm font-black rounded-xl hover:bg-red-600 disabled:opacity-50 transition-colors">
                {saving ? "Removing..." : "Confirm Remove"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

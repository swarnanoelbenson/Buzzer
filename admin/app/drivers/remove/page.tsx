"use client";
import { useEffect, useState } from "react";
import { collection, getDocs, doc, updateDoc, addDoc, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
import type { Driver } from "@/lib/types";
import PageHeader from "@/components/PageHeader";

export default function RemoveDriverPage() {
  const { user } = useAuth();
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalDriver, setModalDriver] = useState<Driver | null>(null);
  const [reason, setReason] = useState("");
  const [saving, setSaving] = useState(false);
  const [done, setDone] = useState<string[]>([]);

  useEffect(() => {
    getDocs(collection(db, "drivers")).then(snap => {
      setDrivers(snap.docs.map(d => ({ id: d.id, ...d.data() } as Driver)));
      setLoading(false);
    });
  }, []);

  const openModal = (driver: Driver) => { setModalDriver(driver); setReason(""); };
  const closeModal = () => { setModalDriver(null); setReason(""); };

  const confirmRemove = async () => {
    if (!modalDriver) return;
    setSaving(true);
    const now = new Date();
    await updateDoc(doc(db, "drivers", modalDriver.id), { isActive: false });
    await addDoc(collection(db, "adminLog"), {
      type: "remove_driver",
      tag: "REMOVE DRIVER",
      actorId: user?.uid ?? "admin",
      actorName: user?.displayName ?? user?.email ?? "Admin",
      targetId: modalDriver.id,
      targetName: modalDriver.name,
      details: `Driver removed: ${modalDriver.name} (${modalDriver.phone}, Bus: ${modalDriver.busRegistration})`,
      reason: reason.trim() || "No reason provided",
      timestamp: Timestamp.now(),
      year: now.getFullYear(),
      term: Math.ceil((now.getMonth() + 1) / 3),
      month: now.getMonth() + 1,
    });
    setDone(prev => [...prev, modalDriver.id]);
    setSaving(false);
    closeModal();
  };

  const active = drivers.filter(d => d.isActive && !done.includes(d.id));

  return (
    <div className="max-w-2xl mx-auto">
      <PageHeader
        title="DRIVERS" subtitle="Remove Driver"
        breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Drivers", href: "/drivers" }, { label: "Remove" }]}
        accent="blue"
      />
      <p className="text-sm text-gray-500 mb-6">Drivers are deactivated rather than permanently deleted, preserving historical trip records.</p>

      {loading ? <p className="text-sm text-gray-300">Loading...</p> : (
        <div className="space-y-3">
          {active.map(driver => (
            <div key={driver.id} className="bg-white rounded-2xl border border-gray-100 px-5 py-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 text-sm font-bold">
                  {driver.name.charAt(0)}
                </div>
                <div>
                  <div className="text-sm font-bold text-gray-900">{driver.name}</div>
                  <div className="text-xs text-gray-400">{driver.phone} · {driver.busRegistration}</div>
                </div>
              </div>
              <button onClick={() => openModal(driver)} className="px-4 py-2 bg-red-50 text-red-600 text-sm font-bold rounded-lg hover:bg-red-100 transition-colors">
                Remove
              </button>
            </div>
          ))}
          {active.length === 0 && <p className="text-sm text-gray-400 text-center py-8">No active drivers to remove.</p>}
        </div>
      )}

      {/* Remove modal */}
      {modalDriver && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 p-6">
            <div className="flex items-center gap-3 mb-5">
              <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ef4444" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/>
                </svg>
              </div>
              <div>
                <h3 className="text-base font-black text-gray-900">Remove {modalDriver.name}</h3>
                <p className="text-xs text-gray-400">This will deactivate the driver and log the action.</p>
              </div>
            </div>

            {/* Before / After comparison */}
            <div className="bg-gray-50 rounded-xl p-4 mb-4">
              <div className="grid grid-cols-2 gap-4 divide-x divide-gray-200">
                <div>
                  <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">Before</div>
                  <div className="font-bold text-gray-900 text-sm">{modalDriver.name}</div>
                  <div className="text-xs text-gray-500">{modalDriver.phone}</div>
                  <div className="text-xs text-gray-500">{modalDriver.busRegistration}</div>
                  <span className="inline-block mt-1.5 text-[10px] font-black px-2 py-0.5 rounded-full bg-green-100 text-green-700">Active</span>
                </div>
                <div className="pl-4">
                  <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">After</div>
                  <div className="font-bold text-gray-900 text-sm">{modalDriver.name}</div>
                  <div className="text-xs text-gray-500">{modalDriver.phone}</div>
                  <div className="text-xs text-gray-500">{modalDriver.busRegistration}</div>
                  <span className="inline-block mt-1.5 text-[10px] font-black px-2 py-0.5 rounded-full bg-gray-100 text-gray-500">Inactive</span>
                </div>
              </div>
            </div>

            <label className="block text-xs font-black tracking-widest text-gray-500 uppercase mb-1.5">Reason for Removal</label>
            <textarea
              rows={3}
              className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-red-200 focus:border-red-400 transition resize-none"
              placeholder="Why is this driver being removed? (saved to admin log)"
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

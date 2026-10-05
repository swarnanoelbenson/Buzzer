"use client";
import { useEffect, useState } from "react";
import { collection, getDocs, doc, updateDoc, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Route } from "@/lib/types";
import PageHeader from "@/components/PageHeader";

function toDate(v: unknown): Date {
  if (!v) return new Date();
  if (v instanceof Date) return v;
  if (typeof (v as Timestamp).toDate === "function") return (v as Timestamp).toDate();
  return new Date();
}

export default function RemoveSchedulePage() {
  const [routes, setRoutes] = useState<Route[]>([]);
  const [loading, setLoading] = useState(true);
  const [confirming, setConfirming] = useState<string | null>(null);
  const [done, setDone] = useState<string[]>([]);

  useEffect(() => {
    getDocs(collection(db, "routes")).then(snap => {
      setRoutes(snap.docs.map(d => ({ id: d.id, ...d.data(), startDate: toDate(d.data().startDate), endDate: toDate(d.data().endDate) } as Route)));
      setLoading(false);
    });
  }, []);

  const deactivate = async (id: string) => {
    await updateDoc(doc(db, "routes", id), { isActive: false });
    setDone(p => [...p, id]);
    setConfirming(null);
  };

  const active = routes.filter(r => r.isActive && !done.includes(r.id));

  return (
    <div className="max-w-2xl mx-auto">
      <PageHeader title="SCHEDULE" subtitle="Remove Schedule" breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "Schedule", href: "/schedule" }, { label: "Remove" }]} accent="orange" />
      <p className="text-sm text-gray-400 mb-6">Routes are deactivated to preserve completed trip history.</p>

      {loading ? <p className="text-sm text-gray-300">Loading...</p> : (
        <div className="space-y-3">
          {active.map(r => (
            <div key={r.id} className="bg-white rounded-2xl border border-gray-100 px-5 py-4 flex items-center justify-between">
              <div>
                <div className="text-sm font-medium text-gray-900">{r.name}</div>
                <div className="text-xs text-gray-400 mt-0.5">
                  Term {r.term} · {r.year} · {r.studentIds?.length ?? 0} students
                </div>
              </div>
              {confirming === r.id ? (
                <div className="flex items-center gap-2">
                  <span className="text-xs text-gray-500">Confirm?</span>
                  <button onClick={() => deactivate(r.id)} className="px-4 py-2 bg-red-500 text-white text-sm font-semibold rounded-lg hover:bg-red-600">Yes, remove</button>
                  <button onClick={() => setConfirming(null)} className="px-4 py-2 bg-gray-100 text-gray-600 text-sm font-medium rounded-lg hover:bg-gray-200">Cancel</button>
                </div>
              ) : (
                <button onClick={() => setConfirming(r.id)} className="px-4 py-2 bg-red-50 text-red-600 text-sm font-semibold rounded-lg hover:bg-red-100 transition-colors">Remove</button>
              )}
            </div>
          ))}
          {active.length === 0 && <p className="text-sm text-gray-400 text-center py-8">No active schedules to remove.</p>}
        </div>
      )}
    </div>
  );
}

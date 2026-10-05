"use client";
import { useEffect, useState } from "react";
import { collection, getDocs, query, orderBy, limit, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { ActivityLog } from "@/lib/types";
import PageHeader from "@/components/PageHeader";

function toDate(v: unknown): Date {
  if (!v) return new Date();
  if (v instanceof Date) return v;
  if (typeof (v as Timestamp).toDate === "function") return (v as Timestamp).toDate();
  return new Date();
}

export default function ActivityPage() {
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<"all" | "driver" | "parent">("all");

  useEffect(() => {
    getDocs(query(collection(db, "activityLog"), orderBy("timestamp", "desc"), limit(200))).then(snap => {
      setLogs(snap.docs.map(d => ({ id: d.id, ...d.data(), timestamp: toDate(d.data().timestamp) } as ActivityLog)));
      setLoading(false);
    });
  }, []);

  const filtered = filter === "all" ? logs : logs.filter(l => l.actorRole === filter);

  return (
    <div className="max-w-5xl mx-auto">
      <div className="flex items-start justify-between mb-8">
        <PageHeader title="VIEW LOG" subtitle="Activity Log" breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "View Log" }]} accent="purple" />
        <div className="flex gap-2 mt-1">
          {(["all", "driver", "parent"] as const).map(f => (
            <button key={f} onClick={() => setFilter(f)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors capitalize ${
                filter === f ? "bg-purple-600 text-white" : "bg-white border border-gray-200 text-gray-600 hover:bg-gray-50"
              }`}>
              {f === "all" ? "All" : f === "driver" ? "Drivers" : "Parents"}
            </button>
          ))}
        </div>
      </div>

      {loading ? <p className="text-sm text-gray-300">Loading...</p> : filtered.length === 0 ? (
        <div className="text-center py-16 text-gray-400 text-sm">No activity recorded yet.</div>
      ) : (
        <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
          <table className="w-full text-base">
            <thead>
              <tr className="text-xs font-semibold text-gray-400 uppercase tracking-wide border-b border-gray-100">
                <th className="px-6 py-3.5 text-left">Date & Time</th>
                <th className="px-6 py-3.5 text-left">Actor</th>
                <th className="px-6 py-3.5 text-left">Role</th>
                <th className="px-6 py-3.5 text-left">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filtered.map(log => (
                <tr key={log.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 text-gray-400 text-xs whitespace-nowrap">
                    {log.timestamp instanceof Date ? (
                      <>
                        <div className="font-medium text-gray-600">{log.timestamp.toLocaleDateString("en-AU", { day: "numeric", month: "short", year: "numeric" })}</div>
                        <div>{log.timestamp.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</div>
                      </>
                    ) : "—"}
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-2.5">
                      <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-semibold ${
                        log.actorRole === "driver" ? "bg-blue-100 text-blue-700" : "bg-purple-100 text-purple-700"
                      }`}>
                        {log.actorName?.charAt(0) ?? "?"}
                      </div>
                      <span className="font-medium text-gray-900">{log.actorName}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`text-xs font-medium px-2.5 py-1 rounded-full ${
                      log.actorRole === "driver" ? "bg-blue-100 text-blue-700" : "bg-purple-100 text-purple-700"
                    }`}>
                      {log.actorRole}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-gray-600">{log.action}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

"use client";
import { useEffect, useState } from "react";
import { collection, getDocs, query, where, orderBy, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import PageHeader from "@/components/PageHeader";

interface DriverLog {
  id: string;
  action: string;
  tag?: string;
  actorName: string;
  actorId?: string;
  driverName?: string;
  routeName?: string;
  studentName?: string;
  details?: string;
  timestamp: Date;
  year: number;
  term?: number;
  month?: number;
}

function toDate(v: unknown): Date {
  if (!v) return new Date();
  if (v instanceof Date) return v;
  if (typeof (v as Timestamp).toDate === "function") return (v as Timestamp).toDate();
  return new Date();
}

const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
const TERM_MONTHS: Record<number, number[]> = { 1: [1,2,3], 2: [4,5,6], 3: [7,8,9], 4: [10,11,12] };

export default function DriverLogPage() {
  const [logs, setLogs] = useState<DriverLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [years, setYears] = useState<number[]>([]);
  const [selYear, setSelYear] = useState<number | null>(null);
  const [selTerm, setSelTerm] = useState<number | null>(null);
  const [selMonth, setSelMonth] = useState<number | null>(null);

  useEffect(() => {
    getDocs(query(collection(db, "activityLog"), where("actorRole", "==", "driver"), orderBy("timestamp", "desc"))).then(snap => {
      const items = snap.docs.map(d => ({
        id: d.id, ...d.data(),
        timestamp: toDate(d.data().timestamp),
        year: d.data().year ?? new Date(toDate(d.data().timestamp)).getFullYear(),
        term: d.data().term,
        month: d.data().month ?? (new Date(toDate(d.data().timestamp)).getMonth() + 1),
      } as DriverLog));
      setLogs(items);
      const ys = [...new Set(items.map(l => l.year))].sort((a, b) => b - a);
      setYears(ys);
      if (ys.length > 0) setSelYear(ys[0]);
      setLoading(false);
    });
  }, []);

  const yearLogs = logs.filter(l => l.year === selYear);
  const termLogs = selTerm ? yearLogs.filter(l => TERM_MONTHS[selTerm].includes(l.month ?? 0)) : yearLogs;
  const monthLogs = selMonth ? termLogs.filter(l => l.month === selMonth) : termLogs;

  const availableTerms = selYear ? [...new Set(yearLogs.map(l => Math.ceil((l.month ?? 1) / 3)))].sort() : [];
  const availableMonths = selTerm ? TERM_MONTHS[selTerm].filter(m => termLogs.some(l => l.month === m)) : [];

  const tagColors: Record<string, string> = {
    login: "bg-blue-100 text-blue-700",
    logout: "bg-gray-100 text-gray-600",
    pickup: "bg-green-100 text-green-700",
    dropoff: "bg-orange-100 text-orange-700",
    modified: "bg-purple-100 text-purple-700",
  };

  function getTagColor(tag?: string) {
    const t = (tag ?? "").toLowerCase();
    for (const [k, v] of Object.entries(tagColors)) { if (t.includes(k)) return v; }
    return "bg-gray-100 text-gray-600";
  }

  return (
    <div className="max-w-5xl mx-auto">
      <PageHeader title="VIEW LOG" subtitle="Driver Log"
        breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "View Log" }, { label: "Driver Log" }]} accent="blue" />

      {/* Filter bar */}
      <div className="flex flex-wrap gap-3 mb-6">
        {/* Year */}
        <div className="flex gap-1.5 flex-wrap">
          {years.map(y => (
            <button key={y} onClick={() => { setSelYear(y); setSelTerm(null); setSelMonth(null); }}
              className={`px-3 py-1.5 rounded-lg text-xs font-black tracking-wide transition-colors ${selYear === y ? "bg-blue-600 text-white" : "bg-white border border-gray-200 text-gray-700 hover:bg-gray-50"}`}>
              {y}
            </button>
          ))}
        </div>

        {/* Term */}
        {availableTerms.length > 0 && (
          <div className="flex gap-1.5">
            {availableTerms.map(t => (
              <button key={t} onClick={() => { setSelTerm(selTerm === t ? null : t); setSelMonth(null); }}
                className={`px-3 py-1.5 rounded-lg text-xs font-black tracking-wide transition-colors ${selTerm === t ? "bg-blue-600 text-white" : "bg-white border border-gray-200 text-gray-700 hover:bg-gray-50"}`}>
                Term {t}
              </button>
            ))}
          </div>
        )}

        {/* Month */}
        {availableMonths.length > 0 && (
          <div className="flex gap-1.5">
            {availableMonths.map(m => (
              <button key={m} onClick={() => setSelMonth(selMonth === m ? null : m)}
                className={`px-3 py-1.5 rounded-lg text-xs font-black tracking-wide transition-colors ${selMonth === m ? "bg-blue-600 text-white" : "bg-white border border-gray-200 text-gray-700 hover:bg-gray-50"}`}>
                {MONTHS[m - 1]}
              </button>
            ))}
          </div>
        )}
      </div>

      {loading ? <p className="text-sm text-gray-300">Loading...</p> : monthLogs.length === 0 ? (
        <div className="text-center py-16 text-gray-400 text-sm">No driver activity for this period.</div>
      ) : (
        <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-xs font-black text-gray-400 uppercase tracking-widest border-b border-gray-100">
                <th className="px-6 py-3.5 text-left">Date & Time</th>
                <th className="px-6 py-3.5 text-left">Driver</th>
                <th className="px-6 py-3.5 text-left">Tag</th>
                <th className="px-6 py-3.5 text-left">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {monthLogs.map(log => (
                <tr key={log.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="font-bold text-gray-900 text-xs">{log.timestamp.toLocaleDateString("en-AU", { day: "numeric", month: "short", year: "numeric" })}</div>
                    <div className="text-gray-400 text-xs">{log.timestamp.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-2">
                      <div className="w-7 h-7 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 text-xs font-black flex-shrink-0">
                        {(log.actorName ?? log.driverName ?? "?").charAt(0)}
                      </div>
                      <span className="font-bold text-gray-900">{log.actorName ?? log.driverName}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`text-[10px] font-black px-2 py-1 rounded-full ${getTagColor(log.tag ?? log.action)}`}>
                      {(log.tag ?? log.action ?? "").toUpperCase()}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-gray-700">{log.details ?? log.action}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

"use client";
import { useEffect, useState } from "react";
import { collection, getDocs, query, orderBy, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import PageHeader from "@/components/PageHeader";

interface AdminLogEntry {
  id: string;
  type: string;
  tag?: string;
  actorId?: string;
  actorName: string;
  targetId?: string;
  targetName?: string;
  details?: string;
  reason?: string;
  before?: Record<string, unknown>;
  after?: Record<string, unknown>;
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

const TAG_COLORS: Record<string, string> = {
  "remove driver":   "bg-red-100 text-red-700",
  "remove student":  "bg-red-100 text-red-700",
  "add driver":      "bg-blue-100 text-blue-700",
  "add student":     "bg-green-100 text-green-700",
  "add schedule":    "bg-orange-100 text-orange-700",
  "modify":          "bg-purple-100 text-purple-700",
  "login":           "bg-blue-100 text-blue-600",
  "logout":          "bg-gray-100 text-gray-600",
};

function tagColor(tag?: string) {
  const t = (tag ?? "").toLowerCase();
  for (const [k, v] of Object.entries(TAG_COLORS)) { if (t.includes(k)) return v; }
  return "bg-gray-100 text-gray-600";
}

export default function AdminLogPage() {
  const [logs, setLogs] = useState<AdminLogEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [years, setYears] = useState<number[]>([]);
  const [selYear, setSelYear] = useState<number | null>(null);
  const [selTerm, setSelTerm] = useState<number | null>(null);
  const [selMonth, setSelMonth] = useState<number | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  useEffect(() => {
    getDocs(query(collection(db, "adminLog"), orderBy("timestamp", "desc"))).then(snap => {
      const items = snap.docs.map(d => ({
        id: d.id, ...d.data(),
        timestamp: toDate(d.data().timestamp),
        year: d.data().year ?? new Date(toDate(d.data().timestamp)).getFullYear(),
        month: d.data().month ?? (new Date(toDate(d.data().timestamp)).getMonth() + 1),
      } as AdminLogEntry));
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

  return (
    <div className="max-w-5xl mx-auto">
      <PageHeader title="VIEW LOG" subtitle="Admin Log"
        breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "View Log" }, { label: "Admin Log" }]} accent="purple" />

      {/* Filters */}
      <div className="flex flex-wrap gap-3 mb-6">
        <div className="flex gap-1.5 flex-wrap">
          {years.map(y => (
            <button key={y} onClick={() => { setSelYear(y); setSelTerm(null); setSelMonth(null); }}
              className={`px-3 py-1.5 rounded-lg text-xs font-black tracking-wide transition-colors ${selYear === y ? "bg-purple-600 text-white" : "bg-white border border-gray-200 text-gray-700 hover:bg-gray-50"}`}>
              {y}
            </button>
          ))}
        </div>
        {availableTerms.length > 0 && (
          <div className="flex gap-1.5">
            {availableTerms.map(t => (
              <button key={t} onClick={() => { setSelTerm(selTerm === t ? null : t); setSelMonth(null); }}
                className={`px-3 py-1.5 rounded-lg text-xs font-black tracking-wide transition-colors ${selTerm === t ? "bg-purple-600 text-white" : "bg-white border border-gray-200 text-gray-700 hover:bg-gray-50"}`}>
                Term {t}
              </button>
            ))}
          </div>
        )}
        {availableMonths.length > 0 && (
          <div className="flex gap-1.5">
            {availableMonths.map(m => (
              <button key={m} onClick={() => setSelMonth(selMonth === m ? null : m)}
                className={`px-3 py-1.5 rounded-lg text-xs font-black tracking-wide transition-colors ${selMonth === m ? "bg-purple-600 text-white" : "bg-white border border-gray-200 text-gray-700 hover:bg-gray-50"}`}>
                {MONTHS[m - 1]}
              </button>
            ))}
          </div>
        )}
      </div>

      {loading ? <p className="text-sm text-gray-300">Loading...</p> : monthLogs.length === 0 ? (
        <div className="text-center py-16 text-gray-400 text-sm">No admin activity for this period.</div>
      ) : (
        <div className="space-y-2">
          {monthLogs.map(log => (
            <div key={log.id} className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
              {/* Main row */}
              <button
                className="w-full flex items-center gap-4 px-5 py-4 hover:bg-gray-50 transition-colors text-left"
                onClick={() => setExpandedId(expandedId === log.id ? null : log.id)}
              >
                <div className="w-8 h-8 rounded-full bg-purple-100 flex items-center justify-center text-purple-700 text-xs font-black flex-shrink-0">
                  {(log.actorName ?? "?").charAt(0)}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-0.5">
                    <span className="font-bold text-gray-900 text-sm">{log.actorName}</span>
                    <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${tagColor(log.tag ?? log.type)}`}>
                      {(log.tag ?? log.type ?? "").toUpperCase()}
                    </span>
                    {log.targetName && (
                      <span className="text-xs text-gray-500">→ {log.targetName}</span>
                    )}
                  </div>
                  <div className="text-xs text-gray-500 truncate">{log.details}</div>
                </div>
                <div className="text-right flex-shrink-0">
                  <div className="text-xs font-bold text-gray-900">{log.timestamp.toLocaleDateString("en-AU", { day: "numeric", month: "short" })}</div>
                  <div className="text-[10px] text-gray-400">{log.timestamp.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</div>
                </div>
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"
                  className={`flex-shrink-0 transition-transform ${expandedId === log.id ? "rotate-180" : ""}`}>
                  <polyline points="6 9 12 15 18 9"/>
                </svg>
              </button>

              {/* Expanded detail */}
              {expandedId === log.id && (
                <div className="px-5 pb-5 border-t border-gray-50">
                  <div className="mt-4 space-y-3">
                    {log.details && (
                      <div>
                        <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-1">Details</div>
                        <p className="text-sm text-gray-700">{log.details}</p>
                      </div>
                    )}
                    {log.reason && (
                      <div>
                        <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-1">Reason</div>
                        <p className="text-sm text-gray-700">{log.reason}</p>
                      </div>
                    )}
                    {/* Before / After */}
                    {(log.before || log.after) && (
                      <div className="bg-gray-50 rounded-xl p-4">
                        <div className="grid grid-cols-2 gap-4 divide-x divide-gray-200">
                          <div>
                            <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">Before</div>
                            {log.before && Object.entries(log.before).map(([k, v]) => (
                              <div key={k} className="text-xs text-gray-700"><span className="font-bold text-gray-500">{k}:</span> {String(v)}</div>
                            ))}
                          </div>
                          <div className="pl-4">
                            <div className="text-[10px] font-black tracking-widest text-gray-400 uppercase mb-2">After</div>
                            {log.after && Object.entries(log.after).map(([k, v]) => (
                              <div key={k} className="text-xs text-gray-700"><span className="font-bold text-gray-500">{k}:</span> {String(v)}</div>
                            ))}
                          </div>
                        </div>
                      </div>
                    )}
                    <div className="text-[10px] text-gray-400">
                      {log.timestamp.toLocaleString("en-AU", { dateStyle: "full", timeStyle: "short" })}
                    </div>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

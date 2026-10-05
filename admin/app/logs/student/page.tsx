"use client";
import { useEffect, useState } from "react";
import { collection, getDocs, query, orderBy, where, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Student } from "@/lib/types";
import PageHeader from "@/components/PageHeader";

interface StudentLog {
  id: string;
  type: string;
  tag?: string;
  studentId: string;
  studentName: string;
  routeName?: string;
  stopAddress?: string;
  action: string;
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

export default function StudentLogPage() {
  const [logs, setLogs] = useState<StudentLog[]>([]);
  const [students, setStudents] = useState<Student[]>([]);
  const [loading, setLoading] = useState(true);

  const [selYear, setSelYear] = useState<number | null>(null);
  const [selTerm, setSelTerm] = useState<number | null>(null);
  const [selStudent, setSelStudent] = useState<string | null>(null);

  const [years, setYears] = useState<number[]>([]);

  useEffect(() => {
    Promise.all([
      getDocs(query(collection(db, "studentLog"), orderBy("timestamp", "desc"))),
      getDocs(collection(db, "students")),
    ]).then(([logSnap, studentSnap]) => {
      const items = logSnap.docs.map(d => ({
        id: d.id, ...d.data(),
        timestamp: toDate(d.data().timestamp),
        year: d.data().year ?? new Date(toDate(d.data().timestamp)).getFullYear(),
        month: d.data().month ?? (new Date(toDate(d.data().timestamp)).getMonth() + 1),
      } as StudentLog));
      setLogs(items);
      setStudents(studentSnap.docs.map(d => ({ id: d.id, ...d.data() } as Student)));
      const ys = [...new Set(items.map(l => l.year))].sort((a, b) => b - a);
      setYears(ys);
      if (ys.length > 0) setSelYear(ys[0]);
      setLoading(false);
    });
  }, []);

  const yearLogs = logs.filter(l => l.year === selYear);
  const termLogs = selTerm ? yearLogs.filter(l => TERM_MONTHS[selTerm].includes(l.month ?? 0)) : yearLogs;
  const studentLogs = selStudent ? termLogs.filter(l => l.studentId === selStudent) : termLogs;

  const studentsInLogs = students.filter(s => termLogs.some(l => l.studentId === s.id));
  const availableTerms = selYear ? [...new Set(yearLogs.map(l => Math.ceil((l.month ?? 1) / 3)))].sort() : [];

  const tagColor = (tag?: string) => {
    const t = (tag ?? "").toLowerCase();
    if (t.includes("pickup") || t.includes("onbus")) return "bg-green-100 text-green-700";
    if (t.includes("dropoff") || t.includes("offbus")) return "bg-orange-100 text-orange-700";
    if (t.includes("absent")) return "bg-red-100 text-red-600";
    return "bg-gray-100 text-gray-600";
  };

  return (
    <div className="max-w-5xl mx-auto">
      <PageHeader title="VIEW LOG" subtitle="Student Log"
        breadcrumbs={[{ label: "Dashboard", href: "/" }, { label: "View Log" }, { label: "Student Log" }]} accent="green" />

      {/* Filter bar */}
      <div className="flex flex-wrap gap-3 mb-6">
        {/* Year */}
        <div className="flex gap-1.5 flex-wrap">
          {years.map(y => (
            <button key={y} onClick={() => { setSelYear(y); setSelTerm(null); setSelStudent(null); }}
              className={`px-3 py-1.5 rounded-lg text-xs font-black tracking-wide transition-colors ${selYear === y ? "bg-green-600 text-white" : "bg-white border border-gray-200 text-gray-700 hover:bg-gray-50"}`}>
              {y}
            </button>
          ))}
        </div>

        {/* Term */}
        {availableTerms.length > 0 && (
          <div className="flex gap-1.5">
            {availableTerms.map(t => (
              <button key={t} onClick={() => { setSelTerm(selTerm === t ? null : t); setSelStudent(null); }}
                className={`px-3 py-1.5 rounded-lg text-xs font-black tracking-wide transition-colors ${selTerm === t ? "bg-green-600 text-white" : "bg-white border border-gray-200 text-gray-700 hover:bg-gray-50"}`}>
                Term {t}
              </button>
            ))}
          </div>
        )}

        {/* Student selector */}
        {studentsInLogs.length > 0 && (
          <select
            className="px-3 py-1.5 rounded-lg text-xs font-bold text-gray-700 bg-white border border-gray-200 focus:outline-none focus:ring-2 focus:ring-green-200"
            value={selStudent ?? ""}
            onChange={e => setSelStudent(e.target.value || null)}
          >
            <option value="">All Students</option>
            {studentsInLogs.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        )}
      </div>

      {loading ? <p className="text-sm text-gray-300">Loading...</p> : studentLogs.length === 0 ? (
        <div className="text-center py-16 text-gray-400 text-sm">No student activity for this period.</div>
      ) : (
        <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-xs font-black text-gray-400 uppercase tracking-widest border-b border-gray-100">
                <th className="px-6 py-3.5 text-left">Date & Time</th>
                <th className="px-6 py-3.5 text-left">Student</th>
                <th className="px-6 py-3.5 text-left">Tag</th>
                <th className="px-6 py-3.5 text-left">Detail</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {studentLogs.map(log => (
                <tr key={log.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="font-bold text-gray-900 text-xs">{log.timestamp.toLocaleDateString("en-AU", { day: "numeric", month: "short", year: "numeric" })}</div>
                    <div className="text-gray-400 text-xs">{log.timestamp.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-2">
                      <div className="w-7 h-7 rounded-full bg-green-100 flex items-center justify-center text-green-700 text-xs font-black flex-shrink-0">
                        {(log.studentName ?? "?").charAt(0)}
                      </div>
                      <div>
                        <div className="font-bold text-gray-900">{log.studentName}</div>
                        {log.routeName && <div className="text-[10px] text-gray-400">{log.routeName}</div>}
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`text-[10px] font-black px-2 py-1 rounded-full ${tagColor(log.tag ?? log.type)}`}>
                      {(log.tag ?? log.type ?? "").toUpperCase()}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-gray-700 text-xs">{log.details ?? log.action}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

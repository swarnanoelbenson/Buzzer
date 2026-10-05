"use client";
import { useState, useEffect } from "react";
import { collection, doc, getDocs, query, where, writeBatch, Timestamp, addDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
import type { Route, Driver, Trip } from "@/lib/types";

// ── Overlay (matches pattern in schedule/page.tsx) ─────────────────────────────
function Overlay({ children }: { children: React.ReactNode }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
      {children}
    </div>
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────
const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-amber-200 focus:border-amber-400 transition";
const LABEL = "block text-[10px] font-black tracking-widest text-gray-400 uppercase mb-1.5";

function toInputDate(d: Date): string {
  return d instanceof Date && !isNaN(d.getTime()) ? d.toISOString().split("T")[0] : "";
}

function toDate(v: unknown): Date | null {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof (v as Timestamp).toDate === "function") return (v as Timestamp).toDate();
  return null;
}

// ── Component ─────────────────────────────────────────────────────────────────
interface Props {
  route: Route;
  drivers: Driver[];
  onClose: () => void;
  onCompleted: () => void;
}

export default function SubstituteDriverModal({ route, drivers, onClose, onCompleted }: Props) {
  const { user } = useAuth();

  const today = toInputDate(new Date());
  const routeStart = toInputDate(route.startDate instanceof Date ? route.startDate : new Date());
  const routeEnd = toInputDate(route.endDate instanceof Date ? route.endDate : new Date());

  // Drivers available for substitution: active and not the current driver
  const availableDrivers = drivers.filter(d => d.isActive && d.id !== route.driverId);
  const currentDriverName = drivers.find(d => d.id === route.driverId)?.name ?? "—";

  const [substituteDriverId, setSubstituteDriverId] = useState("");
  const [fromDate, setFromDate] = useState(today);
  const [toDate, setToDate] = useState(today);
  const [formError, setFormError] = useState("");

  const [step, setStep] = useState<"form" | "preview">("form");
  const [previewLoading, setPreviewLoading] = useState(false);
  const [previewError, setPreviewError] = useState("");
  const [scheduledTrips, setScheduledTrips] = useState<Trip[]>([]);
  const [skippedCount, setSkippedCount] = useState(0);

  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState("");

  // Clear errors when any field changes
  useEffect(() => { setFormError(""); }, [substituteDriverId, fromDate, toDate]);

  function validate(): boolean {
    if (!substituteDriverId) {
      setFormError("Select a substitute driver.");
      return false;
    }
    if (!fromDate || !toDate) {
      setFormError("Select a date range.");
      return false;
    }
    const from = new Date(fromDate);
    const to = new Date(toDate);
    const todayDate = new Date(today);
    if (from < todayDate) {
      setFormError("Start date cannot be in the past.");
      return false;
    }
    if (to < from) {
      setFormError("End date must be on or after the start date.");
      return false;
    }
    const rStart = route.startDate instanceof Date ? route.startDate : null;
    const rEnd = route.endDate instanceof Date ? route.endDate : null;
    if (rStart && from < rStart) {
      setFormError(`Start date cannot be before the route starts (${routeStart}).`);
      return false;
    }
    if (rEnd && to > rEnd) {
      setFormError(`End date cannot be after the route ends (${routeEnd}).`);
      return false;
    }
    return true;
  }

  async function handlePreview() {
    if (!validate()) return;
    setPreviewLoading(true);
    setPreviewError("");
    try {
      const from = new Date(fromDate);
      from.setHours(0, 0, 0, 0);
      const to = new Date(toDate);
      to.setHours(23, 59, 59, 999);

      const q = query(
        collection(db, "trips"),
        where("routeId", "==", route.id),
        where("date", ">=", Timestamp.fromDate(from)),
        where("date", "<=", Timestamp.fromDate(to))
      );
      const snap = await getDocs(q);
      const all = snap.docs.map(d => ({ id: d.id, ...d.data() } as Trip));
      const scheduled = all.filter(t => t.status === "scheduled");
      const skipped = all.length - scheduled.length;

      if (scheduled.length === 0) {
        setPreviewError("No scheduled trips found in this date range. Trips may already be completed or cancelled.");
        setScheduledTrips([]);
        setSkippedCount(skipped);
        return;
      }

      setScheduledTrips(scheduled);
      setSkippedCount(skipped);
      setStep("preview");
    } catch (e) {
      console.error(e);
      setPreviewError("Failed to load trips. Please try again.");
    } finally {
      setPreviewLoading(false);
    }
  }

  async function handleConfirm() {
    if (scheduledTrips.length === 0) return;
    setSaving(true);
    setSaveError("");
    try {
      const batch = writeBatch(db);

      for (const trip of scheduledTrips) {
        batch.update(doc(db, "trips", trip.id), { driverId: substituteDriverId });
      }

      const substituteDriverName = drivers.find(d => d.id === substituteDriverId)?.name ?? substituteDriverId;
      const pickups = scheduledTrips.filter(t => t.type === "pickup").length;
      const dropoffs = scheduledTrips.filter(t => t.type === "dropoff").length;

      await batch.commit();

      // Log to adminLog (separate write — not in batch to keep batch size down and avoid issues)
      await addDoc(collection(db, "adminLog"), {
        type: "substitute_driver",
        tag: "SUBSTITUTE DRIVER",
        actorId: user?.uid ?? "admin",
        actorName: user?.displayName ?? user?.email ?? "Admin",
        targetId: route.id,
        targetName: route.name,
        details: `Substitute driver for ${route.name}: ${currentDriverName} → ${substituteDriverName} (${fromDate} to ${toDate}, ${scheduledTrips.length} trips: ${pickups} pickups + ${dropoffs} dropoffs)`,
        year: new Date().getFullYear(),
        term: route.term,
        month: new Date().getMonth() + 1,
        timestamp: Timestamp.now(),
      });

      onCompleted();
    } catch (e) {
      console.error(e);
      setSaveError("Failed to save substitution. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  const substituteDriverName = drivers.find(d => d.id === substituteDriverId)?.name ?? "";
  const pickups = scheduledTrips.filter(t => t.type === "pickup").length;
  const dropoffs = scheduledTrips.filter(t => t.type === "dropoff").length;

  return (
    <Overlay>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="px-6 py-5 border-b border-gray-100 flex items-center gap-4 flex-shrink-0">
          <div className="w-10 h-10 rounded-full bg-amber-100 flex items-center justify-center text-amber-700 text-base font-black">
            {route.name.charAt(0)}
          </div>
          <div>
            <div className="text-base font-black text-gray-900">Substitute Driver</div>
            <div className="text-xs text-gray-400 font-medium">{route.name}</div>
          </div>
          <button onClick={onClose} className="ml-auto text-gray-400 hover:text-gray-600">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>

        {/* Body */}
        <div className="overflow-y-auto flex-1 px-6 py-5 space-y-5">
          {step === "form" ? (
            <>
              {/* Current driver info */}
              <div className="bg-gray-50 rounded-xl px-4 py-3 text-xs text-gray-500">
                <span className="font-black tracking-widest uppercase text-gray-400">Current driver</span>
                <div className="mt-1 font-bold text-gray-700">{currentDriverName}</div>
              </div>

              {/* Substitute driver dropdown */}
              <div>
                <label className={LABEL}>Substitute Driver</label>
                {availableDrivers.length === 0 ? (
                  <p className="text-xs text-amber-600 font-bold">No other active drivers available.</p>
                ) : (
                  <select
                    className={FIELD}
                    value={substituteDriverId}
                    onChange={e => setSubstituteDriverId(e.target.value)}
                  >
                    <option value="">— select substitute driver —</option>
                    {availableDrivers.map(d => (
                      <option key={d.id} value={d.id}>{d.name}</option>
                    ))}
                  </select>
                )}
              </div>

              {/* Date range */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className={LABEL}>From Date</label>
                  <input
                    className={FIELD}
                    type="date"
                    value={fromDate}
                    min={today}
                    max={routeEnd}
                    onChange={e => setFromDate(e.target.value)}
                  />
                </div>
                <div>
                  <label className={LABEL}>To Date</label>
                  <input
                    className={FIELD}
                    type="date"
                    value={toDate}
                    min={fromDate || today}
                    max={routeEnd}
                    onChange={e => setToDate(e.target.value)}
                  />
                </div>
              </div>

              {/* Route period context */}
              <p className="text-[11px] text-gray-400">
                Route period: <span className="font-bold">{routeStart}</span> to <span className="font-bold">{routeEnd}</span>
              </p>

              {formError && <p className="text-xs text-red-500 font-bold">{formError}</p>}
              {previewError && <p className="text-xs text-amber-600 font-bold">{previewError}</p>}
            </>
          ) : (
            /* Preview step */
            <>
              <div className="bg-amber-50 border border-amber-200 rounded-xl px-4 py-4 space-y-3">
                <p className="text-xs font-black tracking-widest text-amber-700 uppercase">Substitution Summary</p>
                <div className="space-y-1.5 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-500">Current driver</span>
                    <span className="font-bold text-gray-900">{currentDriverName}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">Substitute driver</span>
                    <span className="font-bold text-amber-700">{substituteDriverName}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">Date range</span>
                    <span className="font-bold text-gray-900">{fromDate} → {toDate}</span>
                  </div>
                </div>
                <div className="border-t border-amber-200 pt-3 space-y-1">
                  <p className="text-sm font-black text-gray-900">
                    {scheduledTrips.length} trip{scheduledTrips.length !== 1 ? "s" : ""} will be reassigned
                  </p>
                  <p className="text-xs text-gray-500">{pickups} pickup{pickups !== 1 ? "s" : ""} + {dropoffs} dropoff{dropoffs !== 1 ? "s" : ""}</p>
                  {skippedCount > 0 && (
                    <p className="text-xs text-amber-600 font-bold mt-1">
                      {skippedCount} completed/in-progress trip{skippedCount !== 1 ? "s" : ""} will be skipped.
                    </p>
                  )}
                </div>
              </div>

              <p className="text-xs text-gray-400">
                To undo this substitution, open Substitute again and select <span className="font-bold">{currentDriverName}</span> for the same date range.
              </p>

              {saveError && <p className="text-xs text-red-500 font-bold">{saveError}</p>}
            </>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
          {step === "form" ? (
            <>
              <button
                onClick={onClose}
                className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handlePreview}
                disabled={previewLoading || availableDrivers.length === 0}
                className="px-5 py-2.5 bg-amber-500 text-white text-sm font-black rounded-xl hover:bg-amber-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {previewLoading ? "Loading…" : "Preview"}
              </button>
            </>
          ) : (
            <>
              <button
                onClick={() => { setStep("form"); setSaveError(""); }}
                className="px-5 py-2.5 text-sm font-bold text-gray-500 hover:text-gray-700"
                disabled={saving}
              >
                Back
              </button>
              <button
                onClick={handleConfirm}
                disabled={saving}
                className="px-5 py-2.5 bg-amber-500 text-white text-sm font-black rounded-xl hover:bg-amber-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {saving ? "Saving…" : "Confirm Substitution"}
              </button>
            </>
          )}
        </div>
      </div>
    </Overlay>
  );
}

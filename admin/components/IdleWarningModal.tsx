"use client";
import { useEffect, useState } from "react";

interface IdleWarningModalProps {
  /** Total milliseconds in the warning window (e.g. 5 * 60 * 1000) */
  warningMs: number;
  onStay: () => void;
  onSignOut: () => void;
}

export default function IdleWarningModal({ warningMs, onStay, onSignOut }: IdleWarningModalProps) {
  const [secondsLeft, setSecondsLeft] = useState(Math.ceil(warningMs / 1000));

  useEffect(() => {
    // Tick every second
    const interval = setInterval(() => {
      setSecondsLeft(s => {
        if (s <= 1) {
          clearInterval(interval);
          return 0;
        }
        return s - 1;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  const minutes = Math.floor(secondsLeft / 60);
  const seconds = secondsLeft % 60;
  const timeString = minutes > 0
    ? `${minutes}:${String(seconds).padStart(2, "0")}`
    : `${seconds}s`;

  // Fraction of warning time remaining (1 → 0)
  const fraction = secondsLeft / Math.ceil(warningMs / 1000);
  // Stroke dash for the circular progress (circumference ≈ 2π × 20 ≈ 125.7)
  const circumference = 2 * Math.PI * 20;
  const strokeDash = fraction * circumference;

  return (
    <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-8 flex flex-col items-center gap-5">
        {/* Circular countdown */}
        <div className="relative w-20 h-20">
          <svg className="w-20 h-20 -rotate-90" viewBox="0 0 48 48">
            {/* Track */}
            <circle cx="24" cy="24" r="20" fill="none" stroke="#e5e7eb" strokeWidth="4" />
            {/* Progress */}
            <circle
              cx="24" cy="24" r="20"
              fill="none"
              stroke={secondsLeft <= 30 ? "#ef4444" : "#2563eb"}
              strokeWidth="4"
              strokeLinecap="round"
              strokeDasharray={`${strokeDash} ${circumference}`}
              style={{ transition: "stroke-dasharray 0.9s linear, stroke 0.3s" }}
            />
          </svg>
          <span className="absolute inset-0 flex items-center justify-center text-base font-black text-gray-800">
            {timeString}
          </span>
        </div>

        {/* Text */}
        <div className="text-center space-y-1">
          <h2 className="text-lg font-black text-gray-900">Still there?</h2>
          <p className="text-sm text-gray-500">
            You've been inactive. You'll be signed out automatically in{" "}
            <span className={`font-bold ${secondsLeft <= 30 ? "text-red-500" : "text-blue-600"}`}>
              {timeString}
            </span>
            .
          </p>
        </div>

        {/* Buttons */}
        <div className="flex gap-3 w-full">
          <button
            onClick={onSignOut}
            className="flex-1 px-4 py-2.5 border border-gray-200 text-gray-500 text-sm font-bold rounded-xl hover:bg-gray-50 transition-colors"
          >
            Sign Out
          </button>
          <button
            onClick={onStay}
            className="flex-1 px-4 py-2.5 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 transition-colors"
          >
            Stay Signed In
          </button>
        </div>
      </div>
    </div>
  );
}

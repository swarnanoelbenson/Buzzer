"use client";

interface ConcurrentSessionModalProps {
  onSignOut: () => void;
}

export default function ConcurrentSessionModal({ onSignOut }: ConcurrentSessionModalProps) {
  return (
    <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-8 flex flex-col items-center gap-5 text-center">
        <div className="w-16 h-16 rounded-2xl bg-amber-50 flex items-center justify-center">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#d97706" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
            <line x1="12" y1="9" x2="12" y2="13"/>
            <line x1="12" y1="17" x2="12.01" y2="17"/>
          </svg>
        </div>
        <div className="space-y-1">
          <h2 className="text-lg font-black text-gray-900">Signed Out</h2>
          <p className="text-sm text-gray-500">
            Your account was signed in on another device or browser. Only one active session is allowed at a time.
          </p>
        </div>
        <button
          onClick={onSignOut}
          className="w-full px-4 py-3 bg-blue-600 text-white text-sm font-black rounded-xl hover:bg-blue-700 transition-colors"
        >
          Back to Login
        </button>
      </div>
    </div>
  );
}

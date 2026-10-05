"use client";
import Image from "next/image";
import { useState } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { Suspense } from "react";

function CheckEmailContent() {
  const params = useSearchParams();
  const email = params.get("email") ?? "";
  const school = params.get("school") ?? "";

  const [resendState, setResendState] = useState<"idle" | "sending" | "sent" | "error">("idle");

  const handleResend = async () => {
    setResendState("sending");
    try {
      const res = await fetch("/api/admin-signin-link/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email.toLowerCase(), origin: window.location.origin }),
      });
      setResendState(res.ok ? "sent" : "error");
    } catch {
      setResendState("error");
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex flex-col items-center mb-8">
          <div className="mb-4">
            <Image src="/busmate-logo-website.png" alt="BusMate" width={180} height={48} className="object-contain" />
          </div>
          <p className="text-xl font-black tracking-widest text-gray-900 uppercase mt-2">Admin Console</p>
        </div>

        {/* Card */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-8 text-center">
          {/* Mail icon */}
          <div className="w-16 h-16 rounded-2xl bg-blue-50 flex items-center justify-center mx-auto mb-5">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#2563eb" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
              <polyline points="22,6 12,13 2,6"/>
            </svg>
          </div>

          <h2 className="text-lg font-black text-gray-900 mb-2">Check Your Inbox</h2>

          <p className="text-sm text-gray-900 mb-1">A sign-in link has been sent to</p>
          <p className="text-sm font-bold text-gray-900 mb-1 break-all">{email}</p>

          {school && (
            <div className="inline-flex items-center gap-1.5 px-3 py-1 bg-blue-50 rounded-full mb-4 mt-1">
              <span className="text-[10px] font-black tracking-widest text-blue-600 uppercase">{school}</span>
            </div>
          )}

          <p className="text-sm text-gray-900 mb-6 mt-3">
            Click the link in the email to sign in. The link expires in 15 minutes.
          </p>

          {/* Resend */}
          {resendState === "sent" ? (
            <div className="mb-5 px-4 py-2.5 bg-green-50 border border-green-200 text-green-700 text-xs rounded-xl">
              Link resent — check your inbox (and spam folder).
            </div>
          ) : resendState === "error" ? (
            <div className="mb-5 px-4 py-2.5 bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl">
              Failed to resend. Please try again.
            </div>
          ) : null}

          <button
            onClick={handleResend}
            disabled={resendState === "sending" || resendState === "sent"}
            className="text-xs text-blue-600 font-bold hover:underline disabled:opacity-50 mb-5 block mx-auto"
          >
            {resendState === "sending" ? "Resending..." : "Resend link"}
          </button>

          <p className="text-[11px] text-gray-900 mb-5">
            Didn&apos;t receive it? Check your spam folder.
          </p>

          <Link
            href="/login"
            className="block w-full py-3 bg-gray-100 text-gray-700 font-black text-sm rounded-xl hover:bg-gray-200 transition-colors tracking-wide"
          >
            Back to Sign In
          </Link>
        </div>
      </div>
    </div>
  );
}

export default function CheckEmailPage() {
  return (
    <Suspense>
      <CheckEmailContent />
    </Suspense>
  );
}

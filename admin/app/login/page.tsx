"use client";
import Image from "next/image";
import { useState } from "react";
import { signInWithCustomToken, updateProfile } from "firebase/auth";
import { collection, addDoc, getDocs, query, where, Timestamp, doc, updateDoc } from "firebase/firestore";
import { auth, db } from "@/lib/firebase";

type Step = "email" | "otp";

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-base text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 transition";

export default function LoginPage() {
  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    const normalizedEmail = email.trim().toLowerCase();
    try {
      const res = await fetch("/api/admin-otp/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: normalizedEmail }),
      });

      if (!res.ok) {
        const data = await res.json();
        // Swallow 404 (no account) — don't reveal whether the account exists
        if (res.status !== 404) {
          setError(data.error ?? "Failed to send code. Please try again.");
          setLoading(false);
          return;
        }
      }

      setStep("otp");
    } catch {
      setError("Failed to send code. Please try again.");
    }

    setLoading(false);
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    const normalizedEmail = email.trim().toLowerCase();
    try {
      const res = await fetch("/api/admin-otp/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: normalizedEmail, otp: otp.trim() }),
      });

      const data = await res.json();

      if (!res.ok) {
        setError(data.error ?? "Verification failed. Please try again.");
        setLoading(false);
        return;
      }

      const { customToken, schoolName, adminName, adminUid } = data;

      // Sign in to Firebase Auth with the custom token
      const cred = await signInWithCustomToken(auth, customToken);
      const user = cred.user;

      // Update display name if not yet set
      if (adminName && adminName !== normalizedEmail && !user.displayName) {
        await updateProfile(user, { displayName: adminName });
      }

      const now = new Date();

      // Write a session token to the school doc so concurrent sessions can be detected
      const sessionToken = crypto.randomUUID();
      sessionStorage.setItem("sessionToken", sessionToken);

      const schoolSnap = await getDocs(
        query(collection(db, "schools"), where("adminUid", "==", user.uid))
      );
      if (!schoolSnap.empty) {
        await updateDoc(doc(db, "schools", schoolSnap.docs[0].id), { sessionToken });
      }

      const resolvedSchoolName = schoolSnap.empty ? schoolName : (schoolSnap.docs[0].data().schoolName as string);
      const displayName = user.displayName ?? adminName ?? user.email?.split("@")[0] ?? "Admin";

      // Log the login event
      await addDoc(collection(db, "adminLog"), {
        type: "login",
        tag: "LOGIN",
        actorId: adminUid ?? user.uid,
        actorName: displayName,
        targetName: resolvedSchoolName,
        details: `Admin login — ${resolvedSchoolName}`,
        timestamp: Timestamp.now(),
        year: now.getFullYear(),
        term: Math.ceil((now.getMonth() + 1) / 3),
        month: now.getMonth() + 1,
      });

      // Send login notification (fire-and-forget)
      fetch("/api/notify-login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: user.email,
          displayName,
          schoolName: resolvedSchoolName,
          timestamp: now.toISOString(),
        }),
      }).catch(() => {});

      // Hard navigation so Firebase auth state is cleanly picked up
      window.location.href = "/";
    } catch (err: unknown) {
      const code = (err as { code?: string }).code;
      if (code === "auth/invalid-custom-token") {
        setError("Sign-in failed. Please request a new code.");
      } else {
        setError("Sign-in failed. Please try again.");
      }
    }

    setLoading(false);
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
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-8">

          {step === "email" && (
            <>
              <h2 className="text-lg font-black text-gray-900 mb-1">Sign In</h2>
              <p className="text-sm text-gray-900 mb-6">Enter your email to receive a verification code.</p>

              {error && (
                <div className="mb-4 px-4 py-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl">
                  {error}
                </div>
              )}

              <form onSubmit={handleSendOtp} className="space-y-4">
                <div>
                  <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">Email</label>
                  <input
                    type="email" required autoComplete="email"
                    className={FIELD}
                    placeholder="admin@school.edu.au"
                    value={email}
                    onChange={e => setEmail(e.target.value)}
                  />
                </div>
                <button
                  type="submit" disabled={loading}
                  className="w-full mt-2 py-3 bg-blue-600 text-white font-black text-base rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors tracking-wide"
                >
                  {loading ? "Sending code..." : "Continue"}
                </button>
              </form>
            </>
          )}

          {step === "otp" && (
            <>
              <h2 className="text-lg font-black text-gray-900 mb-2">BusMate Admin Console</h2>
              <p className="text-sm text-gray-900 mb-6">
                If this address is linked to a BusMate membership, you&apos;ll receive a 6-digit code.
              </p>

              {error && (
                <div className="mb-4 px-4 py-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl">
                  {error}
                </div>
              )}

              <form onSubmit={handleVerifyOtp} className="space-y-4">
                <div>
                  <label className="block text-xs font-black tracking-widests text-gray-900 uppercase mb-1.5">Verification Code</label>
                  <input
                    type="text" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} required autoComplete="one-time-code"
                    className={FIELD}
                    placeholder="000000"
                    value={otp}
                    onChange={e => setOtp(e.target.value.replace(/\D/g, ""))}
                  />
                </div>
                <button
                  type="submit" disabled={loading}
                  className="w-full mt-2 py-3 bg-blue-600 text-white font-black text-base rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors tracking-wide"
                >
                  {loading ? "Signing in..." : "Sign In"}
                </button>
              </form>

              <button
                type="button"
                onClick={() => { setStep("email"); setOtp(""); setError(""); }}
                className="mt-4 w-full text-center text-sm text-blue-600 font-bold hover:underline"
              >
                Use a different email
              </button>
            </>
          )}

        </div>
      </div>
    </div>
  );
}

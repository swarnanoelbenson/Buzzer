"use client";
import Image from "next/image";
import { useState } from "react";
import { collection, getDocs, query, where } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useRouter } from "next/navigation";
import Link from "next/link";

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-base text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 transition";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      const normalizedEmail = email.trim().toLowerCase();

      // Gate: only send link if email exists in the schools collection
      const schoolSnap = await getDocs(
        query(collection(db, "schools"), where("email", "==", normalizedEmail))
      );
      if (schoolSnap.empty) {
        setError("No account found for this email. Please sign up first.");
        setLoading(false);
        return;
      }

      const res = await fetch("/api/admin-signin-link/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: normalizedEmail, origin: window.location.origin }),
      });

      if (!res.ok) {
        const data = await res.json();
        setError(data.error ?? "Failed to send sign-in link. Please try again.");
        setLoading(false);
        return;
      }

      router.replace(`/check-email?email=${encodeURIComponent(normalizedEmail)}`);
    } catch {
      setError("Failed to send sign-in link. Please try again.");
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
          <h2 className="text-lg font-black text-gray-900 mb-1">Sign In</h2>
          <p className="text-sm text-gray-900 mb-6">Enter your email to receive a sign-in link.</p>

          {error && (
            <div className="mb-4 px-4 py-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl">
              {error}
            </div>
          )}

          <form onSubmit={handleLogin} className="space-y-4">
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
              {loading ? "Sending link..." : "Send Sign-In Link"}
            </button>
          </form>

          <p className="mt-5 text-center text-sm text-gray-900">
            Don&apos;t have an account?{" "}
            <Link href="/signup" className="text-blue-600 font-bold hover:underline">
              Sign Up
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}

"use client";
import Image from "next/image";
import { useState } from "react";
import { collection, query, where, getDocs } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useRouter } from "next/navigation";
import Link from "next/link";

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-base text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 transition";

export default function SignupPage() {
  const router = useRouter();
  const [schoolName, setSchoolName] = useState("");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSignup = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (!schoolName.trim()) { setError("Please enter your school name."); return; }

    setLoading(true);

    try {
      const schoolsRef = collection(db, "schools");

      // Check for duplicate school name (case-insensitive)
      const nameSnap = await getDocs(
        query(schoolsRef, where("schoolNameLower", "==", schoolName.trim().toLowerCase()))
      );
      if (!nameSnap.empty) {
        setError("A school with this name is already registered.");
        setLoading(false);
        return;
      }

      // Check for duplicate email
      const emailSnap = await getDocs(
        query(schoolsRef, where("email", "==", email.trim().toLowerCase()))
      );
      if (!emailSnap.empty) {
        setError("This email is already registered to a school.");
        setLoading(false);
        return;
      }

      const pendingSignup = {
        schoolName: schoolName.trim(),
        schoolNameLower: schoolName.trim().toLowerCase(),
        adminName: name.trim() || email.trim(),
        email: email.trim().toLowerCase(),
        isSignup: true,
      };

      const res = await fetch("/api/admin-signin-link/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: email.trim().toLowerCase(),
          pendingSignup,
          origin: window.location.origin,
        }),
      });

      if (!res.ok) {
        const data = await res.json();
        setError(data.error ?? "Sign up failed. Please try again.");
        setLoading(false);
        return;
      }

      router.replace(
        `/check-email?email=${encodeURIComponent(email.trim())}&school=${encodeURIComponent(schoolName.trim())}`
      );
    } catch {
      setError("Sign up failed. Please try again.");
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
          <p className="text-xl font-black tracking-widests text-gray-900 uppercase mt-2">Admin Console</p>
        </div>

        {/* Card */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-8">
          <h2 className="text-lg font-black text-gray-900 mb-1">Create Admin Account</h2>
          <p className="text-sm text-gray-900 mb-6">Register your school to get started.</p>

          {error && (
            <div className="mb-4 px-4 py-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl">
              {error}
            </div>
          )}

          <form onSubmit={handleSignup} className="space-y-4">
            <div>
              <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">School Name</label>
              <input
                type="text" required autoComplete="organization"
                className={FIELD}
                placeholder="e.g. St Mary's College"
                value={schoolName}
                onChange={e => setSchoolName(e.target.value)}
              />
            </div>
            <div>
              <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">Full Name</label>
              <input
                type="text" autoComplete="name"
                className={FIELD}
                placeholder="Admin's full name"
                value={name}
                onChange={e => setName(e.target.value)}
              />
            </div>
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
            Already have an account?{" "}
            <Link href="/login" className="text-blue-600 font-bold hover:underline">
              Sign In
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}

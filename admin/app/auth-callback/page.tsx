"use client";
import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { signInWithCustomToken, updateProfile } from "firebase/auth";
import { collection, addDoc, getDocs, query, where, Timestamp } from "firebase/firestore";
import { auth, db } from "@/lib/firebase";
import { useRouter } from "next/navigation";
import Link from "next/link";

type Status = "processing" | "success" | "error";

export default function AuthCallbackPage() {
  const router = useRouter();
  const [status, setStatus] = useState<Status>("processing");
  const [message, setMessage] = useState("");
  const hasRun = useRef(false);

  useEffect(() => {
    if (hasRun.current) return;
    hasRun.current = true;

    const params = new URLSearchParams(window.location.search);
    const token = params.get("token");
    const email = params.get("email");

    if (!token || !email) {
      setStatus("error");
      setMessage("Invalid sign-in link. Please request a new one.");
      return;
    }

    completeSignIn(token, email);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const completeSignIn = async (token: string, email: string) => {
    try {
      // Verify the token server-side and get a Firebase custom token
      const res = await fetch("/api/admin-signin-link/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token, email }),
      });

      if (!res.ok) {
        const data = await res.json();
        setStatus("error");
        setMessage(data.error ?? "Sign-in failed. Please request a new link.");
        return;
      }

      const { customToken, schoolName, adminName, isSignup } = await res.json();

      // Sign in to Firebase Auth with the custom token
      const cred = await signInWithCustomToken(auth, customToken);
      const user = cred.user;

      // Update display name if not yet set
      if (adminName && adminName !== email && !user.displayName) {
        await updateProfile(user, { displayName: adminName });
      }

      const now = new Date();

      if (isSignup) {
        // Log the signup (school doc is already created by the verify route)
        await addDoc(collection(db, "adminLog"), {
          type: "signup",
          tag: "SIGNUP",
          actorId: user.uid,
          actorName: adminName,
          details: `New admin registered for ${schoolName}`,
          timestamp: Timestamp.now(),
          year: now.getFullYear(),
          term: Math.ceil((now.getMonth() + 1) / 3),
          month: now.getMonth() + 1,
        });
      } else {
        // Returning login — find school and write login log
        const schoolSnap = await getDocs(
          query(collection(db, "schools"), where("adminUid", "==", user.uid))
        );

        if (schoolSnap.empty) {
          await auth.signOut();
          setStatus("error");
          setMessage("No school account found for this email. Please sign up first.");
          return;
        }

        const resolvedSchoolName = schoolSnap.docs[0].data().schoolName as string;
        const displayName = user.displayName ?? user.email?.split("@")[0] ?? "Admin";

        await addDoc(collection(db, "adminLog"), {
          type: "login",
          tag: "LOGIN",
          actorId: user.uid,
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
      }

      setStatus("success");
      if (isSignup) {
        setTimeout(() => { window.location.href = "/"; }, 1500);
      } else {
        setTimeout(() => router.replace("/"), 1500);
      }
    } catch (err: unknown) {
      const code = (err as { code?: string }).code;
      if (code === "auth/invalid-custom-token") {
        setStatus("error");
        setMessage("Sign-in failed. Please request a new link.");
      } else {
        setStatus("error");
        setMessage("Sign-in failed. Please try again.");
      }
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

          {status === "processing" && (
            <>
              <div className="w-16 h-16 rounded-2xl bg-blue-50 flex items-center justify-center mx-auto mb-5">
                <div className="w-7 h-7 border-2 border-blue-600 border-t-transparent rounded-full animate-spin" />
              </div>
              <h2 className="text-lg font-black text-gray-900 mb-2">Signing You In</h2>
              <p className="text-sm text-gray-900">Please wait a moment...</p>
            </>
          )}

          {status === "success" && (
            <>
              <div className="flex items-center justify-center mx-auto mb-5">
                <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#16a34a" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10"/>
                  <polyline points="9 12 11.5 14.5 15.5 9.5"/>
                </svg>
              </div>
              <h2 className="text-xl font-black text-gray-900 mb-3">Signed In</h2>
              <p className="text-sm text-gray-900">Redirecting to your dashboard...</p>
            </>
          )}

          {status === "error" && (
            <>
              <div className="w-16 h-16 rounded-2xl bg-red-50 flex items-center justify-center mx-auto mb-5">
                <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#dc2626" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10"/>
                  <line x1="15" y1="9" x2="9" y2="15"/>
                  <line x1="9" y1="9" x2="15" y2="15"/>
                </svg>
              </div>
              <h2 className="text-lg font-black text-gray-900 mb-2">Sign-In Failed</h2>
              <p className="text-sm text-gray-900 mb-6">{message}</p>
              <Link
                href="/login"
                className="block w-full py-3 bg-blue-600 text-white font-black text-sm rounded-xl hover:bg-blue-700 transition-colors tracking-wide"
              >
                Try Again
              </Link>
            </>
          )}

        </div>
      </div>
    </div>
  );
}

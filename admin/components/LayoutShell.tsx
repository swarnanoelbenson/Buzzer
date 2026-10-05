"use client";
import { usePathname, useRouter } from "next/navigation";
import { useState, useCallback, useEffect } from "react";
import { signOut } from "firebase/auth";
import { doc, onSnapshot } from "firebase/firestore";
import { auth, db } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
import { useIdleTimeout } from "@/hooks/useIdleTimeout";
import Sidebar from "./Sidebar";
import TopNav from "./TopNav";
import IdleWarningModal from "./IdleWarningModal";
import ConcurrentSessionModal from "./ConcurrentSessionModal";

const AUTH_ROUTES = ["/login", "/signup", "/check-email", "/auth-callback"];

const IDLE_MS    = 5 * 60 * 1000;   // 5 minutes until warning
const WARNING_MS = 5 * 60 * 1000;   // 5 minutes in warning before auto sign-out

export default function LayoutShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { user, schoolId } = useAuth();
  const isAuthPage = AUTH_ROUTES.includes(pathname);

  const [showWarning, setShowWarning] = useState(false);
  const [showConcurrentModal, setShowConcurrentModal] = useState(false);

  const handleSignOut = useCallback(async () => {
    setShowWarning(false);
    await signOut(auth);
    router.replace("/login");
  }, [router]);

  const handleWarn = useCallback(() => {
    setShowWarning(true);
  }, []);

  const { resetFromWarning } = useIdleTimeout({
    idleMs: IDLE_MS,
    warningMs: WARNING_MS,
    onWarn: handleWarn,
    onSignOut: handleSignOut,
    enabled: !isAuthPage && !!user,
  });

  const handleStay = useCallback(() => {
    setShowWarning(false);
    resetFromWarning();
  }, [resetFromWarning]);

  // Concurrent session detection — listen to the sessionToken field on the school doc.
  // If it changes to a value that doesn't match what this tab stored on login,
  // another session has started and this one must be signed out.
  useEffect(() => {
    if (!schoolId || !user || isAuthPage) return;

    const storedToken = sessionStorage.getItem("sessionToken");
    if (!storedToken) return;

    const unsub = onSnapshot(doc(db, "schools", schoolId), (snap) => {
      if (!snap.exists()) return;
      const remoteToken = snap.data()?.sessionToken as string | undefined;
      // If the remote token differs from what this tab wrote, another session is active
      if (remoteToken && remoteToken !== storedToken) {
        setShowConcurrentModal(true);
      }
    });

    return unsub;
  }, [schoolId, user, isAuthPage]);

  const handleConcurrentSignOut = useCallback(async () => {
    setShowConcurrentModal(false);
    sessionStorage.removeItem("sessionToken");
    await signOut(auth);
    router.replace("/login");
  }, [router]);

  if (isAuthPage) {
    return <>{children}</>;
  }

  return (
    <>
      <div className="flex flex-col h-screen overflow-hidden">
        {/* TopNav spans full width */}
        <TopNav />
        {/* Below nav: sidebar + main */}
        <div className="flex flex-1 min-h-0 overflow-hidden">
          <Sidebar />
          <main className="flex-1 overflow-auto p-6">
            {children}
          </main>
        </div>
      </div>

      {showWarning && (
        <IdleWarningModal
          warningMs={WARNING_MS}
          onStay={handleStay}
          onSignOut={handleSignOut}
        />
      )}

      {showConcurrentModal && (
        <ConcurrentSessionModal onSignOut={handleConcurrentSignOut} />
      )}
    </>
  );
}

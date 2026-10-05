"use client";
import { usePathname, useRouter } from "next/navigation";
import { useState, useCallback } from "react";
import { signOut } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
import { useIdleTimeout } from "@/hooks/useIdleTimeout";
import Sidebar from "./Sidebar";
import TopNav from "./TopNav";
import IdleWarningModal from "./IdleWarningModal";

const AUTH_ROUTES = ["/login", "/signup", "/check-email", "/auth-callback"];

const IDLE_MS    = 5 * 60 * 1000;   // 5 minutes until warning
const WARNING_MS = 5 * 60 * 1000;   // 5 minutes in warning before auto sign-out

export default function LayoutShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { user } = useAuth();
  const isAuthPage = AUTH_ROUTES.includes(pathname);

  const [showWarning, setShowWarning] = useState(false);

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
    </>
  );
}

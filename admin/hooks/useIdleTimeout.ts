"use client";
import { useEffect, useRef, useCallback } from "react";

const ACTIVITY_EVENTS = [
  "mousemove", "mousedown", "keydown", "touchstart", "scroll", "click",
] as const;

interface UseIdleTimeoutOptions {
  /** Milliseconds of inactivity before showing the warning. Default: 5 min */
  idleMs?: number;
  /** Milliseconds after warning before auto sign-out. Default: 5 min */
  warningMs?: number;
  onWarn: () => void;
  onSignOut: () => void;
  /** Call this to reset the timer from outside (e.g. when user acts in modal) */
  enabled?: boolean;
}

export function useIdleTimeout({
  idleMs = 5 * 60 * 1000,
  warningMs = 5 * 60 * 1000,
  onWarn,
  onSignOut,
  enabled = true,
}: UseIdleTimeoutOptions) {
  const idleTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const signOutTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const isWarningRef = useRef(false);

  const clearTimers = useCallback(() => {
    if (idleTimer.current) clearTimeout(idleTimer.current);
    if (signOutTimer.current) clearTimeout(signOutTimer.current);
  }, []);

  const startIdleTimer = useCallback(() => {
    clearTimers();
    isWarningRef.current = false;
    idleTimer.current = setTimeout(() => {
      isWarningRef.current = true;
      onWarn();
      signOutTimer.current = setTimeout(() => {
        onSignOut();
      }, warningMs);
    }, idleMs);
  }, [clearTimers, idleMs, warningMs, onWarn, onSignOut]);

  // Called when user acts during the warning — dismisses and resets
  const resetFromWarning = useCallback(() => {
    isWarningRef.current = false;
    startIdleTimer();
  }, [startIdleTimer]);

  useEffect(() => {
    if (!enabled) return;

    startIdleTimer();

    const handleActivity = () => {
      if (!isWarningRef.current) {
        // Normal activity — just reset the idle timer
        startIdleTimer();
      }
      // If warning is shown, activity is handled by the modal's "Stay signed in" button
    };

    ACTIVITY_EVENTS.forEach(e => window.addEventListener(e, handleActivity, { passive: true }));

    return () => {
      clearTimers();
      ACTIVITY_EVENTS.forEach(e => window.removeEventListener(e, handleActivity));
    };
  }, [enabled, startIdleTimer, clearTimers]);

  return { resetFromWarning };
}

"use client";
import { createContext, useContext, useEffect, useState, ReactNode } from "react";
import { onAuthStateChanged, User } from "firebase/auth";
import { collection, getDocs, query, where } from "firebase/firestore";
import { auth, db } from "./firebase";

interface AuthContextValue {
  user: User | null;
  loading: boolean;
  schoolName: string;
  schoolId: string;
}

const AuthContext = createContext<AuthContextValue>({ user: null, loading: true, schoolName: "", schoolId: "" });

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [schoolName, setSchoolName] = useState("");
  const [schoolId, setSchoolId] = useState("");

  useEffect(() => {
    // Tab-session guard: a tab is considered "authenticated" only if it has a sessionToken
    // in sessionStorage — meaning it either completed a login (auth-callback) or was an
    // already-open tab at the time of login (sessionStorage persists across refreshes but
    // not across tab closes or new tab opens).
    //
    // If a new tab is opened (no sessionToken) and Firebase reports a user (because auth
    // state is shared via IndexedDB across tabs), we sign out only within this tab's
    // local state — we do NOT call signOut(auth) globally, which would kill other tabs.
    const hasTabSession = typeof window !== "undefined" && !!sessionStorage.getItem("sessionToken");

    const unsub = onAuthStateChanged(auth, async (u) => {
      // If this tab has no session token but Firebase reports a user, this tab was opened
      // fresh (new tab or after tab close). Don't authenticate this tab — redirect to login.
      if (!hasTabSession && u) {
        // Sign out only locally: clear state without calling global signOut.
        setUser(null);
        setSchoolName("");
        setSchoolId("");
        setLoading(false);
        return;
      }

      setUser(u);
      if (u) {
        // Fetch the school associated with this admin
        const snap = await getDocs(
          query(collection(db, "schools"), where("adminUid", "==", u.uid))
        );
        if (!snap.empty) {
          setSchoolName(snap.docs[0].data().schoolName as string);
          setSchoolId(snap.docs[0].id);
        } else {
          setSchoolName("");
          setSchoolId("");
        }
      } else {
        setSchoolName("");
        setSchoolId("");
      }
      setLoading(false);
    });
    return unsub;
  }, []);

  return (
    <AuthContext.Provider value={{ user, loading, schoolName, schoolId }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}

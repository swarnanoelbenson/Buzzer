"use client";
import { createContext, useContext, useEffect, useState, ReactNode } from "react";
import { onAuthStateChanged, signOut, User } from "firebase/auth";
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
    // Tab-close logout: sessionStorage is wiped when the tab is closed (not on refresh).
    // If the tab was closed while logged in, Firebase persists the token but sessionStorage
    // is empty — sign the user out immediately so they can't resume the session.
    if (typeof window !== "undefined" && !sessionStorage.getItem("tabOpen")) {
      // Mark this tab as open
      sessionStorage.setItem("tabOpen", "1");
      // If Firebase still has a user from a previous closed tab, sign them out
      if (auth.currentUser) {
        signOut(auth).catch(() => {});
      }
    }

    const unsub = onAuthStateChanged(auth, async (u) => {
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

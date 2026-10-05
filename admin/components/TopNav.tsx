"use client";
import Image from "next/image";
import { usePathname, useRouter } from "next/navigation";
import { signOut } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";

const subtitles: Record<string, string> = {
  "/":                   "Dashboard",
  "/drivers":            "Drivers",
  "/students":           "Students",
  "/students/add":       "Add Student",
  "/students/modify":    "Modify Student",
  "/students/remove":    "Remove Student",
  "/schedule":           "Schedule",
  "/schedule/add":       "Add Schedule",
  "/schedule/modify":    "Modify Schedule",
  "/schedule/remove":    "Remove Schedule",
  "/logs/driver":        "Driver Log",
  "/logs/student":       "Student Log",
  "/logs/admin":         "Admin Log",
  "/logs/route":         "Route Log",
};


export default function TopNav() {
  const pathname = usePathname();
  const router = useRouter();
  const { user } = useAuth();

  // Match subtitle — for /logs/route/* sub-paths use Route Log
  const subtitle = (() => {
    for (const [key, val] of Object.entries(subtitles)) {
      if (pathname === key || pathname.startsWith(key + "/")) return val;
    }
    return "Admin";
  })();

  const handleSignOut = async () => {
    await signOut(auth);
    router.replace("/login");
  };

  // Display name: email prefix or displayName
  const displayName = user?.displayName ?? user?.email?.split("@")[0] ?? "Admin";
  const initials = displayName.charAt(0).toUpperCase();

  return (
    <header className="h-16 bg-blue-600 flex items-center px-6 gap-5 flex-shrink-0 shadow-sm w-full">
      {/* Brand logo + wordmark */}
      <div className="flex items-center flex-shrink-0">
        <Image
          src="/busmate-logo-website.png"
          alt="BusMate"
          height={36}
          width={36}
          className="object-contain"
          style={{ maxHeight: 36, width: "auto" }}
        />
        <span className="ml-2 text-white font-black text-xl tracking-widest uppercase">BusMate</span>
      </div>

      {/* Divider */}
      <div className="w-px h-6 bg-white/30" />

      {/* Current page */}
      <span className="text-white text-base font-bold">{subtitle}</span>

      <div className="flex-1" />

      {/* User badge + sign out */}
      {user && (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-white/20 flex items-center justify-center text-white text-sm font-black flex-shrink-0">
            {initials}
          </div>
          <div className="flex flex-col items-start leading-none">
            <span className="text-white font-black text-sm">{displayName}</span>
            <span className="text-white text-[10px] font-bold tracking-wide">Admin</span>
          </div>
          <button
            onClick={handleSignOut}
            className="ml-2 px-3 py-1.5 bg-white/10 hover:bg-white/20 text-white text-[11px] font-black tracking-widest rounded-lg transition-colors"
          >
            SIGN OUT
          </button>
        </div>
      )}
    </header>
  );
}

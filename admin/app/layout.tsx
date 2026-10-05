import type { Metadata } from "next";
import "./globals.css";
import Sidebar from "@/components/Sidebar";
import TopNav from "@/components/TopNav";
import { AuthProvider } from "@/lib/auth-context";
import AuthGuard from "@/components/AuthGuard";
import LayoutShell from "@/components/LayoutShell";

export const metadata: Metadata = {
  title: "BusMate Admin",
  description: "School bus management platform",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-gray-50 text-gray-900 antialiased">
        <AuthProvider>
          <AuthGuard>
            <LayoutShell>{children}</LayoutShell>
          </AuthGuard>
        </AuthProvider>
      </body>
    </html>
  );
}

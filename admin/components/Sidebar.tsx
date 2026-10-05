"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { useAuth } from "@/lib/auth-context";

const sections = [
  {
    label: "DRIVERS",
    base: "/drivers",
    href: "/drivers",
    cards: [],
  },
  {
    label: "STUDENTS",
    base: "/students",
    href: "/students",
    cards: [],
  },
  {
    label: "SCHEDULE",
    base: "/schedule",
    href: "/schedule",
    cards: [],
  },
  {
    label: "VIEW LOG",
    base: "/logs",
    cards: [
      { label: "DRIVER LOG",   href: "/logs/driver" },
      { label: "STUDENT LOG",  href: "/logs/student" },
      { label: "ADMIN LOG",    href: "/logs/admin" },
      { label: "ROUTE LOG",    href: "/logs/route" },
    ],
  },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { schoolName } = useAuth();

  const initialOpen = sections
    .filter(s => pathname === "/" ? false : pathname.startsWith(s.base))
    .map(s => s.label);

  const [openSections, setOpenSections] = useState<string[]>(initialOpen);

  const toggle = (label: string) => {
    setOpenSections(prev =>
      prev.includes(label) ? prev.filter(l => l !== label) : [...prev, label]
    );
  };

  return (
    <aside className="w-60 bg-white border-r border-gray-100 flex flex-col flex-shrink-0 overflow-hidden">
      {/* Admin Console header */}
      <div className="px-5 py-4 border-b border-gray-100 flex-shrink-0">
        <span className="text-base font-black tracking-widest text-gray-900 uppercase block leading-tight">{schoolName || "BusMate"}</span>
        <span className="text-[11px] font-bold tracking-widest text-gray-900 uppercase">Admin Console</span>
      </div>

      {/* Dashboard */}
      <div className="px-3 pt-3 pb-1 flex-shrink-0">
        <Link
          href="/"
          className={`flex items-center px-3 py-2.5 rounded-lg text-[13px] font-black tracking-widest transition-colors ${
            pathname === "/"
              ? "bg-blue-600 text-white"
              : "text-gray-900 hover:bg-gray-50"
          }`}
        >
          DASHBOARD
        </Link>
      </div>

      {/* Accordion sections — always-visible scrollbar */}
      <nav
        className="flex-1 px-3 pb-6 space-y-0.5 overflow-y-scroll"
        style={{ scrollbarWidth: "thin", scrollbarColor: "#d1d5db transparent" }}
      >
        {sections.map((section) => {
          const isOpen = openSections.includes(section.label);
          const isSectionActive = pathname.startsWith(section.base);

          return (
            <div key={section.label}>
              {"href" in section && section.href ? (
                /* Direct link — no accordion */
                <Link
                  href={section.href}
                  className={`w-full flex items-center px-3 py-2.5 rounded-lg text-[13px] font-black tracking-widest transition-colors ${
                    isSectionActive
                      ? "bg-blue-600 text-white"
                      : "text-gray-900 hover:bg-gray-50"
                  }`}
                >
                  {section.label}
                </Link>
              ) : (
                <>
                  {/* Accordion trigger */}
                  <button
                    onClick={() => toggle(section.label)}
                    className={`w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-[13px] font-black tracking-widest transition-colors ${
                      isSectionActive
                        ? "bg-blue-600 text-white"
                        : "text-gray-900 hover:bg-gray-50"
                    }`}
                  >
                    <span>{section.label}</span>
                    <svg
                      width="11" height="11" viewBox="0 0 24 24" fill="none"
                      stroke="currentColor" strokeWidth="3"
                      strokeLinecap="round" strokeLinejoin="round"
                      className={`transition-transform duration-200 ${isOpen ? "rotate-180" : ""}`}
                    >
                      <polyline points="6 9 12 15 18 9" />
                    </svg>
                  </button>

                  {/* Dropdown items */}
                  {isOpen && (
                    <div className="mt-0.5 mb-1 ml-2 pl-3 border-l border-gray-100 space-y-0.5">
                      {section.cards.map((card) => {
                        const isActive = card.href === section.base
                          ? pathname === section.base
                          : pathname === card.href || pathname.startsWith(card.href + "/");
                        return (
                          <Link
                            key={card.href}
                            href={card.href}
                            className={`flex items-center gap-2 px-2 py-2 rounded-md text-[11px] font-bold tracking-widest transition-colors ${
                              isActive
                                ? "text-blue-600 bg-blue-50"
                                : "text-gray-800 hover:text-gray-900 hover:bg-gray-50"
                            }`}
                          >
                            <span className={`w-1.5 h-1.5 rounded-full flex-shrink-0 ${isActive ? "bg-blue-500" : "bg-gray-300"}`} />
                            {card.label}
                          </Link>
                        );
                      })}
                    </div>
                  )}
                </>
              )}
            </div>
          );
        })}
      </nav>
    </aside>
  );
}

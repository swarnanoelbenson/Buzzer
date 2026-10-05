import Link from "next/link";

interface Breadcrumb { label: string; href?: string }

export default function PageHeader({
  title, subtitle, breadcrumbs,
}: {
  title: string;
  subtitle?: string;
  breadcrumbs?: Breadcrumb[];
  accent?: "blue" | "green" | "orange" | "purple" | "gray";
}) {
  return (
    <div className="mb-7">
      {/* Breadcrumbs */}
      {breadcrumbs && (
        <div className="flex items-center gap-1.5 text-[10px] font-bold tracking-widest uppercase mb-3">
          {breadcrumbs.map((b, i) => (
            <span key={i} className="flex items-center gap-1.5">
              {i > 0 && <span className="text-blue-400">/</span>}
              {b.href ? (
                <Link href={b.href} className="text-blue-500 hover:text-blue-700 transition-colors">{b.label}</Link>
              ) : (
                <span className="text-blue-600 underline underline-offset-2">{b.label}</span>
              )}
            </span>
          ))}
        </div>
      )}
      {/* Title */}
      <h1 className="text-xs font-bold tracking-widest text-gray-400 uppercase mb-1">{title}</h1>
      {subtitle && <p className="text-2xl font-bold text-gray-900 tracking-tight">{subtitle}</p>}
    </div>
  );
}

"use client";

interface PhoneInputProps {
  value: string; // just the 9 digits (without +61)
  onChange: (digits: string) => void;
  className?: string;
  required?: boolean;
  placeholder?: string;
}

/**
 * A phone input that displays a fixed "+61" prefix badge alongside a 9-digit number field.
 * `value` and `onChange` operate only on the subscriber digits (e.g. "430040000").
 * The full E.164 number is assembled by the caller as "+61" + value before saving.
 */
export default function PhoneInput({ value, onChange, className, required, placeholder = "430 040 000" }: PhoneInputProps) {
  return (
    <div className="flex items-stretch">
      <span className="inline-flex items-center px-3 bg-gray-100 border border-r-0 border-gray-200 rounded-l-xl text-sm font-semibold text-gray-500 select-none">
        +61
      </span>
      <input
        type="tel"
        inputMode="numeric"
        pattern="[0-9]{9}"
        maxLength={9}
        required={required}
        value={value}
        onChange={e => {
          // Allow only digits, strip everything else
          const digits = e.target.value.replace(/\D/g, "").slice(0, 9);
          onChange(digits);
        }}
        placeholder={placeholder}
        className={`flex-1 min-w-0 rounded-l-none rounded-r-xl ${className ?? ""}`}
      />
    </div>
  );
}

/**
 * Strip the "+61" country prefix from a full phone number and return only the subscriber digits.
 * Handles "+61430040000" → "430040000" and "0430040000" → "430040000".
 * Returns the raw value unchanged if it doesn't match either pattern.
 */
export function stripPrefix(phone: string): string {
  if (phone.startsWith("+61")) return phone.slice(3);
  if (phone.startsWith("0")) return phone.slice(1);
  return phone;
}

"use client";
import Image from "next/image";
import { useState } from "react";
import { collection, query, where, getDocs } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useRouter } from "next/navigation";
import Link from "next/link";

const FIELD = "w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 text-base text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 transition";

// Minimum age for administrator accounts (years). Mirrors ToS §3 and privacy policy §6.
const MIN_ADMIN_AGE = 21;

function maxDateOfBirth(): string {
  const d = new Date();
  d.setFullYear(d.getFullYear() - MIN_ADMIN_AGE);
  return d.toISOString().split("T")[0];
}

const AU_STATES = ["ACT", "NSW", "NT", "QLD", "SA", "TAS", "VIC", "WA"];

export default function SignupPage() {
  const router = useRouter();

  // School details
  const [schoolName, setSchoolName] = useState("");
  const [schoolStreet1, setSchoolStreet1] = useState("");
  const [schoolStreet2, setSchoolStreet2] = useState("");
  const [schoolSuburb, setSchoolSuburb] = useState("");
  const [schoolState, setSchoolState] = useState("");
  const [schoolPostcode, setSchoolPostcode] = useState("");
  const [schoolPhone, setSchoolPhone] = useState("");
  const [schoolEmail, setSchoolEmail] = useState("");

  // Primary administrator details
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [adminEmail, setAdminEmail] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState("");

  // Form state
  const [agreedToTerms, setAgreedToTerms] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSignup = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (!schoolName.trim()) { setError("Please enter the school name."); return; }
    if (!schoolStreet1.trim()) { setError("Please enter the school street address."); return; }
    if (!schoolSuburb.trim()) { setError("Please enter the suburb/city."); return; }
    if (!schoolState) { setError("Please select the state."); return; }
    if (!schoolPostcode.trim()) { setError("Please enter the postcode."); return; }
    if (!/^\d{4}$/.test(schoolPostcode.trim())) { setError("Postcode must be 4 digits."); return; }
    if (!schoolPhone.trim()) { setError("Please enter the school phone number."); return; }
    if (!schoolEmail.trim()) { setError("Please enter the school email address."); return; }
    if (!firstName.trim()) { setError("Please enter the administrator's first name."); return; }
    if (!lastName.trim()) { setError("Please enter the administrator's last name."); return; }
    if (!adminEmail.trim()) { setError("Please enter the administrator's email address."); return; }

    // Age validation — administrator accounts require a minimum age of 21 years
    if (!dateOfBirth) { setError("Please enter your date of birth."); return; }
    const dob = new Date(dateOfBirth);
    const today = new Date();
    const age = today.getFullYear() - dob.getFullYear() -
      (today < new Date(today.getFullYear(), dob.getMonth(), dob.getDate()) ? 1 : 0);
    if (age < MIN_ADMIN_AGE) {
      setError(`You must be at least ${MIN_ADMIN_AGE} years old to create an administrator account.`);
      return;
    }

    if (!agreedToTerms) {
      setError("You must agree to the Terms of Service to continue.");
      return;
    }

    setLoading(true);

    try {
      const schoolsRef = collection(db, "schools");

      // Check for duplicate school name (case-insensitive)
      const nameSnap = await getDocs(
        query(schoolsRef, where("schoolNameLower", "==", schoolName.trim().toLowerCase()))
      );
      if (!nameSnap.empty) {
        setError("A school with this name is already registered.");
        setLoading(false);
        return;
      }

      // Check for duplicate admin email
      const emailSnap = await getDocs(
        query(schoolsRef, where("email", "==", adminEmail.trim().toLowerCase()))
      );
      if (!emailSnap.empty) {
        setError("This administrator email is already registered.");
        setLoading(false);
        return;
      }

      const adminName = `${firstName.trim()} ${lastName.trim()}`;

      const pendingSignup = {
        schoolName: schoolName.trim(),
        schoolNameLower: schoolName.trim().toLowerCase(),
        schoolAddress: {
          street1: schoolStreet1.trim(),
          street2: schoolStreet2.trim(),
          suburb: schoolSuburb.trim(),
          state: schoolState,
          postcode: schoolPostcode.trim(),
        },
        schoolPhone: schoolPhone.trim(),
        schoolEmail: schoolEmail.trim().toLowerCase(),
        adminFirstName: firstName.trim(),
        adminLastName: lastName.trim(),
        adminName,
        email: adminEmail.trim().toLowerCase(),
        dateOfBirth,
        isSignup: true,
      };

      const res = await fetch("/api/admin-signin-link/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: adminEmail.trim().toLowerCase(),
          pendingSignup,
          origin: window.location.origin,
        }),
      });

      if (!res.ok) {
        const data = await res.json();
        setError(data.error ?? "Sign up failed. Please try again.");
        setLoading(false);
        return;
      }

      router.replace(
        `/check-email?email=${encodeURIComponent(adminEmail.trim())}&school=${encodeURIComponent(schoolName.trim())}`
      );
    } catch {
      setError("Sign up failed. Please try again.");
    }

    setLoading(false);
  };

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4 py-12">
      <div className="w-full max-w-lg">
        {/* Logo */}
        <div className="flex flex-col items-center mb-8">
          <div className="mb-4">
            <Image src="/busmate-logo-website.png" alt="BusMate" width={180} height={48} className="object-contain" />
          </div>
          <p className="text-xl font-black tracking-widest text-gray-900 uppercase mt-2">Admin Console</p>
        </div>

        {/* Card */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-8">
          <h2 className="text-lg font-black text-gray-900 mb-1">Create Admin Account</h2>
          <p className="text-sm text-gray-500 mb-6">Register your school to get started.</p>

          {error && (
            <div className="mb-4 px-4 py-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl">
              {error}
            </div>
          )}

          <form onSubmit={handleSignup} className="space-y-6">

            {/* School Details */}
            <div>
              <p className="text-xs font-black tracking-widest text-gray-400 uppercase mb-3">School Details</p>
              <div className="space-y-3">
                <div>
                  <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">School Name</label>
                  <input
                    type="text" required autoComplete="organization"
                    className={FIELD}
                    placeholder="e.g. St Mary's College"
                    value={schoolName}
                    onChange={e => setSchoolName(e.target.value)}
                  />
                </div>
                <div>
                  <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">Street Address</label>
                  <input
                    type="text" required autoComplete="street-address"
                    className={FIELD}
                    placeholder="Street line 1"
                    value={schoolStreet1}
                    onChange={e => setSchoolStreet1(e.target.value)}
                  />
                </div>
                <div>
                  <input
                    type="text" autoComplete="address-line2"
                    className={FIELD}
                    placeholder="Street line 2 (optional)"
                    value={schoolStreet2}
                    onChange={e => setSchoolStreet2(e.target.value)}
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div className="col-span-2 sm:col-span-1">
                    <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">Suburb / City</label>
                    <input
                      type="text" required autoComplete="address-level2"
                      className={FIELD}
                      placeholder="e.g. Richmond"
                      value={schoolSuburb}
                      onChange={e => setSchoolSuburb(e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">State</label>
                    <select
                      required
                      className={FIELD}
                      value={schoolState}
                      onChange={e => setSchoolState(e.target.value)}
                    >
                      <option value="">Select</option>
                      {AU_STATES.map(s => <option key={s} value={s}>{s}</option>)}
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">Postcode</label>
                    <input
                      type="text" required inputMode="numeric" pattern="\d{4}" maxLength={4}
                      className={FIELD}
                      placeholder="3000"
                      value={schoolPostcode}
                      onChange={e => setSchoolPostcode(e.target.value.replace(/\D/g, ""))}
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">School Phone Number</label>
                  <input
                    type="tel" required autoComplete="tel"
                    className={FIELD}
                    placeholder="(03) 9000 0000"
                    value={schoolPhone}
                    onChange={e => setSchoolPhone(e.target.value)}
                  />
                </div>
                <div>
                  <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">School Email Address</label>
                  <input
                    type="email" required autoComplete="email"
                    className={FIELD}
                    placeholder="info@school.edu.au"
                    value={schoolEmail}
                    onChange={e => setSchoolEmail(e.target.value)}
                  />
                </div>
              </div>
            </div>

            {/* Primary Administrator */}
            <div>
              <p className="text-xs font-black tracking-widest text-gray-400 uppercase mb-3">Primary Administrator</p>
              <div className="space-y-3">
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">First Name</label>
                    <input
                      type="text" required autoComplete="given-name"
                      className={FIELD}
                      placeholder="First name"
                      value={firstName}
                      onChange={e => setFirstName(e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-black tracking-widests text-gray-900 uppercase mb-1.5">Last Name</label>
                    <input
                      type="text" required autoComplete="family-name"
                      className={FIELD}
                      placeholder="Last name"
                      value={lastName}
                      onChange={e => setLastName(e.target.value)}
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-xs font-black tracking-widest text-gray-900 uppercase mb-1.5">Administrator Email Address</label>
                  <input
                    type="email" required autoComplete="email"
                    className={FIELD}
                    placeholder="admin@school.edu.au"
                    value={adminEmail}
                    onChange={e => setAdminEmail(e.target.value)}
                  />
                </div>
                <div>
                  <label className="block text-xs font-black tracking-widests text-gray-900 uppercase mb-1.5">
                    Date of Birth
                    <span className="ml-1 text-gray-400 font-normal normal-case tracking-normal text-xs">(must be 21+)</span>
                  </label>
                  <input
                    type="date" required
                    className={FIELD}
                    max={maxDateOfBirth()}
                    value={dateOfBirth}
                    onChange={e => setDateOfBirth(e.target.value)}
                  />
                </div>
              </div>
            </div>

            {/* Terms of Service */}
            <div className="flex items-start gap-3 pt-1">
              <input
                id="terms"
                type="checkbox"
                required
                checked={agreedToTerms}
                onChange={e => setAgreedToTerms(e.target.checked)}
                className="mt-0.5 h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500 cursor-pointer"
              />
              <label htmlFor="terms" className="text-sm text-gray-600 leading-snug cursor-pointer">
                I agree to the{" "}
                <a
                  href="https://busmate.com.au/terms"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-blue-600 font-bold hover:underline"
                >
                  Terms of Service
                </a>
                {" "}and{" "}
                <a
                  href="https://busmate.com.au/privacy"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-blue-600 font-bold hover:underline"
                >
                  Privacy Policy
                </a>
                .
              </label>
            </div>

            <button
              type="submit" disabled={loading}
              className="w-full py-3 bg-blue-600 text-white font-black text-base rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors tracking-wide"
            >
              {loading ? "Creating account..." : "Sign Up"}
            </button>
          </form>

          <p className="mt-5 text-center text-sm text-gray-900">
            Already have an account?{" "}
            <Link href="/login" className="text-blue-600 font-bold hover:underline">
              Sign In
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}

import type { Timestamp } from "firebase/firestore";

/** Converts a Firestore Timestamp or Date to a JS Date. */
export function firestoreToDate(value: Timestamp | Date | null | undefined): Date {
  if (!value) return new Date();
  if (value instanceof Date) return value;
  // Firestore Timestamp has toDate()
  if (typeof (value as Timestamp).toDate === "function") {
    return (value as Timestamp).toDate();
  }
  return new Date();
}

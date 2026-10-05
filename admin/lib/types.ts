export interface Driver {
  id: string;
  name: string;
  phone: string;
  age: number;
  gender: string;
  address: string;
  childrenCheck: string;
  driversLicense: string;
  licenseExpiry: Date;
  isActive: boolean;
  createdAt: Date;
}

export interface ParentContact {
  name: string;
  phone: string;
  canAccess: boolean;     // whether this parent can log in and view the student
  relationship?: string;  // e.g. "Mother", "Father", "Guardian"
}

export interface Student {
  id: string;
  name: string;
  grade: string;
  stopAddressAM: string;  // morning pickup stop
  stopAddressPM: string;  // afternoon dropoff stop
  routeId: string;
  scheduledPickupTime: string;
  scheduledDropoffTime: string;
  authorisedParentIds: string[];
  parents?: ParentContact[];
  phone?: string;         // student's phone number — used for SMS OTP login
  isActive: boolean;
  createdAt: Date;
}

export interface Parent {
  id: string;
  name: string;
  relationship: string;
  phone: string;          // phone number — used for SMS OTP login
  childIds: string[];
  isActive: boolean;
  profileCompleted: boolean;
  createdAt: Date;
}

export interface Route {
  id: string;
  name: string;
  driverId: string;
  term: number;
  year: number;
  scheduledDays: string[];
  startDate: Date;
  endDate: Date;
  studentIds: string[];
  isActive: boolean;
}

export interface Trip {
  id: string;
  routeId: string;
  driverId: string;
  date: Date;
  type: "pickup" | "dropoff";
  status: "scheduled" | "inProgress" | "completed" | "cancelled";
  studentRecords: StudentTripRecord[];
  startedAt?: Date;
  completedAt?: Date;
}

export interface StudentTripRecord {
  id: string;
  studentName: string;
  stopAddressAM: string;
  stopAddressPM: string;
  status: "pending" | "onBus" | "offBus" | "absent";
  timestamp?: Date;
}

// Written by the parent app; read by admin console and driver app
export interface PassengerNote {
  id: string;
  studentId: string;
  studentName: string;
  routeId: string;
  routeName: string;
  type: "pickup" | "dropoff";   // which trip the note applies to
  noteText: string;
  fromDate: Date;
  toDate: Date;
  createdAt: Date;
  createdByParentId: string;
  createdByParentName: string;
}

export interface ActivityLog {
  id: string;
  actorId: string;
  actorName: string;
  actorRole: string;
  action: string;
  timestamp: Date;
  metadata?: Record<string, string>;
}

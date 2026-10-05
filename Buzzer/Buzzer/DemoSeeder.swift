//
//  DemoSeeder.swift
//  Buzzer
//
//  One-time utility to populate Firestore with demo data using a single
//  batch write — fast, no Auth calls, no network hangs.
//
//  HOW TO USE:
//  1. Open the app → tap "Developer Menu" at the bottom of the login screen.
//  2. Tap "Seed Demo Data" — completes in under 3 seconds.
//
//  DEMO DRIVER CREDENTIALS
//  ─────────────────────────────────────────────────────
//  Name: John Mitchell    Phone: +61412345001
//  Name: Sarah Thompson   Phone: +61412345002
//  Name: David Nguyen     Phone: +61412345003
//
//  Add test numbers in Firebase Console → Authentication →
//  Sign-in method → Phone → Phone numbers for testing:
//    +61412345001  OTP: 123001
//    +61412345002  OTP: 123002
//    +61412345003  OTP: 123003
//
//  DEMO PARENT CREDENTIALS
//  ─────────────────────────────────────────────────────
//  Username: parent.emma   Password: Demo@1234   (Liam's mother)
//  Username: parent.james  Password: Demo@1234   (Liam's father)
//  Username: parent.sofia  Password: Demo@1234   (Mia & Noah's mother)
//
//  NOTE: Parent Auth accounts are created automatically on first login.
//  The Firestore docs use fixed IDs for demo purposes.
//

import Foundation
import FirebaseFirestore

@MainActor
class DemoSeeder {

    static let shared = DemoSeeder()
    private let db = Firestore.db

    // Fixed demo document IDs
    private let driverIds   = ["driver_john", "driver_sarah", "driver_david"]
    private let studentIds  = ["student_liam", "student_mia", "student_noah"]
    private let parentIds   = ["parent_emma", "parent_james", "parent_sofia"]
    private let routeId     = "route_demo_001"

    // MARK: - Public entry point

    /// Writes all demo data in a single Firestore batch — no Auth calls, no hangs.
    func seedAll() async throws {
        print("🌱 Starting seed...")

        let batch = db.batch()

        seedDrivers(into: batch)
        print("  → Drivers prepared")
        seedStudents(into: batch)
        print("  → Students prepared")
        seedParents(into: batch)
        print("  → Parents prepared")
        seedRoute(into: batch)
        print("  → Route prepared")
        seedTrips(into: batch)
        print("  → Trips prepared")

        print("  → Committing batch to Firestore...")

        // Wrap in a task with timeout so it doesn't hang forever
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await batch.commit()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(15))
                throw NSError(
                    domain: "DemoSeeder",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Timed out after 15 seconds. Check Firestore rules — make sure 'allow read, write: if true' is published in Firebase Console."]
                )
            }
            // Return as soon as either the commit succeeds or timeout fires
            try await group.next()
            group.cancelAll()
        }

        print("✅ Demo data seeded successfully.")
    }

    // MARK: - Drivers

    private func seedDrivers(into batch: WriteBatch) {
        let now = Timestamp(date: Date())
        let expiry = Timestamp(date: Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date())

        let drivers: [(id: String, data: [String: Any])] = [
            (driverIds[0], [
                "name": "John Mitchell",
                "phone": "+61412345001",
                "age": 52,
                "gender": "Male",
                "address": "14 Wattle St, Parramatta NSW 2150",
                "childrenCheck": "WWC1234567E",
                "driversLicense": "NSW12345678",
                "licenseExpiry": expiry,
                "busRegistration": "BUS001",
                "imageUrl": "",
                "isActive": true,
                "createdAt": now
            ]),
            (driverIds[1], [
                "name": "Sarah Thompson",
                "phone": "+61412345002",
                "age": 47,
                "gender": "Female",
                "address": "88 Rose Ave, Blacktown NSW 2148",
                "childrenCheck": "WWC7654321E",
                "driversLicense": "NSW87654321",
                "licenseExpiry": expiry,
                "busRegistration": "BUS002",
                "imageUrl": "",
                "isActive": true,
                "createdAt": now
            ]),
            (driverIds[2], [
                "name": "David Nguyen",
                "phone": "+61412345003",
                "age": 58,
                "gender": "Male",
                "address": "3 Park Rd, Penrith NSW 2750",
                "childrenCheck": "WWC1122334E",
                "driversLicense": "NSW11223344",
                "licenseExpiry": expiry,
                "busRegistration": "BUS003",
                "imageUrl": "",
                "isActive": true,
                "createdAt": now
            ])
        ]

        for (id, data) in drivers {
            batch.setData(data, forDocument: db.collection("drivers").document(id))
        }
    }

    // MARK: - Students

    private func seedStudents(into batch: WriteBatch) {
        let now = Timestamp(date: Date())

        let students: [(id: String, data: [String: Any])] = [
            (studentIds[0], [
                "name": "Liam Chen",
                "grade": "Year 5",
                "imageUrl": "",
                "phone": "",
                "stopAddress": "12 Oak St, Parramatta NSW 2150",
                "routeId": routeId,
                "scheduledPickupTime": "08:00 AM",
                "scheduledDropoffTime": "03:30 PM",
                "authorisedParentIds": [parentIds[0], parentIds[1]],
                "isActive": true,
                "createdAt": now
            ]),
            (studentIds[1], [
                "name": "Mia Patel",
                "grade": "Year 3",
                "imageUrl": "",
                "phone": "",
                "stopAddress": "45 Maple Dr, Blacktown NSW 2148",
                "routeId": routeId,
                "scheduledPickupTime": "08:10 AM",
                "scheduledDropoffTime": "03:35 PM",
                "authorisedParentIds": [parentIds[2]],
                "isActive": true,
                "createdAt": now
            ]),
            (studentIds[2], [
                "name": "Noah Patel",
                "grade": "Year 6",
                "imageUrl": "",
                "phone": "",
                "stopAddress": "45 Maple Dr, Blacktown NSW 2148",
                "routeId": routeId,
                "scheduledPickupTime": "08:10 AM",
                "scheduledDropoffTime": "03:35 PM",
                "authorisedParentIds": [parentIds[2]],
                "isActive": true,
                "createdAt": now
            ])
        ]

        for (id, data) in students {
            batch.setData(data, forDocument: db.collection("students").document(id))
        }
    }

    // MARK: - Parents
    // These use fixed Firestore IDs. On first login, ParentLoginView will
    // create the Firebase Auth account and link it to this Firestore doc
    // by matching the username field.

    private func seedParents(into batch: WriteBatch) {
        let now = Timestamp(date: Date())

        let parents: [(id: String, data: [String: Any])] = [
            (parentIds[0], [
                "name": "Emma Chen",
                "relationship": "Mother",
                "username": "parent.emma",
                "password": "Demo@1234",       // stored only for demo seeding reference
                "fcmToken": "",
                "childIds": [studentIds[0]],
                "isActive": true,
                "profileCompleted": true,
                "authLinked": false,            // becomes true once Auth account is created
                "createdAt": now
            ]),
            (parentIds[1], [
                "name": "James Chen",
                "relationship": "Father",
                "username": "parent.james",
                "password": "Demo@1234",
                "fcmToken": "",
                "childIds": [studentIds[0]],
                "isActive": true,
                "profileCompleted": true,
                "authLinked": false,
                "createdAt": now
            ]),
            (parentIds[2], [
                "name": "Sofia Patel",
                "relationship": "Mother",
                "username": "parent.sofia",
                "password": "Demo@1234",
                "fcmToken": "",
                "childIds": [studentIds[1], studentIds[2]],
                "isActive": true,
                "profileCompleted": true,
                "authLinked": false,
                "createdAt": now
            ])
        ]

        for (id, data) in parents {
            batch.setData(data, forDocument: db.collection("parents").document(id))
        }
    }

    // MARK: - Route

    private func seedRoute(into batch: WriteBatch) {
        let now = Date()
        let termStart = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: now)) ?? now
        let termEnd   = Calendar.current.date(byAdding: .month, value: 3, to: termStart) ?? now

        let data: [String: Any] = [
            "name": "Route A — Parramatta & Blacktown",
            "driverId": driverIds[0],
            "term": 1,
            "year": Calendar.current.component(.year, from: now),
            "scheduledDays": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
            "startDate": Timestamp(date: termStart),
            "endDate": Timestamp(date: termEnd),
            "studentIds": studentIds,
            "isActive": true,
            "createdAt": Timestamp(date: now)
        ]

        batch.setData(data, forDocument: db.collection("routes").document(routeId))
    }

    // MARK: - Today's Trips

    private func seedTrips(into batch: WriteBatch) {
        let today = Timestamp(date: Calendar.current.startOfDay(for: Date()))

        let studentRecords: [[String: Any]] = [
            ["id": studentIds[0], "studentName": "Liam Chen",  "stopAddress": "12 Oak St, Parramatta NSW 2150",  "status": "pending", "timestamp": NSNull()],
            ["id": studentIds[1], "studentName": "Mia Patel",  "stopAddress": "45 Maple Dr, Blacktown NSW 2148", "status": "pending", "timestamp": NSNull()],
            ["id": studentIds[2], "studentName": "Noah Patel", "stopAddress": "45 Maple Dr, Blacktown NSW 2148", "status": "pending", "timestamp": NSNull()]
        ]

        let pickup: [String: Any] = [
            "routeId": routeId,
            "driverId": driverIds[0],
            "date": today,
            "type": "pickup",
            "status": "scheduled",
            "studentRecords": studentRecords,
            "startedAt": NSNull(),
            "completedAt": NSNull()
        ]

        let dropoff: [String: Any] = [
            "routeId": routeId,
            "driverId": driverIds[0],
            "date": today,
            "type": "dropoff",
            "status": "scheduled",
            "studentRecords": studentRecords,
            "startedAt": NSNull(),
            "completedAt": NSNull()
        ]

        batch.setData(pickup,  forDocument: db.collection("trips").document("trip_demo_pickup_today"))
        batch.setData(dropoff, forDocument: db.collection("trips").document("trip_demo_dropoff_today"))
    }
}

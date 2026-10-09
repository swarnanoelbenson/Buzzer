//
//  FirestoreService.swift
//  Buzzer
//
//  Central service for all Firestore read/write operations.
//

import Foundation
import Observation
import FirebaseFirestore
import FirebaseAuth

@Observable
@MainActor
class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.db

    /// In-memory cache: routeId → route name. Populated on first fetch.
    private var routeNameCache: [String: String] = [:]

    /// Returns the route name for an ID, using cache to avoid repeated Firestore reads.
    func routeName(for routeId: String) async -> String {
        if let cached = routeNameCache[routeId] { return cached }
        if let route = try? await fetchRoute(id: routeId) {
            routeNameCache[routeId] = route.name
            return route.name
        }
        return routeId   // fallback to ID if fetch fails
    }

    // MARK: - Schools

    /// Returns all schools sorted by name — used to populate the school picker on the sign-in screen.
    func fetchSchools() async throws -> [School] {
        let snapshot = try await db.collection("schools").getDocuments()
        return try snapshot.documents
            .map { try $0.data(as: School.self) }
            .sorted { $0.schoolName < $1.schoolName }
    }

    // MARK: - Auth helpers

    /// Looks up a user by email within a school across the three role collections.
    /// Returns the Firestore document ID and whether the account has a password set.
    /// Used during sign-in to determine if the account exists and whether to prompt for password setup.
    func fetchUserByEmail(_ email: String, schoolId: String, role: UserRole) async throws -> (docId: String, passwordSet: Bool) {
        let normalised = email.trimmingCharacters(in: .whitespaces).lowercased()
        let collection: String
        switch role {
        case .driver:  collection = "drivers"
        case .parent:  collection = "parents"
        case .student: collection = "students"
        default:
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid role."])
        }
        let snapshot = try await db.collection(collection)
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("email", isEqualTo: normalised)
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snapshot.documents.first else {
            throw NSError(domain: "Auth", code: 404, userInfo: [NSLocalizedDescriptionKey: "Account not found. Please contact your school admin."])
        }
        let passwordSet = doc.data()["passwordSet"] as? Bool ?? false
        return (docId: doc.documentID, passwordSet: passwordSet)
    }

    /// Marks a user's passwordSet field as true after they complete password setup.
    func setPasswordSet(_ docId: String, role: UserRole) async throws {
        let collection: String
        switch role {
        case .driver:  collection = "drivers"
        case .parent:  collection = "parents"
        case .student: collection = "students"
        default: return
        }
        try await db.collection(collection).document(docId).updateData(["passwordSet": true])
    }

    // MARK: - Drivers

    func fetchAllDrivers(schoolId: String) async throws -> [Driver] {
        let snapshot = try await db.collection("drivers")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Driver.self) }
    }

    func fetchDriver(id: String) async throws -> Driver {
        let doc = try await db.collection("drivers").document(id).getDocument()
        return try doc.data(as: Driver.self)
    }

    // MARK: - Students

    func fetchStudents(for routeId: String, schoolId: String) async throws -> [Student] {
        let snapshot = try await db.collection("students")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("routeId", isEqualTo: routeId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Student.self) }
    }

    func fetchStudents(for parentId: String, childIds: [String]) async throws -> [Student] {
        guard !childIds.isEmpty else { return [] }
        let snapshot = try await db.collection("students")
            .whereField(FieldPath.documentID(), in: childIds)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Student.self) }
    }

    /// Look up a student by their phone number within a school (normalised — last 9 digits compared).
    func fetchStudentByPhone(_ rawPhone: String, schoolId: String) async throws -> Student {
        // Try the exact stored number first, then fall back to suffix matching
        let snapshot = try await db.collection("students")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        let suffix = String(rawPhone.filter(\.isNumber).suffix(9))
        guard let doc = snapshot.documents.first(where: {
            let stored = ($0.data()["phone"] as? String ?? "").filter(\.isNumber)
            return stored.hasSuffix(suffix) && !suffix.isEmpty
        }) else {
            throw NSError(domain: "Auth", code: 404, userInfo: [NSLocalizedDescriptionKey: "Phone number not found in student records."])
        }
        return try doc.data(as: Student.self)
    }

    // MARK: - Parents

    func fetchParent(id: String) async throws -> Parent {
        let doc = try await db.collection("parents").document(id).getDocument()
        return try doc.data(as: Parent.self)
    }

    /// Look up a parent by their phone number within a school (normalised — last 9 digits compared).
    func fetchParentByPhone(_ rawPhone: String, schoolId: String) async throws -> Parent {
        let snapshot = try await db.collection("parents")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        let suffix = String(rawPhone.filter(\.isNumber).suffix(9))
        guard let doc = snapshot.documents.first(where: {
            let stored = ($0.data()["phone"] as? String ?? "").filter(\.isNumber)
            return stored.hasSuffix(suffix) && !suffix.isEmpty
        }) else {
            throw NSError(domain: "Auth", code: 404, userInfo: [NSLocalizedDescriptionKey: "Phone number not found in parent records."])
        }
        return try doc.data(as: Parent.self)
    }

    func updateParentProfile(id: String, name: String, relationship: ParentRelationship) async throws {
        try await db.collection("parents").document(id).updateData([
            "name": name,
            "relationship": relationship.rawValue,
            "profileCompleted": true
        ])
    }

    func updateParentFCMToken(id: String, token: String) async throws {
        try await db.collection("parents").document(id).updateData([
            "fcmToken": token
        ])
    }

    // MARK: - Routes

    func fetchRoutes(for driverId: String, schoolId: String) async throws -> [Route] {
        let snapshot = try await db.collection("routes")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("driverId", isEqualTo: driverId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Route.self) }
    }

    func fetchRoute(id: String) async throws -> Route {
        let doc = try await db.collection("routes").document(id).getDocument()
        return try doc.data(as: Route.self)
    }

    // MARK: - Trips

    /// Fetches today's trips for a specific driver within a school.
    func fetchTodaysTrips(for driverId: String, schoolId: String) async throws -> [Trip] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let snapshot = try await db.collection("trips")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("driverId", isEqualTo: driverId)
            .whereField("date", isGreaterThanOrEqualTo: startOfDay)
            .whereField("date", isLessThan: endOfDay)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Trip.self) }
    }

    /// Fetches today's trips that contain any of the given student IDs (for parent portal).
    func fetchTodaysTrips(forStudentIds studentIds: [String], schoolId: String) async throws -> [Trip] {
        guard !studentIds.isEmpty else { return [] }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Firestore `array-contains-any` supports up to 10 values
        let snapshot = try await db.collection("trips")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("date", isGreaterThanOrEqualTo: startOfDay)
            .whereField("date", isLessThan: endOfDay)
            .getDocuments()

        // Filter client-side: keep trips where any studentRecord.id matches our child IDs
        let trips = try snapshot.documents.map { try $0.data(as: Trip.self) }
        return trips.filter { trip in
            trip.studentRecords.contains { studentIds.contains($0.id) }
        }
    }

    /// Fetches all upcoming (today + future) trips for a driver within a school.
    func fetchAllTrips(for driverId: String, schoolId: String) async throws -> [Trip] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let snapshot = try await db.collection("trips")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("driverId", isEqualTo: driverId)
            .whereField("date", isGreaterThanOrEqualTo: startOfDay)
            .order(by: "date", descending: false)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Trip.self) }
    }

    /// Fetches trips for the next 2 weeks for a set of student IDs (parent/student portals).
    func fetchFutureTrips(forStudentIds studentIds: [String], schoolId: String) async throws -> [Trip] {
        guard !studentIds.isEmpty else { return [] }
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        let twoWeeksLater = Calendar.current.date(byAdding: .day, value: 14, to: tomorrow)!
        let snapshot = try await db.collection("trips")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("date", isGreaterThanOrEqualTo: tomorrow)
            .whereField("date", isLessThan: twoWeeksLater)
            .getDocuments()
        let trips = try snapshot.documents.map { try $0.data(as: Trip.self) }
        return trips
            .filter { trip in trip.studentRecords.contains { studentIds.contains($0.id) } }
            .sorted { $0.date < $1.date }
    }

    /// Fetches completed trips in the last 2 weeks for a set of student IDs (parent/student portals).
    func fetchCompletedTrips(forStudentIds studentIds: [String], schoolId: String) async throws -> [Trip] {
        guard !studentIds.isEmpty else { return [] }
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Calendar.current.startOfDay(for: Date()))!
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let snapshot = try await db.collection("trips")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("date", isGreaterThanOrEqualTo: twoWeeksAgo)
            .whereField("date", isLessThan: startOfToday)
            .getDocuments()
        let trips = try snapshot.documents.map { try $0.data(as: Trip.self) }
        return trips
            .filter { trip in trip.studentRecords.contains { studentIds.contains($0.id) } }
            .sorted { $0.date > $1.date }
    }

    /// Fetches completed trips in the last 2 weeks for a driver.
    func fetchCompletedTrips(for driverId: String, schoolId: String) async throws -> [Trip] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Calendar.current.startOfDay(for: Date()))!
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let snapshot = try await db.collection("trips")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("driverId", isEqualTo: driverId)
            .whereField("date", isGreaterThanOrEqualTo: twoWeeksAgo)
            .whereField("date", isLessThan: startOfToday)
            .order(by: "date", descending: true)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Trip.self) }
    }

    /// Fetches the last 3 days of completed trips for a driver (history).
    func fetchRecentCompletedTrips(for driverId: String, schoolId: String) async throws -> [Trip] {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Calendar.current.startOfDay(for: Date()))!
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let snapshot = try await db.collection("trips")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("driverId", isEqualTo: driverId)
            .whereField("date", isGreaterThanOrEqualTo: threeDaysAgo)
            .whereField("date", isLessThan: startOfToday)
            .order(by: "date", descending: true)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Trip.self) }
    }

    /// Starts a trip — updates status to inProgress and sets startedAt.
    func startTrip(id: String) async throws {
        try await db.collection("trips").document(id).updateData([
            "status": TripStatus.inProgress.rawValue,
            "startedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Marks a single student as onBus or offBus and records the timestamp.
    func updateStudentStatus(
        tripId: String,
        studentId: String,
        status: StudentTripStatus
    ) async throws {
        let doc = try await db.collection("trips").document(tripId).getDocument()
        var trip = try doc.data(as: Trip.self)

        guard let index = trip.studentRecords.firstIndex(where: { $0.id == studentId }) else {
            throw FirestoreError.studentNotFound
        }

        trip.studentRecords[index].status = status
        trip.studentRecords[index].timestamp = Date()

        // Check if all students are resolved to auto-complete the trip
        let allResolved = trip.studentRecords.allSatisfy {
            $0.status == .onBus || $0.status == .offBus || $0.status == .absent
        }

        var updateData: [String: Any] = [
            "studentRecords": trip.studentRecords.map { record in
                [
                    "id": record.id,
                    "studentName": record.studentName,
                    "stopAddressAM": record.stopAddressAM,
                    "stopAddressPM": record.stopAddressPM,
                    "orderAM": record.orderAM as Any,
                    "orderPM": record.orderPM as Any,
                    "status": record.status.rawValue,
                    "timestamp": record.timestamp as Any
                ]
            }
        ]

        if allResolved {
            updateData["status"] = TripStatus.completed.rawValue
            updateData["completedAt"] = FieldValue.serverTimestamp()
        }

        try await db.collection("trips").document(tripId).updateData(updateData)
    }

    // MARK: - Substitute Driver

    /// Assigns a substitute driver to all scheduled/future trips on a route within a date range.
    /// Passes nil substituteDriverId to clear an existing substitution.
    func assignSubstituteDriver(
        routeId: String,
        substituteDriverId: String?,
        from fromDate: Date,
        to toDate: Date
    ) async throws {
        let startOfFrom = Calendar.current.startOfDay(for: fromDate)
        let endOfTo     = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: toDate))!

        let snap = try await db.collection("trips")
            .whereField("routeId", isEqualTo: routeId)
            .whereField("date", isGreaterThanOrEqualTo: startOfFrom)
            .whereField("date", isLessThan: endOfTo)
            .getDocuments()

        // Only affect trips that haven't started yet
        let eligible = snap.documents.filter {
            let status = $0.data()["status"] as? String ?? ""
            return status == TripStatus.scheduled.rawValue
        }

        let batch = db.batch()
        for doc in eligible {
            if let subId = substituteDriverId {
                batch.updateData(["substituteDriverId": subId], forDocument: doc.reference)
            } else {
                batch.updateData(["substituteDriverId": FieldValue.delete()], forDocument: doc.reference)
            }
        }
        try await batch.commit()
    }

    // MARK: - Passenger Notes

    /// Fetches active (non-deleted) passenger notes for a specific student within a date range.
    func fetchActiveNotes(for studentId: String) async throws -> [FirestorePassengerNote] {
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = try await db.collection("passengerNotes")
            .whereField("studentId", isEqualTo: studentId)
            .whereField("isDeleted", isEqualTo: false)
            .whereField("toDate", isGreaterThanOrEqualTo: today)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: FirestorePassengerNote.self) }
    }

    /// Adds a new passenger note. Returns the new document reference.
    @discardableResult
    func addPassengerNote(_ note: FirestorePassengerNote) async throws -> DocumentReference {
        let data: [String: Any] = [
            "schoolId": note.schoolId,
            "studentId": note.studentId,
            "studentName": note.studentName,
            "routeId": note.routeId,
            "routeName": note.routeName,
            "type": note.type.rawValue,
            "noteText": note.noteText,
            "fromDate": Timestamp(date: note.fromDate),
            "toDate": Timestamp(date: note.toDate),
            "createdAt": FieldValue.serverTimestamp(),
            "createdById": note.createdById,
            "createdByName": note.createdByName,
            "createdByRole": note.createdByRole,
            "isDeleted": false
        ]
        return try await db.collection("passengerNotes").addDocument(data: data)
    }

    /// Updates the text and date range of an existing note (only by the original creator).
    func updatePassengerNote(id: String, noteText: String, fromDate: Date, toDate: Date, type: TripType) async throws {
        try await db.collection("passengerNotes").document(id).updateData([
            "noteText": noteText,
            "fromDate": Timestamp(date: fromDate),
            "toDate": Timestamp(date: toDate),
            "type": type.rawValue
        ])
    }

    /// Soft-deletes a passenger note.
    func deletePassengerNote(id: String) async throws {
        try await db.collection("passengerNotes").document(id).updateData(["isDeleted": true])
    }

    // MARK: - Students (by ID)

    func fetchStudent(id: String) async throws -> Student {
        let doc = try await db.collection("students").document(id).getDocument()
        return try doc.data(as: Student.self)
    }

    // MARK: - Activity Log

    func logActivity(schoolId: String, actorId: String, actorName: String, actorRole: String, action: String, metadata: [String: String]? = nil) {
        let data: [String: Any] = [
            "schoolId": schoolId,
            "actorId": actorId,
            "actorName": actorName,
            "actorRole": actorRole,
            "action": action,
            "timestamp": FieldValue.serverTimestamp(),
            "metadata": metadata ?? [:]
        ]
        db.collection("activityLog").addDocument(data: data)
    }
}

// MARK: - Errors

enum FirestoreError: LocalizedError {
    case studentNotFound
    case documentNotFound

    var errorDescription: String? {
        switch self {
        case .studentNotFound: return "Student record not found in trip."
        case .documentNotFound: return "Document not found in Firestore."
        }
    }
}

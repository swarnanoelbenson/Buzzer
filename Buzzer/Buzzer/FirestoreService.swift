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

    // MARK: - Drivers

    func fetchAllDrivers() async throws -> [Driver] {
        let snapshot = try await db.collection("drivers")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Driver.self) }
    }

    func fetchDriver(id: String) async throws -> Driver {
        let doc = try await db.collection("drivers").document(id).getDocument()
        return try doc.data(as: Driver.self)
    }

    // MARK: - Students

    func fetchStudents(for routeId: String) async throws -> [Student] {
        let snapshot = try await db.collection("students")
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

    /// Look up a student by their phone number (normalised — last 9 digits compared).
    func fetchStudentByPhone(_ rawPhone: String) async throws -> Student {
        // Try the exact stored number first, then fall back to suffix matching
        let snapshot = try await db.collection("students")
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

    /// Look up a parent by their phone number (normalised — last 9 digits compared).
    func fetchParentByPhone(_ rawPhone: String) async throws -> Parent {
        let snapshot = try await db.collection("parents")
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

    func fetchRoutes(for driverId: String) async throws -> [Route] {
        let snapshot = try await db.collection("routes")
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

    /// Fetches today's trips for a specific driver.
    func fetchTodaysTrips(for driverId: String) async throws -> [Trip] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let snapshot = try await db.collection("trips")
            .whereField("driverId", isEqualTo: driverId)
            .whereField("date", isGreaterThanOrEqualTo: startOfDay)
            .whereField("date", isLessThan: endOfDay)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Trip.self) }
    }

    /// Fetches today's trips that contain any of the given student IDs (for parent portal).
    func fetchTodaysTrips(forStudentIds studentIds: [String]) async throws -> [Trip] {
        guard !studentIds.isEmpty else { return [] }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Firestore `array-contains-any` supports up to 10 values
        let snapshot = try await db.collection("trips")
            .whereField("date", isGreaterThanOrEqualTo: startOfDay)
            .whereField("date", isLessThan: endOfDay)
            .getDocuments()

        // Filter client-side: keep trips where any studentRecord.id matches our child IDs
        let trips = try snapshot.documents.map { try $0.data(as: Trip.self) }
        return trips.filter { trip in
            trip.studentRecords.contains { studentIds.contains($0.id) }
        }
    }

    /// Fetches all upcoming trips for a driver (for View All tab).
    func fetchAllTrips(for driverId: String) async throws -> [Trip] {
        let snapshot = try await db.collection("trips")
            .whereField("driverId", isEqualTo: driverId)
            .order(by: "date", descending: false)
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

    /// Adds a new passenger note.
    func addPassengerNote(_ note: FirestorePassengerNote) async throws {
        let data: [String: Any] = [
            "studentId": note.studentId,
            "studentName": note.studentName,
            "routeId": note.routeId,
            "routeName": note.routeName,
            "type": note.type.rawValue,
            "noteText": note.noteText,
            "fromDate": Timestamp(date: note.fromDate),
            "toDate": Timestamp(date: note.toDate),
            "createdAt": FieldValue.serverTimestamp(),
            "createdByParentId": note.createdByParentId,
            "createdByParentName": note.createdByParentName,
            "isDeleted": false
        ]
        try await db.collection("passengerNotes").addDocument(data: data)
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

    func logActivity(actorId: String, actorName: String, actorRole: String, action: String, metadata: [String: String]? = nil) {
        let data: [String: Any] = [
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

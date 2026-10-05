//
//  NotificationService.swift
//  Buzzer
//
//  Sends push notifications to authorised parents when a student is
//  picked up or dropped off. Uses Firebase Cloud Messaging HTTP v1 API.
//
//  HOW IT WORKS:
//  When a driver marks a student OnBus/OffBus, this service:
//  1. Fetches the student's authorised parent FCM tokens from Firestore
//  2. Sends a push notification to each parent via FCM HTTP v1 API
//
//  NOTE: The FCM calls are made via Firebase Functions HTTP callable in
//  production. For now we write a notification record to Firestore and
//  a Cloud Function (to be deployed separately) picks it up and sends
//  the actual FCM message. This avoids storing service account credentials
//  in the app binary.
//

import Foundation
import FirebaseFirestore

@MainActor
class NotificationService {

    static let shared = NotificationService()
    private let db = Firestore.db

    // MARK: - Trigger notification for a student status change

    /// Called every time a student is marked OnBus, OffBus, or Absent.
    /// Writes a notification request to Firestore — the Cloud Function picks it up
    /// and sends the actual FCM push to each authorised parent.
    func notifyParents(
        studentId: String,
        studentName: String,
        status: StudentTripStatus,
        tripType: TripType,
        driverName: String
    ) async {
        guard status != .pending else { return }

        let (title, body) = messageContent(
            studentName: studentName,
            status: status,
            tripType: tripType
        )

        let payload: [String: Any] = [
            "studentId": studentId,
            "studentName": studentName,
            "status": status.rawValue,
            "tripType": tripType.rawValue,
            "title": title,
            "body": body,
            "driverName": driverName,
            "timestamp": FieldValue.serverTimestamp(),
            "sent": false       // Cloud Function sets this to true after sending
        ]

        // Write to /notificationQueue — Cloud Function watches this collection
        _ = try? await db.collection("notificationQueue").addDocument(data: payload)

        // Also log to activity log
        FirestoreService.shared.logActivity(
            actorId: studentId,
            actorName: driverName,
            actorRole: "driver",
            action: "\(studentName) \(actionVerb(status: status, tripType: tripType))",
            metadata: ["studentId": studentId, "status": status.rawValue]
        )
    }

    // MARK: - Message content

    private func messageContent(
        studentName: String,
        status: StudentTripStatus,
        tripType: TripType
    ) -> (title: String, body: String) {
        let time = formattedTime(Date())

        switch (status, tripType) {
        case (.onBus, .pickup):
            return (
                title: "🚌 \(studentName) is on the bus",
                body: "Picked up at \(time). Have a great day!"
            )
        case (.offBus, .dropoff):
            return (
                title: "🏠 \(studentName) has arrived",
                body: "Dropped off at \(time). Welcome home!"
            )
        case (.absent, _):
            return (
                title: "⚠️ \(studentName) marked absent",
                body: "Your child was not present for the \(tripType.rawValue) at \(time)."
            )
        default:
            return (
                title: "Bus update for \(studentName)",
                body: "Status updated at \(time)."
            )
        }
    }

    private func actionVerb(status: StudentTripStatus, tripType: TripType) -> String {
        switch (status, tripType) {
        case (.onBus, .pickup):   return "boarded the bus"
        case (.offBus, .dropoff): return "was dropped off"
        case (.absent, _):        return "was marked absent"
        default:                  return "status updated"
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}

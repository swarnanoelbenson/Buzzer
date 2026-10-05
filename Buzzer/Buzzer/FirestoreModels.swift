//
//  FirestoreModels.swift
//  Buzzer
//
//  Firestore data models for all entities in the system.
//  These map directly to Firestore collections.
//

import Foundation
import FirebaseFirestore

// MARK: - Driver
// Collection: /drivers/{driverId}
// driverId = Firebase Auth UID

struct Driver: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var phone: String                   // Full phone number with country code e.g. +61412345678
    var age: Int
    var gender: String
    var address: String
    var childrenCheck: String           // Working with Children Check number
    var driversLicense: String
    var licenseExpiry: Date
    var busRegistration: String
    var imageUrl: String?
    var isActive: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name, phone, age, gender, address
        case childrenCheck, driversLicense, licenseExpiry, busRegistration
        case imageUrl, isActive, createdAt
    }
}

// MARK: - Student
// Collection: /students/{studentId}

struct Student: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var grade: String
    var imageUrl: String?
    var phone: String?                  // Phone number — used for SMS OTP login
    var stopAddress: String
    var routeId: String
    var scheduledPickupTime: String     // e.g. "08:15 AM"
    var scheduledDropoffTime: String    // e.g. "03:30 PM"
    var authorisedParentIds: [String]   // parent UIDs who can receive notifications
    var isActive: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, grade, imageUrl, phone, stopAddress
        case routeId, scheduledPickupTime, scheduledDropoffTime
        case authorisedParentIds, isActive, createdAt
    }
}

// MARK: - Parent
// Collection: /parents/{parentId}
// parentId = Firebase Auth UID

struct Parent: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var relationship: ParentRelationship
    var phone: String                   // Phone number — used for SMS OTP login
    var fcmToken: String?               // For push notifications
    var childIds: [String]              // Student IDs linked to this parent
    var isActive: Bool
    var profileCompleted: Bool          // False until parent fills in profile on first login
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, relationship, phone, fcmToken
        case childIds, isActive, profileCompleted, createdAt
    }
}

enum ParentRelationship: String, Codable, CaseIterable {
    case mother = "Mother"
    case father = "Father"
    case stepMother = "Step Mother"
    case stepFather = "Step Father"
    case guardian = "Guardian"
}

// MARK: - Route
// Collection: /routes/{routeId}

struct Route: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var driverId: String
    var term: Int                       // 1, 2, 3, or 4
    var year: Int                       // e.g. 2026
    var scheduledDays: [String]         // e.g. ["Monday", "Wednesday", "Friday"]
    var startDate: Date
    var endDate: Date
    var studentIds: [String]
    var isActive: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, driverId, term, year
        case scheduledDays, startDate, endDate
        case studentIds, isActive, createdAt
    }
}

// MARK: - Trip
// Collection: /trips/{tripId}
// One Trip document per day per route per type (pickup/dropoff).

struct Trip: Identifiable, Codable {
    @DocumentID var id: String?
    var routeId: String
    var driverId: String
    var date: Date
    var type: TripType
    var status: TripStatus
    var studentRecords: [StudentTripRecord]
    var startedAt: Date?
    var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, routeId, driverId, date, type, status
        case studentRecords, startedAt, completedAt
    }
}

enum TripType: String, Codable {
    case pickup = "pickup"
    case dropoff = "dropoff"
}

enum TripStatus: String, Codable {
    case scheduled = "scheduled"
    case inProgress = "inProgress"
    case completed = "completed"
    case cancelled = "cancelled"
}

struct StudentTripRecord: Codable, Identifiable {
    var id: String                      // studentId
    var studentName: String
    var stopAddress: String
    var status: StudentTripStatus
    var timestamp: Date?               // When picked up or dropped off

    enum CodingKeys: String, CodingKey {
        case id, studentName, stopAddress, status, timestamp
    }
}

enum StudentTripStatus: String, Codable {
    case pending = "pending"
    case onBus = "onBus"
    case offBus = "offBus"
    case absent = "absent"
}

// MARK: - Firestore Passenger Note
// Collection: /passengerNotes/{noteId}
// Written by parents via the parent portal; read by drivers and admin console.
// Named FirestorePassengerNote to distinguish from the Core Data PassengerNote in PassengerNoteManager.

struct FirestorePassengerNote: Identifiable, Codable {
    @DocumentID var id: String?
    var studentId: String
    var studentName: String
    var routeId: String
    var routeName: String
    var type: TripType                      // "pickup" or "dropoff"
    var noteText: String
    var fromDate: Date
    var toDate: Date
    var createdAt: Date
    var createdByParentId: String
    var createdByParentName: String
    var isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, studentId, studentName
        case routeId, routeName, type, noteText
        case fromDate, toDate, createdAt
        case createdByParentId, createdByParentName, isDeleted
    }
}

// MARK: - Activity Log
// Collection: /activityLog/{logId}

struct ActivityLog: Identifiable, Codable {
    @DocumentID var id: String?
    var actorId: String
    var actorName: String
    var actorRole: String               // "driver" or "parent"
    var action: String                  // Human-readable description
    var timestamp: Date
    var metadata: [String: String]?    // Extra context (studentId, routeId, etc.)

    enum CodingKeys: String, CodingKey {
        case id, actorId, actorName, actorRole, action, timestamp, metadata
    }
}

//
//  Models.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import Foundation

// MARK: - Attendee List
struct AttendeeList: Identifiable, Equatable {
    let id: UUID
    var name: String
    var createdDate: Date
    var attendees: [Attendee]
    
    init(id: UUID = UUID(), name: String, createdDate: Date = Date(), attendees: [Attendee] = []) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.attendees = attendees
    }
}

// MARK: - Phone Tag
enum PhoneTag: String, CaseIterable {
    case mother = "Mother"
    case father = "Father"
    case student = "Student"
}

// MARK: - Attendee
struct Attendee: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var orderIndex: Int
    var grade: String
    var scheduledAM: Bool
    var scheduledPM: Bool
    var notes: String
    var address: String
    // Mother's phone (primary, required)
    var primaryPhone: String
    var primaryPhoneTag: PhoneTag
    // Father's phone (secondary, optional)
    var secondaryPhone: String
    var secondaryPhoneTag: PhoneTag
    // Student's phone (optional)
    var studentPhone: String
    var studentPhoneTag: PhoneTag
    // Guardian info
    var motherName: String
    var fatherName: String
    // Schedule times
    var pickupTime: Date?
    var dropoffTime: Date?

    init(
        id: UUID = UUID(),
        name: String,
        orderIndex: Int = 0,
        grade: String = "",
        scheduledAM: Bool = true,
        scheduledPM: Bool = true,
        notes: String = "",
        address: String = "",
        primaryPhone: String = "",
        primaryPhoneTag: PhoneTag = .mother,
        secondaryPhone: String = "",
        secondaryPhoneTag: PhoneTag = .father,
        studentPhone: String = "",
        studentPhoneTag: PhoneTag = .student,
        motherName: String = "",
        fatherName: String = "",
        pickupTime: Date? = nil,
        dropoffTime: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
        self.grade = grade
        self.scheduledAM = scheduledAM
        self.scheduledPM = scheduledPM
        self.notes = notes
        self.address = address
        self.primaryPhone = primaryPhone
        self.primaryPhoneTag = primaryPhoneTag
        self.secondaryPhone = secondaryPhone
        self.secondaryPhoneTag = secondaryPhoneTag
        self.studentPhone = studentPhone
        self.studentPhoneTag = studentPhoneTag
        self.motherName = motherName
        self.fatherName = fatherName
        self.pickupTime = pickupTime
        self.dropoffTime = dropoffTime
    }
}

// MARK: - Attendance Session Type
enum SessionType: String, CaseIterable {
    case pickup = "pickup"
    case dropoff = "dropoff"
}

// MARK: - Attendance Status
enum AttendanceStatus: String, CaseIterable {
    case present = "present"
    case absent = "absent"
}

// MARK: - Attendance Session
struct AttendanceSession: Identifiable {
    let id: UUID
    var listId: UUID
    var sessionType: SessionType
    var createdDate: Date
    var records: [AttendanceRecord]
    var sessionStartTimestamp: Date?
    var finalCheckTimestamp: Date?
    
    init(id: UUID = UUID(), listId: UUID, sessionType: SessionType, createdDate: Date = Date(), records: [AttendanceRecord] = [], sessionStartTimestamp: Date? = nil, finalCheckTimestamp: Date? = nil) {
        self.id = id
        self.listId = listId
        self.sessionType = sessionType
        self.createdDate = createdDate
        self.records = records
        self.sessionStartTimestamp = sessionStartTimestamp
        self.finalCheckTimestamp = finalCheckTimestamp
    }
}

// MARK: - Attendance Record
struct AttendanceRecord: Identifiable {
    let id: UUID
    var attendeeId: UUID
    var status: AttendanceStatus
    var timestamp: Date?
    
    init(id: UUID = UUID(), attendeeId: UUID, status: AttendanceStatus, timestamp: Date? = nil) {
        self.id = id
        self.attendeeId = attendeeId
        self.status = status
        self.timestamp = timestamp
    }
}

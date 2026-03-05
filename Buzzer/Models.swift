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

// MARK: - Attendee
struct Attendee: Identifiable, Equatable {
    let id: UUID
    var name: String
    var orderIndex: Int
    var grade: String
    var scheduledAM: Bool
    var scheduledPM: Bool
    var notes: String
    
    init(id: UUID = UUID(), name: String, orderIndex: Int = 0, grade: String = "", scheduledAM: Bool = true, scheduledPM: Bool = true, notes: String = "") {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
        self.grade = grade
        self.scheduledAM = scheduledAM
        self.scheduledPM = scheduledPM
        self.notes = notes
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
    var finalCheckTimestamp: Date?
    
    init(id: UUID = UUID(), listId: UUID, sessionType: SessionType, createdDate: Date = Date(), records: [AttendanceRecord] = [], finalCheckTimestamp: Date? = nil) {
        self.id = id
        self.listId = listId
        self.sessionType = sessionType
        self.createdDate = createdDate
        self.records = records
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

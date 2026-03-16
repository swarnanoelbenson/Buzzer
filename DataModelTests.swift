//
//  DataModelTests.swift
//  BuzzerTests
//
//  Created by Noel Benson on 16/3/2026.
//

import XCTest
@testable import Buzzer

final class DataModelTests: XCTestCase {
    
    var driverDetails: DriverDetails!
    
    override func setUp() {
        super.setUp()
        // Create test driver
        driverDetails = DriverDetails(
            name: "John Smith",
            busRego: "ABC123",
            phoneNo: "123456789",
            email: "john@gmail.com"
        )
    }
    
    override func tearDown() {
        driverDetails = nil
        super.tearDown()
    }
    
    // MARK: - DriverDetails Tests
    
    func testDriverDetailsInitialization() {
        XCTAssertEqual(driverDetails.name, "John Smith")
        XCTAssertEqual(driverDetails.busRego, "ABC123")
        XCTAssertEqual(driverDetails.phoneNo, "123456789")
        XCTAssertEqual(driverDetails.email, "john@gmail.com")
    }
    
    func testDriverDetailsEquality() {
        let details1 = DriverDetails(
            name: "John Smith",
            busRego: "ABC123",
            phoneNo: "123456789",
            email: "john@gmail.com"
        )
        
        let details2 = DriverDetails(
            name: "John Smith",
            busRego: "ABC123",
            phoneNo: "123456789",
            email: "john@gmail.com"
        )
        
        XCTAssertEqual(details1, details2)
    }
    
    func testDriverDetailsInequality() {
        let details1 = DriverDetails(
            name: "John Smith",
            busRego: "ABC123",
            phoneNo: "123456789",
            email: "john@gmail.com"
        )
        
        let details2 = DriverDetails(
            name: "Jane Doe",
            busRego: "XYZ789",
            phoneNo: "987654321",
            email: "jane@yahoo.com"
        )
        
        XCTAssertNotEqual(details1, details2)
    }
    
    func testDriverDetailsAreEncodable() {
        let encoder = JSONEncoder()
        
        do {
            let data = try encoder.encode(driverDetails)
            XCTAssertNotNil(data)
            XCTAssertGreaterThan(data.count, 0)
        } catch {
            XCTFail("Failed to encode DriverDetails: \(error)")
        }
    }
    
    func testDriverDetailsAreDecodable() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(driverDetails)
            let decodedDetails = try decoder.decode(DriverDetails.self, from: data)
            
            XCTAssertEqual(decodedDetails.name, driverDetails.name)
            XCTAssertEqual(decodedDetails.busRego, driverDetails.busRego)
            XCTAssertEqual(decodedDetails.phoneNo, driverDetails.phoneNo)
            XCTAssertEqual(decodedDetails.email, driverDetails.email)
        } catch {
            XCTFail("Failed to encode/decode DriverDetails: \(error)")
        }
    }
    
    // MARK: - AttendanceRecord Tests
    
    func testAttendanceRecordCreation() {
        let attendeeId = UUID()
        let timestamp = Date()
        
        let record = AttendanceRecord(
            id: UUID(),
            attendeeId: attendeeId,
            status: .present,
            timestamp: timestamp
        )
        
        XCTAssertEqual(record.attendeeId, attendeeId)
        XCTAssertEqual(record.status, .present)
        XCTAssertEqual(record.timestamp, timestamp)
    }
    
    func testAttendanceRecordPresent() {
        let record = AttendanceRecord(
            id: UUID(),
            attendeeId: UUID(),
            status: .present,
            timestamp: Date()
        )
        
        XCTAssertEqual(record.status, .present)
        XCTAssertNotNil(record.timestamp)
    }
    
    func testAttendanceRecordAbsent() {
        let record = AttendanceRecord(
            id: UUID(),
            attendeeId: UUID(),
            status: .absent,
            timestamp: nil
        )
        
        XCTAssertEqual(record.status, .absent)
        XCTAssertNil(record.timestamp)
    }
    
    // MARK: - Attendee Tests
    
    func testAttendeeCreation() {
        let attendee = Attendee(
            id: UUID(),
            name: "Emma Wilson",
            orderIndex: 0,
            grade: "5th Grade",
            scheduledAM: true,
            scheduledPM: true,
            notes: "Seat at front"
        )
        
        XCTAssertEqual(attendee.name, "Emma Wilson")
        XCTAssertEqual(attendee.grade, "5th Grade")
        XCTAssertEqual(attendee.orderIndex, 0)
        XCTAssertTrue(attendee.scheduledAM)
        XCTAssertTrue(attendee.scheduledPM)
        XCTAssertEqual(attendee.notes, "Seat at front")
    }
    
    func testAttendeeDefaultValues() {
        let attendee = Attendee(name: "Test Student")
        
        XCTAssertEqual(attendee.name, "Test Student")
        XCTAssertEqual(attendee.orderIndex, 0)
        XCTAssertEqual(attendee.grade, "")
        XCTAssertTrue(attendee.scheduledAM)
        XCTAssertTrue(attendee.scheduledPM)
        XCTAssertEqual(attendee.notes, "")
    }
    
    func testAttendeeEquality() {
        let id = UUID()
        let attendee1 = Attendee(id: id, name: "Test", orderIndex: 0)
        let attendee2 = Attendee(id: id, name: "Test", orderIndex: 0)
        
        XCTAssertEqual(attendee1, attendee2)
    }
    
    // MARK: - AttendeeList Tests
    
    func testAttendeeListCreation() {
        let attendee1 = Attendee(
            id: UUID(),
            name: "John Smith",
            orderIndex: 0,
            grade: "5th Grade"
        )
        
        let attendee2 = Attendee(
            id: UUID(),
            name: "Emma Wilson",
            orderIndex: 1,
            grade: "6th Grade"
        )
        
        let list = AttendeeList(
            id: UUID(),
            name: "Morning Route",
            createdDate: Date(),
            attendees: [attendee1, attendee2]
        )
        
        XCTAssertEqual(list.name, "Morning Route")
        XCTAssertEqual(list.attendees.count, 2)
        XCTAssertEqual(list.attendees[0].name, "John Smith")
        XCTAssertEqual(list.attendees[1].name, "Emma Wilson")
    }
    
    func testAttendeeListEmpty() {
        let list = AttendeeList(
            id: UUID(),
            name: "Empty Route",
            attendees: []
        )
        
        XCTAssertEqual(list.attendees.count, 0)
        XCTAssertTrue(list.attendees.isEmpty)
    }
    
    // MARK: - AttendanceSession Tests
    
    func testAttendanceSessionCreation() {
        let listId = UUID()
        let session = AttendanceSession(
            id: UUID(),
            listId: listId,
            sessionType: .pickup,
            createdDate: Date(),
            records: [],
            sessionStartTimestamp: Date(),
            finalCheckTimestamp: nil
        )
        
        XCTAssertEqual(session.listId, listId)
        XCTAssertEqual(session.sessionType, .pickup)
        XCTAssertNotNil(session.sessionStartTimestamp)
        XCTAssertNil(session.finalCheckTimestamp)
    }
    
    func testAttendanceSessionWithRecords() {
        let attendeeId = UUID()
        let record = AttendanceRecord(
            id: UUID(),
            attendeeId: attendeeId,
            status: .present,
            timestamp: Date()
        )
        
        let session = AttendanceSession(
            id: UUID(),
            listId: UUID(),
            sessionType: .dropoff,
            records: [record]
        )
        
        XCTAssertEqual(session.records.count, 1)
        XCTAssertEqual(session.records[0].attendeeId, attendeeId)
        XCTAssertEqual(session.records[0].status, .present)
    }
    
    // MARK: - Enum Tests
    
    func testSessionTypeEnum() {
        XCTAssertEqual(SessionType.pickup.rawValue, "pickup")
        XCTAssertEqual(SessionType.dropoff.rawValue, "dropoff")
        XCTAssertEqual(SessionType.allCases.count, 2)
    }
    
    func testAttendanceStatusEnum() {
        XCTAssertEqual(AttendanceStatus.present.rawValue, "present")
        XCTAssertEqual(AttendanceStatus.absent.rawValue, "absent")
        XCTAssertEqual(AttendanceStatus.allCases.count, 2)
    }
}

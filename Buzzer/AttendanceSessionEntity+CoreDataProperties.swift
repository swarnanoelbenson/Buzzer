//
//  AttendanceSessionEntity+CoreDataProperties.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import Foundation
import CoreData

extension AttendanceSessionEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AttendanceSessionEntity> {
        return NSFetchRequest<AttendanceSessionEntity>(entityName: "AttendanceSessionEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var sessionType: String?
    @NSManaged public var createdDate: Date?
    @NSManaged public var finalCheckTimestamp: Date?
    @NSManaged public var list: AttendeeListEntity?
    @NSManaged public var records: NSSet?
    
}

// MARK: Generated accessors for records
extension AttendanceSessionEntity {
    
    @objc(addRecordsObject:)
    @NSManaged public func addToRecords(_ value: AttendanceRecordEntity)
    
    @objc(removeRecordsObject:)
    @NSManaged public func removeFromRecords(_ value: AttendanceRecordEntity)
    
    @objc(addRecords:)
    @NSManaged public func addToRecords(_ values: NSSet)
    
    @objc(removeRecords:)
    @NSManaged public func removeFromRecords(_ values: NSSet)
    
}

extension AttendanceSessionEntity : Identifiable {
    
}

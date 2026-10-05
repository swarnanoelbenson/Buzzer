//
//  AttendanceRecordEntity+CoreDataProperties.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import Foundation
import CoreData

extension AttendanceRecordEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AttendanceRecordEntity> {
        return NSFetchRequest<AttendanceRecordEntity>(entityName: "AttendanceRecordEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var status: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var attendee: AttendeeEntity?
    @NSManaged public var session: AttendanceSessionEntity?
    
}

extension AttendanceRecordEntity : Identifiable {
    
}

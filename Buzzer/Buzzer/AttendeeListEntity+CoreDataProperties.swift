//
//  AttendeeListEntity+CoreDataProperties.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import Foundation
import CoreData

extension AttendeeListEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AttendeeListEntity> {
        return NSFetchRequest<AttendeeListEntity>(entityName: "AttendeeListEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdDate: Date?
    @NSManaged public var attendees: NSSet?
    
}

// MARK: Generated accessors for attendees
extension AttendeeListEntity {
    
    @objc(addAttendeesObject:)
    @NSManaged public func addToAttendees(_ value: AttendeeEntity)
    
    @objc(removeAttendeesObject:)
    @NSManaged public func removeFromAttendees(_ value: AttendeeEntity)
    
    @objc(addAttendees:)
    @NSManaged public func addToAttendees(_ values: NSSet)
    
    @objc(removeAttendees:)
    @NSManaged public func removeFromAttendees(_ values: NSSet)
    
}

extension AttendeeListEntity : Identifiable {
    
}

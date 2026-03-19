//
//  AttendeeEntity+CoreDataProperties.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import Foundation
import CoreData

extension AttendeeEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AttendeeEntity> {
        return NSFetchRequest<AttendeeEntity>(entityName: "AttendeeEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var orderIndex: Int16
    @NSManaged public var address: String
    @NSManaged public var primaryPhone: String
    @NSManaged public var primaryPhoneTag: String

    @NSManaged public var secondaryPhone: String?
    @NSManaged public var secondaryPhoneTag: String?
    @NSManaged public var list: AttendeeListEntity?
    
}

extension AttendeeEntity : Identifiable {
    
}

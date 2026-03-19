//
//  PassengerNoteEntity+CoreDataProperties.swift
//  Buzzer
//

import Foundation
import CoreData

extension PassengerNoteEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PassengerNoteEntity> {
        return NSFetchRequest<PassengerNoteEntity>(entityName: "PassengerNoteEntity")
    }

    @NSManaged public var noteID: UUID?
    @NSManaged public var attendeeID: UUID?
    @NSManaged public var attendeeName: String?
    @NSManaged public var fromDate: Date?
    @NSManaged public var toDate: Date?
    @NSManaged public var noteText: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?

}

extension PassengerNoteEntity: Identifiable {

}

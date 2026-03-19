//
//  PassengerNoteManager.swift
//  Buzzer
//

import Foundation
import CoreData

/// A value type representing a passenger note, used in views.
struct PassengerNote: Identifiable {
    let id: UUID
    let attendeeID: UUID
    let attendeeName: String
    let fromDate: Date
    let toDate: Date
    let noteText: String
    let createdAt: Date
    let updatedAt: Date
}

class PassengerNoteManager {
    static let shared = PassengerNoteManager()

    private var context: NSManagedObjectContext {
        PersistenceController.shared.viewContext
    }

    // MARK: - Add Note

    func addNote(attendeeID: UUID, attendeeName: String, fromDate: Date, toDate: Date, noteText: String) {
        let entity = PassengerNoteEntity(context: context)
        entity.noteID = UUID()
        entity.attendeeID = attendeeID
        entity.attendeeName = attendeeName
        entity.fromDate = fromDate
        entity.toDate = toDate
        entity.noteText = noteText
        entity.createdAt = Date()
        entity.updatedAt = Date()
        save()
    }

    // MARK: - Get Active Note for a Date

    /// Returns all notes active on the given date for the specified attendee.
    func getActiveNotes(for attendeeID: UUID, on date: Date) -> [PassengerNote] {
        let request: NSFetchRequest<PassengerNoteEntity> = PassengerNoteEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "attendeeID == %@ AND fromDate <= %@ AND toDate >= %@",
            attendeeID as CVarArg,
            Calendar.current.startOfDay(for: date) as CVarArg,
            Calendar.current.startOfDay(for: date) as CVarArg
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PassengerNoteEntity.fromDate, ascending: true)]

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { convertToNote($0) }
        } catch {
            print("Failed to fetch active notes: \(error)")
            return []
        }
    }

    // MARK: - Get All Notes for Passenger

    func getNotes(for attendeeID: UUID) -> [PassengerNote] {
        let request: NSFetchRequest<PassengerNoteEntity> = PassengerNoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "attendeeID == %@", attendeeID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PassengerNoteEntity.fromDate, ascending: false)]

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { convertToNote($0) }
        } catch {
            print("Failed to fetch notes: \(error)")
            return []
        }
    }

    // MARK: - Get All Notes (for report export)

    func getAllNotes() -> [PassengerNote] {
        let request: NSFetchRequest<PassengerNoteEntity> = PassengerNoteEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PassengerNoteEntity.attendeeName, ascending: true),
            NSSortDescriptor(keyPath: \PassengerNoteEntity.fromDate, ascending: true)
        ]

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { convertToNote($0) }
        } catch {
            print("Failed to fetch all notes: \(error)")
            return []
        }
    }

    // MARK: - Update Note

    func updateNote(id: UUID, fromDate: Date, toDate: Date, noteText: String) {
        let request: NSFetchRequest<PassengerNoteEntity> = PassengerNoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "noteID == %@", id as CVarArg)

        do {
            if let entity = try context.fetch(request).first {
                entity.fromDate = fromDate
                entity.toDate = toDate
                entity.noteText = noteText
                entity.updatedAt = Date()
                save()
            }
        } catch {
            print("Failed to update note: \(error)")
        }
    }

    // MARK: - Delete Note

    func deleteNote(id: UUID) {
        let request: NSFetchRequest<PassengerNoteEntity> = PassengerNoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "noteID == %@", id as CVarArg)

        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                save()
            }
        } catch {
            print("Failed to delete note: \(error)")
        }
    }

    // MARK: - Conversion

    private func convertToNote(_ entity: PassengerNoteEntity) -> PassengerNote? {
        guard
            let noteID = entity.noteID,
            let attendeeID = entity.attendeeID,
            let attendeeName = entity.attendeeName,
            let fromDate = entity.fromDate,
            let toDate = entity.toDate,
            let noteText = entity.noteText,
            let createdAt = entity.createdAt,
            let updatedAt = entity.updatedAt
        else { return nil }

        return PassengerNote(
            id: noteID,
            attendeeID: attendeeID,
            attendeeName: attendeeName,
            fromDate: fromDate,
            toDate: toDate,
            noteText: noteText,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Save

    private func save() {
        PersistenceController.shared.save()
    }
}

//
//  DataManager.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import Foundation
import CoreData

class DataManager: ObservableObject {
    private let persistenceController: PersistenceController
    private var context: NSManagedObjectContext {
        persistenceController.viewContext
    }
    
    @Published var lists: [AttendeeList] = []
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        fetchLists()
    }
    
    // MARK: - List Operations
    
    func fetchLists() {
        let request: NSFetchRequest<AttendeeListEntity> = AttendeeListEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AttendeeListEntity.createdDate, ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            lists = entities.map { convertToAttendeeList($0) }
        } catch {
            print("Failed to fetch lists: \(error)")
        }
    }
    
    func createList(name: String) {
        let entity = AttendeeListEntity(context: context)
        entity.id = UUID()
        entity.name = name
        entity.createdDate = Date()
        
        save()
        fetchLists()
    }
    
    func updateList(_ list: AttendeeList) {
        let request: NSFetchRequest<AttendeeListEntity> = AttendeeListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                entity.name = list.name
                save()
                fetchLists()
            }
        } catch {
            print("Failed to update list: \(error)")
        }
    }
    
    func deleteList(_ list: AttendeeList) {
        let request: NSFetchRequest<AttendeeListEntity> = AttendeeListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                save()
                fetchLists()
            }
        } catch {
            print("Failed to delete list: \(error)")
        }
    }
    
    // MARK: - Attendee Operations
    
    func addAttendee(to list: AttendeeList, name: String) {
        let request: NSFetchRequest<AttendeeListEntity> = AttendeeListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)
        
        do {
            if let listEntity = try context.fetch(request).first {
                let attendeeEntity = AttendeeEntity(context: context)
                attendeeEntity.id = UUID()
                attendeeEntity.name = name
                attendeeEntity.orderIndex = Int16(listEntity.attendees?.count ?? 0)
                attendeeEntity.list = listEntity
                
                save()
                fetchLists()
            }
        } catch {
            print("Failed to add attendee: \(error)")
        }
    }
    
    func updateAttendee(_ attendee: Attendee, in list: AttendeeList) {
        let request: NSFetchRequest<AttendeeEntity> = AttendeeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", attendee.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                entity.name = attendee.name
                entity.orderIndex = Int16(attendee.orderIndex)
                save()
                fetchLists()
            }
        } catch {
            print("Failed to update attendee: \(error)")
        }
    }
    
    func deleteAttendee(_ attendee: Attendee, from list: AttendeeList) {
        let request: NSFetchRequest<AttendeeEntity> = AttendeeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", attendee.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                save()
                fetchLists()
            }
        } catch {
            print("Failed to delete attendee: \(error)")
        }
    }
    
    func reorderAttendees(in list: AttendeeList, attendees: [Attendee]) {
        let request: NSFetchRequest<AttendeeListEntity> = AttendeeListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)
        
        do {
            if let listEntity = try context.fetch(request).first {
                for (index, attendee) in attendees.enumerated() {
                    let attendeeRequest: NSFetchRequest<AttendeeEntity> = AttendeeEntity.fetchRequest()
                    attendeeRequest.predicate = NSPredicate(format: "id == %@", attendee.id as CVarArg)
                    
                    if let attendeeEntity = try context.fetch(attendeeRequest).first {
                        attendeeEntity.orderIndex = Int16(index)
                    }
                }
                save()
                fetchLists()
            }
        } catch {
            print("Failed to reorder attendees: \(error)")
        }
    }
    
    // MARK: - Conversion Helpers
    
    private func convertToAttendeeList(_ entity: AttendeeListEntity) -> AttendeeList {
        let attendees = (entity.attendees?.allObjects as? [AttendeeEntity] ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { convertToAttendee($0) }
        
        return AttendeeList(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            createdDate: entity.createdDate ?? Date(),
            attendees: attendees
        )
    }
    
    private func convertToAttendee(_ entity: AttendeeEntity) -> Attendee {
        return Attendee(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            orderIndex: Int(entity.orderIndex)
        )
    }
    
    // MARK: - Save
    
    private func save() {
        persistenceController.save()
    }
}

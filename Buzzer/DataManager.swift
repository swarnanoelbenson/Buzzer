//
//  DataManager.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import Foundation
import CoreData
import Combine

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
    
    func duplicateList(_ list: AttendeeList, newName: String) {
        let request: NSFetchRequest<AttendeeListEntity> = AttendeeListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            guard let sourceEntity = try context.fetch(request).first else { return }

            // Create new list entity
            let newListEntity = AttendeeListEntity(context: context)
            newListEntity.id = UUID()
            newListEntity.name = newName
            newListEntity.createdDate = Date()

            // Copy all attendees (new IDs, no sessions)
            let sourceAttendees = (sourceEntity.attendees?.allObjects as? [AttendeeEntity] ?? [])
                .sorted { $0.orderIndex < $1.orderIndex }

            for source in sourceAttendees {
                let newAttendee = AttendeeEntity(context: context)
                newAttendee.id = UUID()
                newAttendee.name = source.name
                newAttendee.grade = source.grade
                newAttendee.orderIndex = source.orderIndex
                newAttendee.address = source.address
                newAttendee.primaryPhone = source.primaryPhone
                newAttendee.primaryPhoneTag = source.primaryPhoneTag
                newAttendee.secondaryPhone = source.secondaryPhone
                newAttendee.secondaryPhoneTag = source.secondaryPhoneTag
                newAttendee.studentPhone = source.studentPhone
                newAttendee.studentPhoneTag = source.studentPhoneTag
                newAttendee.motherName = source.motherName
                newAttendee.fatherName = source.fatherName
                newAttendee.pickupTime = source.pickupTime
                newAttendee.dropoffTime = source.dropoffTime
                newAttendee.list = newListEntity
            }

            save()
            fetchLists()
        } catch {
            print("Failed to duplicate list: \(error)")
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
    
    func addAttendee(
        to list: AttendeeList,
        name: String,
        grade: String,
        address: String,
        primaryPhone: String,
        primaryPhoneTag: PhoneTag,
        secondaryPhone: String = "",
        secondaryPhoneTag: PhoneTag = .father,
        studentPhone: String = "",
        studentPhoneTag: PhoneTag = .student,
        motherName: String = "",
        fatherName: String = "",
        pickupTime: Date? = nil,
        dropoffTime: Date? = nil
    ) {
        let request: NSFetchRequest<AttendeeListEntity> = AttendeeListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)
        
        do {
            if let listEntity = try context.fetch(request).first {
                let attendeeEntity = AttendeeEntity(context: context)
                attendeeEntity.id = UUID()
                attendeeEntity.name = name
                attendeeEntity.grade = grade
                attendeeEntity.orderIndex = Int16(listEntity.attendees?.count ?? 0)
                attendeeEntity.list = listEntity
                attendeeEntity.address = address
                attendeeEntity.primaryPhone = primaryPhone
                attendeeEntity.primaryPhoneTag = primaryPhoneTag.rawValue
                attendeeEntity.secondaryPhone = secondaryPhone.isEmpty ? nil : secondaryPhone
                attendeeEntity.secondaryPhoneTag = secondaryPhone.isEmpty ? nil : secondaryPhoneTag.rawValue
                attendeeEntity.studentPhone = studentPhone.isEmpty ? nil : studentPhone
                attendeeEntity.studentPhoneTag = studentPhone.isEmpty ? nil : studentPhoneTag.rawValue
                attendeeEntity.motherName = motherName.isEmpty ? nil : motherName
                attendeeEntity.fatherName = fatherName.isEmpty ? nil : fatherName
                attendeeEntity.pickupTime = pickupTime
                attendeeEntity.dropoffTime = dropoffTime
                
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
                entity.grade = attendee.grade
                entity.orderIndex = Int16(attendee.orderIndex)
                entity.address = attendee.address
                entity.primaryPhone = attendee.primaryPhone
                entity.primaryPhoneTag = attendee.primaryPhoneTag.rawValue
                entity.secondaryPhone = attendee.secondaryPhone.isEmpty ? nil : attendee.secondaryPhone
                entity.secondaryPhoneTag = attendee.secondaryPhone.isEmpty ? nil : attendee.secondaryPhoneTag.rawValue
                entity.studentPhone = attendee.studentPhone.isEmpty ? nil : attendee.studentPhone
                entity.studentPhoneTag = attendee.studentPhone.isEmpty ? nil : attendee.studentPhoneTag.rawValue
                entity.motherName = attendee.motherName.isEmpty ? nil : attendee.motherName
                entity.fatherName = attendee.fatherName.isEmpty ? nil : attendee.fatherName
                entity.pickupTime = attendee.pickupTime
                entity.dropoffTime = attendee.dropoffTime
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
            if (try context.fetch(request).first) != nil {
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
            orderIndex: Int(entity.orderIndex),
            grade: entity.grade,
            address: entity.address ?? "",
            primaryPhone: entity.primaryPhone ?? "",
            primaryPhoneTag: PhoneTag(rawValue: entity.primaryPhoneTag ?? "") ?? .mother,
            secondaryPhone: entity.secondaryPhone ?? "",
            secondaryPhoneTag: PhoneTag(rawValue: entity.secondaryPhoneTag ?? "") ?? .father,
            studentPhone: entity.studentPhone ?? "",
            studentPhoneTag: PhoneTag(rawValue: entity.studentPhoneTag ?? "") ?? .student,
            motherName: entity.motherName ?? "",
            fatherName: entity.fatherName ?? "",
            pickupTime: entity.pickupTime,
            dropoffTime: entity.dropoffTime
        )
    }
    
    // MARK: - Session Operations
    
    func saveSession(_ session: AttendanceSession, records: [AttendanceRecord], finalCheckTimestamp: Date? = nil) {
        // Create session entity
        let sessionEntity = AttendanceSessionEntity(context: context)
        sessionEntity.id = session.id
        sessionEntity.sessionType = session.sessionType.rawValue
        sessionEntity.createdDate = session.createdDate
        sessionEntity.sessionStartTimestamp = session.sessionStartTimestamp
        sessionEntity.finalCheckTimestamp = finalCheckTimestamp
        
        // Link to list
        let listRequest: NSFetchRequest<AttendeeListEntity> = AttendeeListEntity.fetchRequest()
        listRequest.predicate = NSPredicate(format: "id == %@", session.listId as CVarArg)
        
        do {
            if let listEntity = try context.fetch(listRequest).first {
                sessionEntity.list = listEntity
                // Create record entities
                for record in records {
                    let recordEntity = AttendanceRecordEntity(context: context)
                    recordEntity.id = record.id
                    recordEntity.status = record.status.rawValue
                    recordEntity.timestamp = record.timestamp
                    recordEntity.session = sessionEntity
                    
                    // Link to attendee
                    let attendeeRequest: NSFetchRequest<AttendeeEntity> = AttendeeEntity.fetchRequest()
                    attendeeRequest.predicate = NSPredicate(format: "id == %@", record.attendeeId as CVarArg)
                    
                    if let attendeeEntity = try context.fetch(attendeeRequest).first {
                        recordEntity.attendee = attendeeEntity
                    }
                }
                
                save()
            }
        } catch {
            print("Failed to save session: \(error)")
        }
    }
    
    func fetchRecentSession(for list: AttendeeList, type: SessionType) -> AttendanceSession? {
        let request: NSFetchRequest<AttendanceSessionEntity> = AttendanceSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "list.id == %@ AND sessionType == %@", list.id as CVarArg, type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AttendanceSessionEntity.createdDate, ascending: false)]
        request.fetchLimit = 1
        
        do {
            if let entity = try context.fetch(request).first {
                return convertToAttendanceSession(entity)
            }
        } catch {
            print("Failed to fetch recent session: \(error)")
        }
        
        return nil
    }
    
    func fetchSessions(for list: AttendeeList) -> [AttendanceSession] {
        let request: NSFetchRequest<AttendanceSessionEntity> = AttendanceSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "list.id == %@", list.id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AttendanceSessionEntity.createdDate, ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { convertToAttendanceSession($0) }
        } catch {
            print("Failed to fetch sessions: \(error)")
            return []
        }
    }
    
    // MARK: - Conversion Helpers (Sessions)
    
    private func convertToAttendanceSession(_ entity: AttendanceSessionEntity) -> AttendanceSession {
        let records = (entity.records?.allObjects as? [AttendanceRecordEntity] ?? [])
            .map { convertToAttendanceRecord($0) }
        
        return AttendanceSession(
            id: entity.id ?? UUID(),
            listId: entity.list?.id ?? UUID(),
            sessionType: SessionType(rawValue: entity.sessionType ?? "pickup") ?? .pickup,
            createdDate: entity.createdDate ?? Date(),
            records: records,
            sessionStartTimestamp: entity.sessionStartTimestamp,
            finalCheckTimestamp: entity.finalCheckTimestamp
        )
    }
    
    private func convertToAttendanceRecord(_ entity: AttendanceRecordEntity) -> AttendanceRecord {
        return AttendanceRecord(
            id: entity.id ?? UUID(),
            attendeeId: entity.attendee?.id ?? UUID(),
            status: AttendanceStatus(rawValue: entity.status ?? "absent") ?? .absent,
            timestamp: entity.timestamp
        )
    }
    
    // MARK: - Delete All Data
    
    func deleteAllData() {
        // Delete all sessions
        let sessionsRequest: NSFetchRequest<AttendanceSessionEntity> = AttendanceSessionEntity.fetchRequest()
        do {
            let sessions = try context.fetch(sessionsRequest)
            for session in sessions {
                context.delete(session)
            }
            print("🗑️ Deleted \(sessions.count) attendance sessions")
        } catch {
            print("❌ Failed to delete sessions: \(error)")
        }
        
        // Delete all records (should cascade from sessions, but just in case)
        let recordsRequest: NSFetchRequest<AttendanceRecordEntity> = AttendanceRecordEntity.fetchRequest()
        do {
            let records = try context.fetch(recordsRequest)
            for record in records {
                context.delete(record)
            }
            print("🗑️ Deleted \(records.count) attendance records")
        } catch {
            print("❌ Failed to delete records: \(error)")
        }
        
        // Delete all attendees
        let attendeesRequest: NSFetchRequest<AttendeeEntity> = AttendeeEntity.fetchRequest()
        do {
            let attendees = try context.fetch(attendeesRequest)
            for attendee in attendees {
                context.delete(attendee)
            }
            print("🗑️ Deleted \(attendees.count) attendees")
        } catch {
            print("❌ Failed to delete attendees: \(error)")
        }
        
        // Delete all lists
        let listsRequest: NSFetchRequest<AttendeeListEntity> = AttendeeListEntity.fetchRequest()
        do {
            let listEntities = try context.fetch(listsRequest)
            for list in listEntities {
                context.delete(list)
            }
            print("🗑️ Deleted \(listEntities.count) attendee lists")
        } catch {
            print("❌ Failed to delete lists: \(error)")
        }
        
        // Save and refresh
        save()
        fetchLists()
        
        print("✅ All data deleted successfully")
    }
    
    // MARK: - Save
    
    private func save() {
        persistenceController.save()
    }
}

//
//  DemoModeManager.swift
//  Buzzer
//
//  Manages demo/test mode for app reviewers.
//  Enables pre-populated data so all features can be tested immediately.
//

import Foundation
import CoreData
import Combine

// MARK: - Demo Mode Manager

class DemoModeManager: ObservableObject {
    static let shared = DemoModeManager()

    @Published private(set) var isDemoMode: Bool {
        didSet { UserDefaults.standard.set(isDemoMode, forKey: "isDemoMode") }
    }

    private init() {
        self.isDemoMode = UserDefaults.standard.bool(forKey: "isDemoMode")
    }

    // MARK: - Enable Demo Mode

    /// Populates all demo data and saves driver details.
    func enableDemoMode(dataManager: DataManager) {
        let context = PersistenceController.shared.viewContext

        // 1. Save demo driver details
        let demoDriver = DriverDetails(
            name: "Demo Driver",
            busRego: "ABC123",
            phoneNo: "0412345678",
            email: "demo@busmate.app"
        )
        DriverManager.shared.saveDriverDetails(demoDriver)

        // 2. Create the demo attendee list and attendees
        let listEntity = AttendeeListEntity(context: context)
        listEntity.id = UUID()
        listEntity.name = "Demo Route"
        listEntity.createdDate = Date()

        // Helper to build a Date for a given hour:minute today (used for pickup/dropoff times)
        func time(hour: Int, minute: Int) -> Date {
            Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        }

        let demoAttendeesData: [(
            name: String, grade: String, phone: String,
            motherName: String, fatherName: String,
            pickupHour: Int, pickupMinute: Int,
            dropoffHour: Int, dropoffMinute: Int
        )] = [
            ("John Smith",    "Grade 6", "0411000001", "Mary Smith",    "Robert Smith",   7, 45, 15, 30),
            ("Sarah Johnson", "Grade 5", "0411000002", "Linda Johnson", "Mark Johnson",   8,  0, 15, 45),
            ("Mike Davis",    "Grade 6", "0411000003", "Patricia Davis","James Davis",    7, 50, 15, 30),
            ("Emily Brown",   "Grade 5", "0411000004", "Barbara Brown", "William Brown",  8,  5, 15, 40),
            ("Alex Wilson",   "Grade 7", "0411000005", "Susan Wilson",  "Richard Wilson", 7, 55, 15, 35),
            ("Jessica Lee",   "Grade 6", "0411000006", "Karen Lee",     "Charles Lee",    8, 10, 15, 50),
            ("Tom Anderson",  "Grade 5", "0411000007", "Nancy Anderson","Joseph Anderson",7, 48, 15, 30),
            ("Lisa Martinez", "Grade 7", "0411000008", "Betty Martinez","Thomas Martinez",8,  2, 15, 45),
            ("David Taylor",  "Grade 6", "0411000009", "Dorothy Taylor","Christopher Taylor", 7, 52, 15, 35),
            ("Sophie White",  "Grade 5", "0411000010", "Sandra White",  "Daniel White",   8,  8, 15, 50),
        ]

        var attendeeEntities: [AttendeeEntity] = []
        for (index, data) in demoAttendeesData.enumerated() {
            let attendeeEntity = AttendeeEntity(context: context)
            attendeeEntity.id = UUID()
            attendeeEntity.name = data.name
            attendeeEntity.grade = data.grade
            attendeeEntity.orderIndex = Int16(index)
            attendeeEntity.address = "1\(index + 1) Demo Street, Sydney NSW 2000"
            attendeeEntity.primaryPhone = data.phone
            attendeeEntity.primaryPhoneTag = PhoneTag.mother.rawValue
            attendeeEntity.motherName = data.motherName
            attendeeEntity.fatherName = data.fatherName
            attendeeEntity.pickupTime = time(hour: data.pickupHour, minute: data.pickupMinute)
            attendeeEntity.dropoffTime = time(hour: data.dropoffHour, minute: data.dropoffMinute)
            attendeeEntity.list = listEntity
            attendeeEntities.append(attendeeEntity)
        }

        // 3. Create demo sessions for this week (pickup + dropoff each day Mon–Fri)
        let calendar = Calendar.current
        let today = Date()
        // Find the most recent Monday
        let weekday = calendar.component(.weekday, from: today) // 1=Sun, 2=Mon ... 7=Sat
        let daysFromMonday = (weekday == 1) ? 6 : weekday - 2
        guard let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else { return }

        // Days: Mon=0, Tue=1, Wed=2, Thu=3, Fri=4
        let dayOffsets = [0, 1, 2, 3, 4]

        for dayOffset in dayOffsets {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: thisMonday) else { continue }

            // Only create sessions for past/current days so they appear as history
            guard dayDate <= today else { continue }

            // Pickup session — 8:00 AM
            if let pickupStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayDate),
               let pickupFinal = calendar.date(bySettingHour: 8, minute: 25, second: 0, of: dayDate) {

                let pickupSession = AttendanceSessionEntity(context: context)
                pickupSession.id = UUID()
                pickupSession.sessionType = SessionType.pickup.rawValue
                pickupSession.createdDate = pickupStart
                pickupSession.sessionStartTimestamp = pickupStart
                pickupSession.finalCheckTimestamp = pickupFinal
                pickupSession.list = listEntity

                for attendeeEntity in attendeeEntities {
                    let record = AttendanceRecordEntity(context: context)
                    record.id = UUID()
                    let isAbsent = isAbsentForDemo(
                        attendeeName: attendeeEntity.name ?? "",
                        dayOffset: dayOffset,
                        sessionType: .pickup
                    )
                    record.status = isAbsent ? AttendanceStatus.absent.rawValue : AttendanceStatus.present.rawValue
                    record.timestamp = isAbsent ? nil : pickupStart.addingTimeInterval(Double(Int.random(in: 60...900)))
                    record.attendee = attendeeEntity
                    record.session = pickupSession
                }
            }

            // Dropoff session — 3:30 PM
            if let dropoffStart = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: dayDate),
               let dropoffFinal = calendar.date(bySettingHour: 15, minute: 55, second: 0, of: dayDate) {

                let dropoffSession = AttendanceSessionEntity(context: context)
                dropoffSession.id = UUID()
                dropoffSession.sessionType = SessionType.dropoff.rawValue
                dropoffSession.createdDate = dropoffStart
                dropoffSession.sessionStartTimestamp = dropoffStart
                dropoffSession.finalCheckTimestamp = dropoffFinal
                dropoffSession.list = listEntity

                for attendeeEntity in attendeeEntities {
                    let record = AttendanceRecordEntity(context: context)
                    record.id = UUID()
                    let isAbsent = isAbsentForDemo(
                        attendeeName: attendeeEntity.name ?? "",
                        dayOffset: dayOffset,
                        sessionType: .dropoff
                    )
                    record.status = isAbsent ? AttendanceStatus.absent.rawValue : AttendanceStatus.present.rawValue
                    record.timestamp = isAbsent ? nil : dropoffStart.addingTimeInterval(Double(Int.random(in: 60...900)))
                    record.attendee = attendeeEntity
                    record.session = dropoffSession
                }
            }
        }

        // 4. Create demo passenger notes
        // John Smith: Mon–Wed this week — "Parent picking up early"
        if let johnNoteFrom = calendar.date(byAdding: .day, value: 0, to: thisMonday),
           let johnNoteTo   = calendar.date(byAdding: .day, value: 2, to: thisMonday),
           let johnEntity   = attendeeEntities.first(where: { $0.name == "John Smith" }),
           let johnID       = johnEntity.id {
            let note = PassengerNoteEntity(context: context)
            note.noteID      = UUID()
            note.attendeeID  = johnID
            note.attendeeName = "John Smith"
            note.fromDate    = johnNoteFrom
            note.toDate      = johnNoteTo
            note.noteText    = "Parent picking up early"
            note.createdAt   = Date()
            note.updatedAt   = Date()
        }

        // Sarah Johnson: Tuesday only — "Doctor appointment"
        if let sarahNoteDay = calendar.date(byAdding: .day, value: 1, to: thisMonday),
           let sarahEntity  = attendeeEntities.first(where: { $0.name == "Sarah Johnson" }),
           let sarahID      = sarahEntity.id {
            let note = PassengerNoteEntity(context: context)
            note.noteID      = UUID()
            note.attendeeID  = sarahID
            note.attendeeName = "Sarah Johnson"
            note.fromDate    = sarahNoteDay
            note.toDate      = sarahNoteDay
            note.noteText    = "Doctor appointment"
            note.createdAt   = Date()
            note.updatedAt   = Date()
        }

        // Mike Davis: Wed–Fri — "Early dismissal at 2PM"
        if let mikeNoteFrom = calendar.date(byAdding: .day, value: 2, to: thisMonday),
           let mikeNoteTo   = calendar.date(byAdding: .day, value: 4, to: thisMonday),
           let mikeEntity   = attendeeEntities.first(where: { $0.name == "Mike Davis" }),
           let mikeID       = mikeEntity.id {
            let note = PassengerNoteEntity(context: context)
            note.noteID      = UUID()
            note.attendeeID  = mikeID
            note.attendeeName = "Mike Davis"
            note.fromDate    = mikeNoteFrom
            note.toDate      = mikeNoteTo
            note.noteText    = "Early dismissal at 2PM"
            note.createdAt   = Date()
            note.updatedAt   = Date()
        }

        // 5. Save and refresh
        PersistenceController.shared.save()
        dataManager.fetchLists()

        isDemoMode = true
        print("✅ Demo mode enabled")
    }

    // MARK: - Disable Demo Mode

    /// Deletes all data and driver details, returning the app to first-launch state.
    func disableDemoMode(dataManager: DataManager) {
        dataManager.deleteAllData()

        // Delete all passenger notes
        let context = PersistenceController.shared.viewContext
        let notesRequest: NSFetchRequest<PassengerNoteEntity> = PassengerNoteEntity.fetchRequest()
        if let notes = try? context.fetch(notesRequest) {
            notes.forEach { context.delete($0) }
        }
        PersistenceController.shared.save()

        DriverManager.shared.clearDriverDetails()
        isDemoMode = false
        print("✅ Demo mode disabled — all data cleared")
    }

    // MARK: - Absence Logic

    /// Determines demo absence patterns:
    /// - Tuesday pickup: John Smith absent
    /// - Thursday pickup: Sarah Johnson, Mike Davis absent
    private func isAbsentForDemo(attendeeName: String, dayOffset: Int, sessionType: SessionType) -> Bool {
        switch dayOffset {
        case 1: // Tuesday
            return attendeeName == "John Smith"
        case 3: // Thursday
            return attendeeName == "Sarah Johnson" || attendeeName == "Mike Davis"
        default:
            return false
        }
    }
}

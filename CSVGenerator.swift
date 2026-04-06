//
//  CSVGenerator.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//

import Foundation

struct CSVGenerator {
    
    // MARK: - Weekly Manifest Report
    
    /// Generates bus manifest in Excel-friendly CSV format for a week
    static func generateWeeklyManifest(
        for sessions: [AttendanceSession],
        list: AttendeeList,
        weekStartDate: Date,
        driverDetails: DriverDetails?,
        passengerNotes: [PassengerNote] = []
    ) -> String {
        var csv = ""
        
        // Get week end date (unused but kept for potential future use)
        let calendar = Calendar.current
        _ = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
        
        // Get final check timestamp from the most recent dropoff session (unused but kept for potential future use)
        let dropoffSessions = sessions.filter { $0.sessionType == .dropoff }
        _ = dropoffSessions.last?.finalCheckTimestamp
        
        // HEADER SECTION
        csv += "WEEKLY REPORT - \(TimestampFormatter.formatDateLong(weekStartDate))\n"
        csv += "\n"
        csv += "ROUTE:,\(list.name)\n"
        csv += "REGISTRATION:,\(driverDetails?.busRego ?? "N/A")\n"
        csv += "DRIVER:,\(driverDetails?.name ?? "N/A")\n"
        csv += "PHONE:,\(driverDetails?.phoneNo ?? "N/A")\n"
        csv += "EMAIL:,\(driverDetails?.email ?? "N/A")\n"
        csv += "\n"
        

        // ATTENDANCE TABLE HEADERS
        // Layout: Name | Grade | [Mon AM Pickup Sched | Mon AM Pickup Actual | Mon PM Dropoff Sched | Mon PM Dropoff Actual] x5 | Address | Mother's Phone | Mother's Name | Father's Phone | Father's Name | Student's Phone
        // Total columns: 2 + 20 + 6 = 28
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

        // Header row 1 — day labels (AM Pickup, PM Dropoff) each span two sub-columns (the day label + a blank neighbour that merges left in Excel)
        // Loop emits: ,{Day} AM Pickup,,{Day} PM Dropoff,  (4 commas = 4 separators per day)
        // The trailing comma after PM Dropoff becomes the blank sub-column that merges left in Excel.
        // After the loop, contact headers follow WITHOUT a leading comma (the loop's last comma serves as separator).
        csv += "Name,Grade"
        for day in weekdays {
            csv += ",\(day) AM Pickup,,\(day) PM Dropoff,"
        }
        // The loop's trailing comma creates the blank neighbour for Friday PM Dropoff (col 21).
        // The leading comma here starts Address at col 22.
        csv += ",Address,Mother's Phone,Mother's Name,Father's Phone,Father's Name,Student's Phone\n"

        // Header row 2 — "AM Scheduled | AM Actual | PM Scheduled | PM Actual" under each day pair; blanks elsewhere
        csv += ","   // Name — blank
        csv += ","   // Grade — blank (also acts as separator before first day sub-headers)
        for _ in weekdays {
            csv += "AM Scheduled,AM Actual,PM Scheduled,PM Actual,"
        }
        // Contact columns (6) — blank sub-headers; leading separator already emitted by the loop's trailing comma
        csv += ",,,,,\n"

        // Sort attendees by original list order
        let sortedAttendees = list.attendees.sorted { $0.orderIndex < $1.orderIndex }

        // Get current date for comparison
        let today = Date()

        // DATA ROWS - One row per student
        for attendee in sortedAttendees {
            csv += escapeCSV(attendee.name)
            csv += ","
            csv += escapeCSV(attendee.grade)

            // Add daily pickup and dropoff times for Mon-Fri
            for dayOffset in 0..<5 {
                let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
                let isDayInFuture = calendar.compare(dayDate, to: today, toGranularity: .day) == .orderedDescending

                // AM Pickup — Scheduled
                csv += ","
                if let sched = attendee.pickupTime {
                    csv += TimestampFormatter.formatTimeShort12Hour(sched)
                }

                // AM Pickup — Actual
                csv += ","
                if isDayInFuture {
                    csv += ""
                } else if let hasPickupSession = sessions.first(where: {
                    $0.sessionType == .pickup && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                }) {
                    if let record = hasPickupSession.records.first(where: { $0.attendeeId == attendee.id }) {
                        if record.status == .present, let ts = record.timestamp {
                            csv += TimestampFormatter.formatTimeShort12Hour(ts)
                        } else {
                            csv += "Absent"
                        }
                    } else {
                        csv += "Absent"
                    }
                } else {
                    csv += ""
                }

                // PM Dropoff — Scheduled
                csv += ","
                if let sched = attendee.dropoffTime {
                    csv += TimestampFormatter.formatTimeShort12Hour(sched)
                }

                // PM Dropoff — Actual
                csv += ","
                if isDayInFuture {
                    csv += ""
                } else if let hasDropoffSession = sessions.first(where: {
                    $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                }) {
                    if let record = hasDropoffSession.records.first(where: { $0.attendeeId == attendee.id }) {
                        if record.status == .present, let ts = record.timestamp {
                            csv += TimestampFormatter.formatTimeShort12Hour(ts)
                        } else {
                            csv += "Absent"
                        }
                    } else {
                        csv += "Absent"
                    }
                } else {
                    csv += ""
                }
            }

            // Contact detail columns: Address | Mother's Phone | Mother's Name | Father's Phone | Father's Name | Student's Phone
            csv += ","
            csv += escapeCSV(attendee.address)
            csv += ","
            csv += escapeCSV(attendee.primaryPhone)           // Mother's Phone
            csv += ","
            csv += escapeCSV(attendee.motherName)             // Mother's Name
            csv += ","
            csv += escapeCSV(attendee.secondaryPhone)         // Father's Phone
            csv += ","
            csv += escapeCSV(attendee.fatherName)             // Father's Name
            csv += ","
            csv += escapeCSV(attendee.studentPhone)           // Student's Phone
            csv += "\n"
        }

        csv += "\n"

        // JOURNEY START TIME ROW
        // Col layout: Name | Grade | [PickSched | PickActual | DropSched | DropActual] x5 | Address | ...
        // Journey start goes into the first "Actual" cell of each day pair (col index 3 & 1 within each group).
        // Simpler: emit Name, Grade, then for each day emit: blank(sched) | startTime(actual) | blank(sched) | startTime(actual) | then contact blanks.
        csv += "Journey Start Time,"  // Name col
        csv += ""                      // Grade col

        for dayOffset in 0..<5 {
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate

            let pickupSession = sessions.first {
                $0.sessionType == .pickup && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
            }
            let dropoffSession = sessions.first {
                $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
            }

            // AM Pickup Scheduled (blank) | AM Pickup Actual (session start)
            csv += ","  // sched — blank
            csv += ","
            if let start = pickupSession?.sessionStartTimestamp {
                csv += TimestampFormatter.formatTimeShort12Hour(start)
            }

            // PM Dropoff Scheduled (blank) | PM Dropoff Actual (session start)
            csv += ","  // sched — blank
            csv += ","
            if let start = dropoffSession?.sessionStartTimestamp {
                csv += TimestampFormatter.formatTimeShort12Hour(start)
            }
        }
        // Contact columns — all blank (6: Address, Mother's Phone, Mother's Name, Father's Phone, Father's Name, Student's Phone)
        csv += ",,,,,,"
        csv += "\n"

        // FINAL CHECK ROW
        csv += "No Child Left On Bus,"  // Name col
        csv += ""                        // Grade col

        for dayOffset in 0..<5 {
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
            let isDayInFuture = calendar.compare(dayDate, to: today, toGranularity: .day) == .orderedDescending

            let pickupSession = sessions.first {
                $0.sessionType == .pickup && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
            }
            let dropoffSession = sessions.first {
                $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
            }

            // AM Pickup Scheduled (blank) | AM Pickup Actual (final check)
            csv += ","  // sched — blank
            csv += ","
            if !isDayInFuture, let fc = pickupSession?.finalCheckTimestamp {
                csv += TimestampFormatter.formatTimeShort12Hour(fc)
            }

            // PM Dropoff Scheduled (blank) | PM Dropoff Actual (final check)
            csv += ","  // sched — blank
            csv += ","
            if !isDayInFuture, let fc = dropoffSession?.finalCheckTimestamp {
                csv += TimestampFormatter.formatTimeShort12Hour(fc)
            }
        }
        // Contact columns — all blank (6: Address, Mother's Phone, Mother's Name, Father's Phone, Father's Name, Student's Phone)
        csv += ",,,,,,"
        csv += "\n"
        csv += "\n"

        // Total columns = 2 (Name+Grade) + 20 (5 days × 4) + 6 (contact) = 28
        // To span a value across all columns, pad with 27 commas.
        let columnSpan = String(repeating: ",", count: 27)

        // TRAVEL NOTES SECTION
        let notesTrail = String(repeating: ",", count: 26)  // 27 cols - 1 for the value cell = 26 trailing
        csv += "TRAVEL NOTES\(columnSpan)\n"
        csv += "Student Name,Notes\(notesTrail)\n"

        for attendee in sortedAttendees {
            if !attendee.notes.isEmpty {
                csv += escapeCSV(attendee.name)
                csv += ","
                csv += escapeCSV(attendee.notes)
                csv += notesTrail
                csv += "\n"
            }
        }

        // PASSENGER NOTES SECTION
        if !passengerNotes.isEmpty {
            csv += "\n"
            csv += "PASSENGER NOTES\(columnSpan)\n"
            let sortedNotes = passengerNotes.sorted {
                if $0.attendeeName != $1.attendeeName {
                    return $0.attendeeName < $1.attendeeName
                }
                return $0.fromDate < $1.fromDate
            }
            for note in sortedNotes {
                let fromStr = formatDateLong(note.fromDate)
                let toStr = formatDateLong(note.toDate)
                let line = "\(note.attendeeName): \(fromStr) to \(toStr) \(note.noteText)"
                csv += escapeCSV(line)
                csv += columnSpan
                csv += "\n"
            }
        }

        return csv
    }

    // MARK: - Date Formatting Helper

    private static func formatDateLong(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Manifest Helper Functions
    
    
    /// Escapes CSV values with quotes if needed
    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
    
    // MARK: - Single Session Export

    /// Generates a manifest-style CSV for a single session, mirroring the weekly report format
    static func generateSingleSessionManifest(
        for session: AttendanceSession,
        list: AttendeeList,
        driverDetails: DriverDetails?,
        passengerNotes: [PassengerNote] = []
    ) -> String {
        var csv = ""

        let sessionTypeName = session.sessionType == .pickup ? "AM Pickup" : "PM Dropoff"
        let sessionDate = TimestampFormatter.formatDateLong(session.createdDate)

        // HEADER SECTION
        csv += "SESSION REPORT - \(sessionTypeName) - \(sessionDate)\n"
        csv += "\n"
        csv += "ROUTE:,\(list.name)\n"
        csv += "REGISTRATION:,\(driverDetails?.busRego ?? "N/A")\n"
        csv += "DRIVER:,\(driverDetails?.name ?? "N/A")\n"
        csv += "PHONE:,\(driverDetails?.phoneNo ?? "N/A")\n"
        csv += "EMAIL:,\(driverDetails?.email ?? "N/A")\n"
        csv += "\n"

        // ATTENDANCE TABLE HEADERS
        // Columns: Name | [Date] Pickup | [Date] Dropoff | Address | Mother's Phone | Mother's Name | Father's Phone | Father's Name | Student's Phone
        let shortDate = TimestampFormatter.formatDate(session.createdDate)
        csv += "Name"
        csv += ",\(shortDate) AM Pickup,\(shortDate) PM Dropoff"
        csv += ",Address,Mother's Phone,Mother's Name,Father's Phone,Father's Name,Student's Phone"
        csv += "\n"

        let sortedAttendees = list.attendees.sorted { $0.orderIndex < $1.orderIndex }

        // DATA ROWS
        for attendee in sortedAttendees {
            csv += escapeCSV(attendee.name)

            // Pickup column
            csv += ","
            if session.sessionType == .pickup {
                if let record = session.records.first(where: { $0.attendeeId == attendee.id }) {
                    if record.status == .present, let ts = record.timestamp {
                        csv += TimestampFormatter.formatTimeShort12Hour(ts)
                    } else {
                        csv += "Absent"
                    }
                } else {
                    csv += "Absent"
                }
            }
            // else leave blank — this is a dropoff-only session

            // Dropoff column
            csv += ","
            if session.sessionType == .dropoff {
                if let record = session.records.first(where: { $0.attendeeId == attendee.id }) {
                    if record.status == .present, let ts = record.timestamp {
                        csv += TimestampFormatter.formatTimeShort12Hour(ts)
                    } else {
                        csv += "Absent"
                    }
                } else {
                    csv += "Absent"
                }
            }
            // else leave blank — this is a pickup-only session

            // Contact detail columns: Address | Mother's Phone | Mother's Name | Father's Phone | Father's Name | Student's Phone
            csv += ","
            csv += escapeCSV(attendee.address)
            csv += ","
            csv += escapeCSV(attendee.primaryPhone)       // Mother's Phone
            csv += ","
            csv += escapeCSV(attendee.motherName)         // Mother's Name
            csv += ","
            csv += escapeCSV(attendee.secondaryPhone)     // Father's Phone
            csv += ","
            csv += escapeCSV(attendee.fatherName)         // Father's Name
            csv += ","
            csv += escapeCSV(attendee.studentPhone)       // Student's Phone
            csv += "\n"
        }

        csv += "\n"

        // JOURNEY START TIME ROW
        csv += "Journey Start Time"
        csv += ","
        if session.sessionType == .pickup, let start = session.sessionStartTimestamp {
            csv += TimestampFormatter.formatTimeShort12Hour(start)
        }
        csv += ","
        if session.sessionType == .dropoff, let start = session.sessionStartTimestamp {
            csv += TimestampFormatter.formatTimeShort12Hour(start)
        }
        csv += "\n"

        // FINAL CHECK ROW
        csv += "No Child Left On Bus"
        csv += ","
        if session.sessionType == .pickup, let fc = session.finalCheckTimestamp {
            csv += TimestampFormatter.formatTimeShort12Hour(fc)
        }
        csv += ","
        if session.sessionType == .dropoff, let fc = session.finalCheckTimestamp {
            csv += TimestampFormatter.formatTimeShort12Hour(fc)
        }
        csv += "\n\n"

        // Total columns = 1 (Name) + 2 (Pickup/Dropoff) + 6 (contact details) = 9
        let columnSpan = String(repeating: ",", count: 8)

        // TRAVEL NOTES SECTION
        csv += "TRAVEL NOTES\(columnSpan)\n"
        csv += "Student Name,Notes\(String(repeating: ",", count: 7))\n"
        for attendee in sortedAttendees where !attendee.notes.isEmpty {
            csv += escapeCSV(attendee.name)
            csv += ","
            csv += escapeCSV(attendee.notes)
            csv += String(repeating: ",", count: 7)
            csv += "\n"
        }

        // PASSENGER NOTES SECTION
        if !passengerNotes.isEmpty {
            csv += "\n"
            csv += "PASSENGER NOTES\(columnSpan)\n"
            let sortedNotes = passengerNotes.sorted {
                $0.attendeeName != $1.attendeeName ? $0.attendeeName < $1.attendeeName : $0.fromDate < $1.fromDate
            }
            for note in sortedNotes {
                let fromStr = formatDateLong(note.fromDate)
                let toStr = formatDateLong(note.toDate)
                let line = "\(note.attendeeName): \(fromStr) to \(toStr) \(note.noteText)"
                csv += escapeCSV(line)
                csv += columnSpan
                csv += "\n"
            }
        }

        return csv
    }
    
    /// Generates filename for a single session export
    static func generateFilename(for session: AttendanceSession, list: AttendeeList) -> String {
        let dateStr = TimestampFormatter.formatDate(session.createdDate)
        let timeStr = TimestampFormatter.formatTimeShort12Hour(session.createdDate)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let sessionType = session.sessionType == .pickup ? "AMPickup" : "PMDropoff"
        let listName = sanitizeFilename(list.name)
        
        return "Session_\(listName)_\(sessionType)_\(dateStr)_\(timeStr).csv"
    }
    
    // MARK: - File Naming
    
    /// Generates filename for weekly manifest report
    static func generateManifestFilename(for list: AttendeeList, weekStartDate: Date) -> String {
        let calendar = Calendar.current
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
        
        let startDateStr = TimestampFormatter.formatDate(weekStartDate)
        let endDateStr = TimestampFormatter.formatDate(weekEndDate)
        let listName = sanitizeFilename(list.name)
        
        return "\(listName)_\(startDateStr)_to_\(endDateStr).csv"
    }
    
    // MARK: - Helpers
    
    /// Removes invalid characters from filename
    private static func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
    
    // MARK: - Save to File
    
    /// Saves CSV content to temporary file and returns URL
    static func saveToTemporaryFile(csvContent: String, filename: String) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to save CSV: \(error)")
            return nil
        }
    }
}



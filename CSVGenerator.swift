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
        // Columns: Name | Grade | Mon Pickup | Mon Dropoff | ... | Fri Pickup | Fri Dropoff | Address | Primary Contact | Primary Tag | Secondary Contact | Secondary Tag
        csv += "Name,"

        // Add weekday columns with Pickup/Dropoff sub-columns (Mon-Fri)
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        for day in weekdays {
            csv += ",\(day) Pickup,\(day) Dropoff"
        }

        // Contact detail columns
        csv += ",Address,Primary Phone,Primary Contact,Secondary Phone,Secondary Contact"
        csv += "\n"
        
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
                
                // Check if this day is in the future
                let isDayInFuture = calendar.compare(dayDate, to: today, toGranularity: .day) == .orderedDescending
                
                // Pickup timestamp
                csv += ","
                if isDayInFuture {
                    // Leave blank for future dates
                    csv += ""
                } else {
                    let pickupTimestamp = getPickupTimestamp(for: attendee.id, on: dayDate, in: sessions)
                    if let time = pickupTimestamp {
                        csv += TimestampFormatter.formatTimeShort12Hour(time)
                    } else {
                        csv += "Absent"
                    }
                }
                
                // Dropoff timestamp
                csv += ","
                if isDayInFuture {
                    // Leave blank for future dates
                    csv += ""
                } else {
                    let dropoffTimestamp = getDropoffTimestamp(for: attendee.id, on: dayDate, in: sessions)
                    if let time = dropoffTimestamp {
                        csv += TimestampFormatter.formatTimeShort12Hour(time)
                    } else {
                        csv += "Absent"
                    }
                }
            }
            // Contact detail columns
            csv += ","
            csv += escapeCSV(attendee.address)
            csv += ","
            csv += escapeCSV(attendee.primaryPhone)
            csv += ","
            csv += escapeCSV(attendee.primaryPhoneTag.rawValue)
            csv += ","
            csv += escapeCSV(attendee.secondaryPhone)
            csv += ","
            csv += escapeCSV(attendee.secondaryPhoneTag.rawValue.isEmpty || attendee.secondaryPhone.isEmpty ? "" : attendee.secondaryPhoneTag.rawValue)
            csv += "\n"
        }

        csv += "\n"

        // JOURNEY START TIME ROW
        csv += "Journey Start Time,"
        csv += ""  // Empty for Grade column
        
        for dayOffset in 0..<5 {
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
            
            // Get pickup session for this day
            let pickupSession = sessions.first {
                $0.sessionType == .pickup &&
                calendar.isDate($0.createdDate, inSameDayAs: dayDate)
            }
            
            // Pickup session start time
            csv += ","
            if let pickupStart = pickupSession?.sessionStartTimestamp {
                csv += TimestampFormatter.formatTimeShort12Hour(pickupStart)
            } else {
                csv += ""
            }
            
            // Get dropoff session for this day
            let dropoffSession = sessions.first {
                $0.sessionType == .dropoff &&
                calendar.isDate($0.createdDate, inSameDayAs: dayDate)
            }
            
            // Dropoff session start time
            csv += ","
            if let dropoffStart = dropoffSession?.sessionStartTimestamp {
                csv += TimestampFormatter.formatTimeShort12Hour(dropoffStart)
            } else {
                csv += ""
            }
        }
        csv += "\n"
        
        // FINAL CHECK ROW
        csv += "No Child Left On Bus,"
        csv += ""  // Empty for Grade column
        
        // Add final check timestamp for each day (pickup and dropoff columns)
        for dayOffset in 0..<5 {
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
            
            // Check if this day is in the future
            let isDayInFuture = calendar.compare(dayDate, to: today, toGranularity: .day) == .orderedDescending
            
            // Pickup column - show final check timestamp
            csv += ","
            if isDayInFuture {
                // Leave blank for future dates
                csv += ""
            } else {
                // Get pickup session for this day
                let pickupSession = sessions.first { 
                    $0.sessionType == .pickup && 
                    calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                }
                
                if let finalCheck = pickupSession?.finalCheckTimestamp {
                    csv += TimestampFormatter.formatTimeShort12Hour(finalCheck)
                } else {
                    csv += ""
                }
            }
            
            // Dropoff column - show final check timestamp
            csv += ","
            if isDayInFuture {
                // Leave blank for future dates
                csv += ""
            } else {
                // Get dropoff session for this day
                let dropoffSession = sessions.first { 
                    $0.sessionType == .dropoff && 
                    calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                }
                
                if let finalCheck = dropoffSession?.finalCheckTimestamp {
                    csv += TimestampFormatter.formatTimeShort12Hour(finalCheck)
                } else {
                    csv += ""
                }
            }
        }
        csv += "\n"
        csv += "\n"
        
        // Total columns = 1 (Name) + 1 (Grade) + 10 (5 days x 2) + 5 (contact details) = 17
        // To span a value across all columns, write it in col 0 then pad with 16 empty commas.
        let columnSpan = String(repeating: ",", count: 16)

        // TRAVEL NOTES SECTION
        csv += "TRAVEL NOTES\(columnSpan)\n"
        csv += "Student Name,Notes\(String(repeating: ",", count: 15))\n"

        for attendee in sortedAttendees {
            if !attendee.notes.isEmpty {
                csv += escapeCSV(attendee.name)
                csv += ","
                csv += escapeCSV(attendee.notes)
                csv += String(repeating: ",", count: 15)
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
    
    /// Gets pickup timestamp for a specific attendee on a specific date
    private static func getPickupTimestamp(for attendeeId: UUID, on date: Date, in sessions: [AttendanceSession]) -> Date? {
        let calendar = Calendar.current
        let pickupSessions = sessions.filter { 
            $0.sessionType == .pickup && calendar.isDate($0.createdDate, inSameDayAs: date)
        }
        
        for session in pickupSessions {
            if let record = session.records.first(where: { $0.attendeeId == attendeeId && $0.status == .present }) {
                return record.timestamp
            }
        }
        
        return nil
    }
    
    /// Gets dropoff timestamp for a specific attendee on a specific date
    private static func getDropoffTimestamp(for attendeeId: UUID, on date: Date, in sessions: [AttendanceSession]) -> Date? {
        let calendar = Calendar.current
        let dropoffSessions = sessions.filter { 
            $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: date)
        }
        
        for session in dropoffSessions {
            if let record = session.records.first(where: { $0.attendeeId == attendeeId && $0.status == .present }) {
                return record.timestamp
            }
        }
        
        return nil
    }
    
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

        let sessionTypeName = session.sessionType == .pickup ? "Pick-Up" : "Drop-Off"
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
        // Columns: Name | [Date] Pickup | [Date] Dropoff | Address | Primary Phone | Primary Contact | Secondary Phone | Secondary Contact
        let shortDate = TimestampFormatter.formatDate(session.createdDate)
        csv += "Name"
        csv += ",\(shortDate) Pickup,\(shortDate) Dropoff"
        csv += ",Address,Primary Phone,Primary Contact,Secondary Phone,Secondary Contact"
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

            // Contact detail columns
            csv += ","
            csv += escapeCSV(attendee.address)
            csv += ","
            csv += escapeCSV(attendee.primaryPhone)
            csv += ","
            csv += escapeCSV(attendee.primaryPhoneTag.rawValue)
            csv += ","
            csv += escapeCSV(attendee.secondaryPhone)
            csv += ","
            csv += escapeCSV(attendee.secondaryPhone.isEmpty ? "" : attendee.secondaryPhoneTag.rawValue)
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

        // Total columns = 1 (Name) + 2 (Pickup/Dropoff) + 5 (contact details) = 8
        let columnSpan = String(repeating: ",", count: 7)

        // TRAVEL NOTES SECTION
        csv += "TRAVEL NOTES\(columnSpan)\n"
        csv += "Student Name,Notes\(String(repeating: ",", count: 6))\n"
        for attendee in sortedAttendees where !attendee.notes.isEmpty {
            csv += escapeCSV(attendee.name)
            csv += ","
            csv += escapeCSV(attendee.notes)
            csv += String(repeating: ",", count: 6)
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
        let sessionType = session.sessionType == .pickup ? "Pickup" : "Dropoff"
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



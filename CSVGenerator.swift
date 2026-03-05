//
//  CSVGenerator.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//

import Foundation

struct CSVGenerator {
    
    // MARK: - Single Session Export
    
    /// Generates CSV content for a single session
    static func generateCSV(for session: AttendanceSession, list: AttendeeList) -> String {
        var csv = ""
        
        // Header with metadata
        csv += "Report Generated: \(TimestampFormatter.formatDateTimeFull(Date()))\n"
        csv += "List: \(list.name)\n"
        csv += "Session Type: \(session.sessionType == .pickup ? "Pick-Up" : "Drop-Off")\n"
        csv += "Session Date: \(TimestampFormatter.formatDateLong(session.createdDate))\n"
        csv += "Session Time: \(TimestampFormatter.formatTime(session.createdDate))\n"
        csv += "\n"
        
        // Column headers
        csv += "Serial Number,Attendee Name,Status,Timestamp\n"
        
        // Sort records by attendee order in the list
        let sortedRecords = session.records.sorted { record1, record2 in
            let index1 = list.attendees.firstIndex { $0.id == record1.attendeeId } ?? 999
            let index2 = list.attendees.firstIndex { $0.id == record2.attendeeId } ?? 999
            return index1 < index2
        }
        
        // Data rows
        for (index, record) in sortedRecords.enumerated() {
            let serialNumber = index + 1
            let attendeeName = getAttendeeName(for: record.attendeeId, in: list)
            let status = record.status == .present ? "Present" : "Absent"
            let timestamp = TimestampFormatter.formatForCSV(timestamp: record.timestamp)
            
            csv += "\(serialNumber),\"\(attendeeName)\",\(status),\(timestamp)\n"
        }
        
        return csv
    }
    
    // MARK: - Multiple Sessions Export (Date Range)
    
    /// Generates CSV content for multiple sessions
    static func generateCSV(for sessions: [AttendanceSession], list: AttendeeList, dateRange: (start: Date, end: Date)? = nil) -> String {
        var csv = ""
        
        // Header with metadata
        csv += "Report Generated: \(TimestampFormatter.formatDateTimeFull(Date()))\n"
        csv += "List: \(list.name)\n"
        
        if let dateRange = dateRange {
            csv += "Date Range: \(TimestampFormatter.formatDate(dateRange.start)) to \(TimestampFormatter.formatDate(dateRange.end))\n"
        } else {
            csv += "All Sessions\n"
        }
        csv += "\n"
        
        // Column headers
        csv += "Serial Number,Attendee Name,Date,Session Type,Status,Timestamp\n"
        
        // Sort sessions by date (oldest first for reports)
        let sortedSessions = sessions.sorted { $0.createdDate < $1.createdDate }
        
        var serialNumber = 1
        
        // Process each session
        for session in sortedSessions {
            let sortedRecords = session.records.sorted { record1, record2 in
                let index1 = list.attendees.firstIndex { $0.id == record1.attendeeId } ?? 999
                let index2 = list.attendees.firstIndex { $0.id == record2.attendeeId } ?? 999
                return index1 < index2
            }
            
            for record in sortedRecords {
                let attendeeName = getAttendeeName(for: record.attendeeId, in: list)
                let date = TimestampFormatter.formatDate(session.createdDate)
                let sessionType = session.sessionType == .pickup ? "Pick-Up" : "Drop-Off"
                let status = record.status == .present ? "Present" : "Absent"
                let timestamp = TimestampFormatter.formatForCSV(timestamp: record.timestamp)
                
                csv += "\(serialNumber),\"\(attendeeName)\",\(date),\(sessionType),\(status),\(timestamp)\n"
                serialNumber += 1
            }
        }
        
        return csv
    }
    
    // MARK: - Daily Report (Today's Sessions)
    
    /// Generates CSV for today's sessions
    static func generateTodayReport(for sessions: [AttendanceSession], list: AttendeeList) -> String {
        let today = Date()
        let todaySessions = sessions.filter { Calendar.current.isDate($0.createdDate, inSameDayAs: today) }
        
        var csv = ""
        
        // Header with metadata
        csv += "Report Generated: \(TimestampFormatter.formatDateTimeFull(Date()))\n"
        csv += "List: \(list.name)\n"
        csv += "Report Date: \(TimestampFormatter.formatDateLong(today))\n"
        csv += "\n"
        
        // Column headers
        csv += "Serial Number,Attendee Name,Pick-up Timestamp,Drop-off Timestamp\n"
        
        // Create a map of attendees with their pick-up and drop-off records
        var attendeeRecords: [UUID: (name: String, pickup: Date?, dropoff: Date?)] = [:]
        
        for attendee in list.attendees {
            attendeeRecords[attendee.id] = (name: attendee.name, pickup: nil, dropoff: nil)
        }
        
        // Fill in the timestamps
        for session in todaySessions {
            for record in session.records {
                if var existing = attendeeRecords[record.attendeeId] {
                    if session.sessionType == .pickup && record.status == .present {
                        existing.pickup = record.timestamp
                    } else if session.sessionType == .dropoff && record.status == .present {
                        existing.dropoff = record.timestamp
                    }
                    attendeeRecords[record.attendeeId] = existing
                }
            }
        }
        
        // Sort by original list order
        let sortedAttendees = list.attendees.sorted { $0.orderIndex < $1.orderIndex }
        
        // Generate rows
        for (index, attendee) in sortedAttendees.enumerated() {
            let serialNumber = index + 1
            if let data = attendeeRecords[attendee.id] {
                let pickupTime = TimestampFormatter.formatForCSV(timestamp: data.pickup)
                let dropoffTime = TimestampFormatter.formatForCSV(timestamp: data.dropoff)
                csv += "\(serialNumber),\"\(data.name)\",\(pickupTime),\(dropoffTime)\n"
            }
        }
        
        return csv
    }
    
    // MARK: - File Naming
    
    /// Generates appropriate filename for a single session
    static func generateFilename(for session: AttendanceSession, list: AttendeeList) -> String {
        let date = TimestampFormatter.formatDate(session.createdDate)
        let time = TimestampFormatter.formatTimeShort(session.createdDate).replacingOccurrences(of: ":", with: "-")
        let type = session.sessionType == .pickup ? "Pickup" : "Dropoff"
        let listName = sanitizeFilename(list.name)
        
        return "\(date)_\(time)_\(type)_\(listName).csv"
    }
    
    /// Generates filename for date range report
    static func generateFilename(for list: AttendeeList, dateRange: (start: Date, end: Date)? = nil) -> String {
        let listName = sanitizeFilename(list.name)
        
        if let dateRange = dateRange {
            let startDate = TimestampFormatter.formatDate(dateRange.start)
            let endDate = TimestampFormatter.formatDate(dateRange.end)
            return "\(startDate)_to_\(endDate)_\(listName).csv"
        } else {
            let date = TimestampFormatter.formatDate(Date())
            return "\(date)_All_Sessions_\(listName).csv"
        }
    }
    
    /// Generates filename for today's report
    static func generateTodayFilename(for list: AttendeeList) -> String {
        let date = TimestampFormatter.formatDate(Date())
        let listName = sanitizeFilename(list.name)
        return "\(date)_\(listName).csv"
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
    
    /// Gets attendee name by ID
    private static func getAttendeeName(for attendeeId: UUID, in list: AttendeeList) -> String {
        return list.attendees.first { $0.id == attendeeId }?.name ?? "Unknown"
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

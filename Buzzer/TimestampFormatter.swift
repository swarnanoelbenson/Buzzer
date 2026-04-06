//
//  TimestampFormatter.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import Foundation

struct TimestampFormatter {
    
    // MARK: - Time Formatting
    
    /// Formats a date as HH:MM:SS (24-hour format)
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    /// Formats a date as HH:MM (24-hour format, without seconds)
    static func formatTimeShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    /// Formats time in 12-hour short format (e.g., "7:05am")
    static func formatTimeShort12Hour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date).lowercased()
    }
    
    /// Formats time in 12-hour format with space (e.g., "3:35 PM")
    static func formatTime12Hour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    

    
    // MARK: - ISO 8601 Formatting
    
    /// Converts a date to ISO 8601 format for storage
    static func toISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
    
    /// Converts an ISO 8601 string to a Date
    static func fromISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
    
    // MARK: - Date Formatting
    
    /// Formats a date as YYYY-MM-DD
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// Formats a date as "Month Day, Year" (e.g., "March 4, 2026")
    static func formatDateLong(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Formats a date as "MMM d" (e.g., "Mar 4")
    static func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Combined Date and Time
    
    /// Formats date and time as "MMM d, h:mm a" (e.g., "Mar 4, 8:15 AM")
    static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
    
    /// Formats date and time as "YYYY-MM-DD HH:MM:SS"
    static func formatDateTimeFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // MARK: - Relative Time
    
    /// Returns a relative time string (e.g., "2 hours ago", "just now")
    static func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - CSV Formatting
    
    /// Formats timestamp for CSV export (7:05am format or "Absent")
    static func formatForCSV(timestamp: Date?) -> String {
        guard let timestamp = timestamp else {
            return "Absent"
        }
        return formatTimeShort12Hour(timestamp)
    }
    
    // MARK: - Helpers
    
    /// Checks if two dates are on the same day
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    /// Returns the start of day for a given date
    static func startOfDay(for date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }
    
    /// Returns the end of day for a given date
    static func endOfDay(for date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay(for: date)) ?? date
    }
}

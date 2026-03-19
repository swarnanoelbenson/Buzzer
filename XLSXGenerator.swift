//
//  XLSXGenerator.swift
//  Buzzer
//

import Foundation
import libxlsxwriter

struct XLSXGenerator {

    // MARK: - Column layout constants
    // Col 0: Name
    // Col 1: Grade
    // Col 2–11: Mon Pickup, Mon Dropoff … Fri Pickup, Fri Dropoff  (5 days × 2 = 10 cols)
    // Col 12: Address
    // Col 13: Primary Phone
    // Col 14: Primary Contact
    // Col 15: Secondary Phone
    // Col 16: Secondary Contact
    // Total: 17 columns (0–16)

    private static let lastCol: lxw_col_t = 16

    // MARK: - Public entry point

    static func generateWeeklyManifest(
        for sessions: [AttendanceSession],
        list: AttendeeList,
        weekStartDate: Date,
        driverDetails: DriverDetails?,
        passengerNotes: [PassengerNote] = []
    ) -> URL? {
        let filename = generateManifestFilename(for: list, weekStartDate: weekStartDate)
        let tempURL  = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let path     = tempURL.path

        guard let workbook = workbook_new((path as NSString).fileSystemRepresentation) else { return nil }
        guard let ws       = workbook_add_worksheet(workbook, nil) else {
            workbook_close(workbook); return nil
        }

        // ── Formats ─────────────────────────────────────────────────────────
        let fTitle          = makeFormat(workbook) { f in
            format_set_bold(f); format_set_font_size(f, 14)
        }
        let fMeta           = makeFormat(workbook) { f in
            format_set_bold(f)
        }
        let fHeader         = makeFormat(workbook) { f in
            format_set_bold(f)
            format_set_bg_color(f, 0x2E75B6)
            format_set_font_color(f, 0xFFFFFF)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
        }
        let fHeaderContact  = makeFormat(workbook) { f in
            format_set_bold(f)
            format_set_bg_color(f, 0x375623)
            format_set_font_color(f, 0xFFFFFF)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
        }
        let fCell           = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
        }
        let fCellLeft       = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
        }
        let fAbsent         = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
            format_set_font_color(f, 0xFF0000)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
        }
        let fSectionHeader  = makeFormat(workbook) { f in
            format_set_bold(f)
            format_set_bg_color(f, 0xD6DCE4)
            format_set_font_size(f, 12)
        }
        let fNoteMerged     = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
            format_set_bg_color(f, 0xFFF2CC)
            format_set_align(f, UInt8(LXW_ALIGN_LEFT.rawValue))
            format_set_align(f, UInt8(LXW_ALIGN_VERTICAL_CENTER.rawValue))
        }

        // ── Column widths ───────────────────────────────────────────────────
        worksheet_set_column(ws, 0,  0,  25, nil)   // Name
        worksheet_set_column(ws, 1,  1,  10, nil)   // Grade
        for col in stride(from: lxw_col_t(2), through: lxw_col_t(11), by: 1) {
            worksheet_set_column(ws, col, col, 17, nil) // Day Pickup/Dropoff ("Wednesday Pickup")
        }
        worksheet_set_column(ws, 12, 12, 35, nil)   // Address
        worksheet_set_column(ws, 13, 13, 16, nil)   // Primary Phone
        worksheet_set_column(ws, 14, 14, 14, nil)   // Primary Contact
        worksheet_set_column(ws, 15, 15, 16, nil)   // Secondary Phone
        worksheet_set_column(ws, 16, 16, 14, nil)   // Secondary Contact

        // ── Track current row ────────────────────────────────────────────────
        var row: lxw_row_t = 0

        // ── Report title ─────────────────────────────────────────────────────
        worksheet_set_row(ws, row, 24, nil)
        worksheet_merge_range(ws, row, 0, row, lastCol,
                              "WEEKLY REPORT - \(TimestampFormatter.formatDateLong(weekStartDate))", fTitle)
        row += 1; row += 1

        // ── Driver / route meta ───────────────────────────────────────────────
        for (label, value) in [
            ("ROUTE",        list.name),
            ("REGISTRATION", driverDetails?.busRego ?? "N/A"),
            ("DRIVER",       driverDetails?.name    ?? "N/A"),
            ("PHONE",        driverDetails?.phoneNo ?? "N/A"),
            ("EMAIL",        driverDetails?.email   ?? "N/A")
        ] {
            worksheet_set_row(ws, row, 16, nil)
            writeStr(ws, row, 0, label, fMeta)
            writeStr(ws, row, 1, value, nil)
            row += 1
        }
        row += 1

        // ── Column headers ───────────────────────────────────────────────────
        worksheet_set_row(ws, row, 22, nil)
        writeStr(ws, row, 0, "Name",  fHeader)
        writeStr(ws, row, 1, "Grade", fHeader)

        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        for (i, day) in weekdays.enumerated() {
            let pickupCol  = lxw_col_t(2 + i * 2)
            let dropoffCol = lxw_col_t(3 + i * 2)
            writeStr(ws, row, pickupCol,  "\(day) Pickup",  fHeader)
            writeStr(ws, row, dropoffCol, "\(day) Dropoff", fHeader)
        }
        writeStr(ws, row, 12, "Address",           fHeaderContact)
        writeStr(ws, row, 13, "Primary Phone",     fHeaderContact)
        writeStr(ws, row, 14, "Primary Contact",   fHeaderContact)
        writeStr(ws, row, 15, "Secondary Phone",   fHeaderContact)
        writeStr(ws, row, 16, "Secondary Contact", fHeaderContact)
        row += 1

        // ── Data rows ─────────────────────────────────────────────────────────
        let calendar        = Calendar.current
        let today           = Date()
        let sortedAttendees = list.attendees.sorted { $0.orderIndex < $1.orderIndex }

        for attendee in sortedAttendees {
            worksheet_set_row(ws, row, 18, nil)
            writeStr(ws, row, 0, attendee.name,  fCellLeft)
            writeStr(ws, row, 1, attendee.grade, fCell)

            for dayOffset in 0..<5 {
                let dayDate    = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
                let isFuture   = calendar.compare(dayDate, to: today, toGranularity: .day) == .orderedDescending
                let pickupCol  = lxw_col_t(2 + dayOffset * 2)
                let dropoffCol = lxw_col_t(3 + dayOffset * 2)

                if isFuture {
                    writeStr(ws, row, pickupCol,  "", fCell)
                    writeStr(ws, row, dropoffCol, "", fCell)
                } else {
                    if let t = getPickupTimestamp(for: attendee.id, on: dayDate, in: sessions) {
                        writeStr(ws, row, pickupCol, TimestampFormatter.formatTimeShort12Hour(t), fCell)
                    } else {
                        writeStr(ws, row, pickupCol, "Absent", fAbsent)
                    }
                    if let t = getDropoffTimestamp(for: attendee.id, on: dayDate, in: sessions) {
                        writeStr(ws, row, dropoffCol, TimestampFormatter.formatTimeShort12Hour(t), fCell)
                    } else {
                        writeStr(ws, row, dropoffCol, "Absent", fAbsent)
                    }
                }
            }

            writeStr(ws, row, 12, attendee.address,                                                          fCellLeft)
            writeStr(ws, row, 13, attendee.primaryPhone,                                                     fCell)
            writeStr(ws, row, 14, attendee.primaryPhoneTag.rawValue,                                         fCell)
            writeStr(ws, row, 15, attendee.secondaryPhone,                                                   fCell)
            writeStr(ws, row, 16, attendee.secondaryPhone.isEmpty ? "" : attendee.secondaryPhoneTag.rawValue, fCell)
            row += 1
        }
        row += 1

        // ── Journey start time row ────────────────────────────────────────────
        worksheet_set_row(ws, row, 18, nil)
        writeStr(ws, row, 0, "Journey Start Time", fMeta)
        for dayOffset in 0..<5 {
            let dayDate    = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
            let pickupCol  = lxw_col_t(2 + dayOffset * 2)
            let dropoffCol = lxw_col_t(3 + dayOffset * 2)
            if let t = sessions.first(where: { $0.sessionType == .pickup  && calendar.isDate($0.createdDate, inSameDayAs: dayDate) })?.sessionStartTimestamp {
                writeStr(ws, row, pickupCol,  TimestampFormatter.formatTimeShort12Hour(t), fCell)
            }
            if let t = sessions.first(where: { $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: dayDate) })?.sessionStartTimestamp {
                writeStr(ws, row, dropoffCol, TimestampFormatter.formatTimeShort12Hour(t), fCell)
            }
        }
        row += 1

        // ── No child left on bus row ──────────────────────────────────────────
        worksheet_set_row(ws, row, 18, nil)
        writeStr(ws, row, 0, "No Child Left On Bus", fMeta)
        for dayOffset in 0..<5 {
            let dayDate    = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
            let isFuture   = calendar.compare(dayDate, to: today, toGranularity: .day) == .orderedDescending
            let pickupCol  = lxw_col_t(2 + dayOffset * 2)
            let dropoffCol = lxw_col_t(3 + dayOffset * 2)
            if !isFuture {
                if let t = sessions.first(where: { $0.sessionType == .pickup  && calendar.isDate($0.createdDate, inSameDayAs: dayDate) })?.finalCheckTimestamp {
                    writeStr(ws, row, pickupCol,  TimestampFormatter.formatTimeShort12Hour(t), fCell)
                }
                if let t = sessions.first(where: { $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: dayDate) })?.finalCheckTimestamp {
                    writeStr(ws, row, dropoffCol, TimestampFormatter.formatTimeShort12Hour(t), fCell)
                }
            }
        }
        row += 1; row += 1

        // ── Travel notes section ──────────────────────────────────────────────
        let travelNotes = sortedAttendees.filter { !$0.notes.isEmpty }
        if !travelNotes.isEmpty {
            worksheet_set_row(ws, row, 22, nil)
            worksheet_merge_range(ws, row, 0, row, lastCol, "TRAVEL NOTES", fSectionHeader)
            row += 1
            for attendee in travelNotes {
                worksheet_set_row(ws, row, 36, nil)
                let travelNoteText = "\(attendee.name): \(attendee.notes)"
                worksheet_merge_range(ws, row, 0, row, lastCol, travelNoteText, fNoteMerged)
                row += 1
            }
            row += 1
        }

        // ── Passenger notes section ───────────────────────────────────────────
        if !passengerNotes.isEmpty {
            worksheet_set_row(ws, row, 22, nil)
            worksheet_merge_range(ws, row, 0, row, lastCol, "PASSENGER NOTES", fSectionHeader)
            row += 1

            let sortedNotes = passengerNotes.sorted {
                $0.attendeeName == $1.attendeeName ? $0.fromDate < $1.fromDate : $0.attendeeName < $1.attendeeName
            }
            for note in sortedNotes {
                worksheet_set_row(ws, row, 36, nil)
                let noteText = "\(note.attendeeName): \(formatDateLong(note.fromDate)) to \(formatDateLong(note.toDate)) — \(note.noteText)"
                worksheet_merge_range(ws, row, 0, row, lastCol, noteText, fNoteMerged)
                row += 1
            }
        }

        workbook_close(workbook)
        return tempURL
    }

    // MARK: - Filename

    static func generateManifestFilename(for list: AttendeeList, weekStartDate: Date) -> String {
        let calendar    = Calendar.current
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
        let start       = TimestampFormatter.formatDate(weekStartDate)
        let end         = TimestampFormatter.formatDate(weekEndDate)
        let name        = sanitizeFilename(list.name)
        return "\(name)_\(start)_to_\(end).xlsx"
    }

    // MARK: - Helpers

    /// Convenience wrapper — keeps call sites clean.
    private static func writeStr(
        _ ws: UnsafeMutablePointer<lxw_worksheet>?,
        _ row: lxw_row_t,
        _ col: lxw_col_t,
        _ value: String,
        _ format: UnsafeMutablePointer<lxw_format>?
    ) {
        worksheet_write_string(ws, row, col, (value as NSString).utf8String, format)
    }

    /// Creates a format and applies a configuration closure to it.
    private static func makeFormat(
        _ workbook: UnsafeMutablePointer<lxw_workbook>?,
        configure: (UnsafeMutablePointer<lxw_format>) -> Void
    ) -> UnsafeMutablePointer<lxw_format>? {
        guard let fmt = workbook_add_format(workbook) else { return nil }
        configure(fmt)
        return fmt
    }

    private static func formatDateLong(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date)
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func getPickupTimestamp(for attendeeId: UUID, on date: Date, in sessions: [AttendanceSession]) -> Date? {
        let calendar = Calendar.current
        for session in sessions where session.sessionType == .pickup && calendar.isDate(session.createdDate, inSameDayAs: date) {
            if let record = session.records.first(where: { $0.attendeeId == attendeeId && $0.status == .present }) {
                return record.timestamp
            }
        }
        return nil
    }

    private static func getDropoffTimestamp(for attendeeId: UUID, on date: Date, in sessions: [AttendanceSession]) -> Date? {
        let calendar = Calendar.current
        for session in sessions where session.sessionType == .dropoff && calendar.isDate(session.createdDate, inSameDayAs: date) {
            if let record = session.records.first(where: { $0.attendeeId == attendeeId && $0.status == .present }) {
                return record.timestamp
            }
        }
        return nil
    }
}

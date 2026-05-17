//
//  XLSXGenerator.swift
//  Buzzer
//

import Foundation
import libxlsxwriter

struct XLSXGenerator {

    // MARK: - Column layout constants (Weekly Manifest)
    // Col 0:  Name
    // Col 1:  Grade
    // Cols 2–21: 5 days × 4 cols each
    //   Per day: AM Scheduled | AM Actual | PM Scheduled | PM Actual
    //   Monday 2–5, Tuesday 6–9, Wednesday 10–13, Thursday 14–17, Friday 18–21
    // Total: 22 columns (0–21)

    private static let weeklyLastCol: lxw_col_t = 21

    // MARK: - Column layout constants (Single Session)
    // Col 0:  Name
    // Col 1:  {Date} AM Pickup  (actual time or "Absent" for pickup sessions; blank for dropoff)
    // Col 2:  {Date} PM Dropoff (actual time or "Absent" for dropoff sessions; blank for pickup)
    // Total: 3 columns (0–2)

    private static let sessionLastCol: lxw_col_t = 2

    // MARK: - Weekly Manifest

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
        let fTitle         = makeFormat(workbook) { f in
            format_set_bold(f); format_set_font_size(f, 14)
        }
        let fMeta          = makeFormat(workbook) { f in
            format_set_bold(f)
        }
        // Blue header for day-level labels (row 1)
        let fHeaderDay     = makeFormat(workbook) { f in
            format_set_bold(f)
            format_set_bg_color(f, 0x2E75B6)
            format_set_font_color(f, 0xFFFFFF)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
        }
        // Lighter blue for Scheduled/Actual sub-headers (row 2)
        let fHeaderSub     = makeFormat(workbook) { f in
            format_set_bold(f)
            format_set_bg_color(f, 0x9DC3E6)
            format_set_font_color(f, 0x1F3864)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
        }
        // Green header for Name/Grade
        let fHeaderMeta    = makeFormat(workbook) { f in
            format_set_bold(f)
            format_set_bg_color(f, 0x2E75B6)
            format_set_font_color(f, 0xFFFFFF)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
        }
        let fCell          = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
        }
        let fCellLeft      = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
        }
        let fAbsent        = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
            format_set_font_color(f, 0xFF0000)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
        }
        let fScheduled     = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
            format_set_font_color(f, 0x595959)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
        }
        let fSectionHeader = makeFormat(workbook) { f in
            format_set_bold(f)
            format_set_bg_color(f, 0xD6DCE4)
            format_set_font_size(f, 12)
        }
        let fNoteMerged    = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
            format_set_bg_color(f, 0xFFF2CC)
            format_set_align(f, UInt8(LXW_ALIGN_LEFT.rawValue))
            format_set_align(f, UInt8(LXW_ALIGN_VERTICAL_CENTER.rawValue))
        }

        // ── Column widths ───────────────────────────────────────────────────
        worksheet_set_column(ws, 0, 0, 25, nil)    // Name
        worksheet_set_column(ws, 1, 1, 8,  nil)    // Grade
        // Day columns: 4 per day × 5 days = cols 2–21
        for col in stride(from: lxw_col_t(2), through: lxw_col_t(21), by: 1) {
            worksheet_set_column(ws, col, col, 13, nil)
        }


        // ── Track current row ─────────────────────────────────────────────
        var row: lxw_row_t = 0

        // ── Report title ──────────────────────────────────────────────────
        worksheet_set_row(ws, row, 24, nil)
        worksheet_merge_range(ws, row, 0, row, weeklyLastCol,
                              "WEEKLY REPORT - \(TimestampFormatter.formatDateLong(weekStartDate))", fTitle)
        row += 1; row += 1

        // ── Driver / route meta ───────────────────────────────────────────
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

        // ── Header row 1: Name, Grade, day labels (merged per pair), contact labels ──
        worksheet_set_row(ws, row, 22, nil)
        writeStr(ws, row, 0, "Name",  fHeaderMeta)
        writeStr(ws, row, 1, "Grade", fHeaderMeta)

        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        for (i, day) in weekdays.enumerated() {
            let amPickupCol  = lxw_col_t(2 + i * 4)
            let amBlankCol   = lxw_col_t(3 + i * 4)
            let pmDropoffCol = lxw_col_t(4 + i * 4)
            let pmBlankCol   = lxw_col_t(5 + i * 4)
            // Merge AM Pickup label across its two sub-columns
            worksheet_merge_range(ws, row, amPickupCol,  row, amBlankCol,   "\(day) AM Pickup",  fHeaderDay)
            // Merge PM Dropoff label across its two sub-columns
            worksheet_merge_range(ws, row, pmDropoffCol, row, pmBlankCol,   "\(day) PM Dropoff", fHeaderDay)
        }
        row += 1

        // ── Header row 2: blank for Name/Grade, then Scheduled/Actual per day, blank for contacts ──
        worksheet_set_row(ws, row, 18, nil)
        writeStr(ws, row, 0, "", fHeaderMeta)   // Name blank
        writeStr(ws, row, 1, "", fHeaderMeta)   // Grade blank
        for i in 0..<5 {
            let base = lxw_col_t(2 + i * 4)
            writeStr(ws, row, base + 0, "AM Scheduled", fHeaderSub)
            writeStr(ws, row, base + 1, "AM Actual",    fHeaderSub)
            writeStr(ws, row, base + 2, "PM Scheduled", fHeaderSub)
            writeStr(ws, row, base + 3, "PM Actual",    fHeaderSub)
        }
        row += 1

        // ── Data rows ─────────────────────────────────────────────────────
        let calendar        = Calendar.current
        let today           = Date()
        let sortedAttendees = list.attendees.sorted { $0.orderIndex < $1.orderIndex }

        for attendee in sortedAttendees {
            worksheet_set_row(ws, row, 18, nil)
            writeStr(ws, row, 0, attendee.name,  fCellLeft)
            writeStr(ws, row, 1, attendee.grade, fCell)

            for dayOffset in 0..<5 {
                let dayDate   = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
                let isFuture  = calendar.compare(dayDate, to: today, toGranularity: .day) == .orderedDescending
                let base      = lxw_col_t(2 + dayOffset * 4)

                // AM Scheduled
                if let sched = attendee.pickupTime {
                    writeStr(ws, row, base + 0, TimestampFormatter.formatTimeShort12Hour(sched), fScheduled)
                } else {
                    writeStr(ws, row, base + 0, "", fCell)
                }

                // AM Actual
                if isFuture {
                    writeStr(ws, row, base + 1, "", fCell)
                } else if let pickupSession = sessions.first(where: {
                    $0.sessionType == .pickup && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                }) {
                    if let record = pickupSession.records.first(where: { $0.attendeeId == attendee.id }) {
                        if record.status == .present, let ts = record.timestamp {
                            writeStr(ws, row, base + 1, TimestampFormatter.formatTimeShort12Hour(ts), fCell)
                        } else {
                            writeStr(ws, row, base + 1, "Absent", fAbsent)
                        }
                    } else {
                        writeStr(ws, row, base + 1, "Absent", fAbsent)
                    }
                } else {
                    writeStr(ws, row, base + 1, "", fCell)
                }

                // PM Scheduled
                if let sched = attendee.dropoffTime {
                    writeStr(ws, row, base + 2, TimestampFormatter.formatTimeShort12Hour(sched), fScheduled)
                } else {
                    writeStr(ws, row, base + 2, "", fCell)
                }

                // PM Actual
                if isFuture {
                    writeStr(ws, row, base + 3, "", fCell)
                } else if let dropoffSession = sessions.first(where: {
                    $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                }) {
                    if let record = dropoffSession.records.first(where: { $0.attendeeId == attendee.id }) {
                        if record.status == .present, let ts = record.timestamp {
                            writeStr(ws, row, base + 3, TimestampFormatter.formatTimeShort12Hour(ts), fCell)
                        } else {
                            writeStr(ws, row, base + 3, "Absent", fAbsent)
                        }
                    } else {
                        writeStr(ws, row, base + 3, "Absent", fAbsent)
                    }
                } else {
                    writeStr(ws, row, base + 3, "", fCell)
                }
            }

            row += 1
        }
        row += 1

        // ── Journey start time row ────────────────────────────────────────
        worksheet_set_row(ws, row, 18, nil)
        writeStr(ws, row, 0, "Journey Start Time", fMeta)
        for dayOffset in 0..<5 {
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
            let base    = lxw_col_t(2 + dayOffset * 4)
            // Write into the AM Actual and PM Actual columns
            if let t = sessions.first(where: {
                $0.sessionType == .pickup && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
            })?.sessionStartTimestamp {
                writeStr(ws, row, base + 1, TimestampFormatter.formatTimeShort12Hour(t), fCell)
            }
            if let t = sessions.first(where: {
                $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
            })?.sessionStartTimestamp {
                writeStr(ws, row, base + 3, TimestampFormatter.formatTimeShort12Hour(t), fCell)
            }
        }
        row += 1

        // ── No child left on bus row ──────────────────────────────────────
        worksheet_set_row(ws, row, 18, nil)
        writeStr(ws, row, 0, "No Child Left On Bus", fMeta)
        for dayOffset in 0..<5 {
            let dayDate  = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
            let isFuture = calendar.compare(dayDate, to: today, toGranularity: .day) == .orderedDescending
            let base     = lxw_col_t(2 + dayOffset * 4)
            if !isFuture {
                if let t = sessions.first(where: {
                    $0.sessionType == .pickup && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                })?.finalCheckTimestamp {
                    writeStr(ws, row, base + 1, TimestampFormatter.formatTimeShort12Hour(t), fCell)
                }
                if let t = sessions.first(where: {
                    $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                })?.finalCheckTimestamp {
                    writeStr(ws, row, base + 3, TimestampFormatter.formatTimeShort12Hour(t), fCell)
                }
            }
        }
        row += 1; row += 1

        // ── Travel notes section ──────────────────────────────────────────
        let travelNotes = sortedAttendees.filter { !$0.notes.isEmpty }
        if !travelNotes.isEmpty {
            worksheet_set_row(ws, row, 22, nil)
            worksheet_merge_range(ws, row, 0, row, weeklyLastCol, "TRAVEL NOTES", fSectionHeader)
            row += 1
            for attendee in travelNotes {
                worksheet_set_row(ws, row, 36, nil)
                worksheet_merge_range(ws, row, 0, row, weeklyLastCol,
                                      "\(attendee.name): \(attendee.notes)", fNoteMerged)
                row += 1
            }
            row += 1
        }

        // ── Passenger notes section ───────────────────────────────────────
        if !passengerNotes.isEmpty {
            worksheet_set_row(ws, row, 22, nil)
            worksheet_merge_range(ws, row, 0, row, weeklyLastCol, "PASSENGER NOTES", fSectionHeader)
            row += 1
            let sortedNotes = passengerNotes.sorted {
                $0.attendeeName == $1.attendeeName ? $0.fromDate < $1.fromDate : $0.attendeeName < $1.attendeeName
            }
            for note in sortedNotes {
                worksheet_set_row(ws, row, 36, nil)
                let noteText = "\(note.attendeeName): \(formatDateLong(note.fromDate)) to \(formatDateLong(note.toDate)) — \(note.noteText)"
                worksheet_merge_range(ws, row, 0, row, weeklyLastCol, noteText, fNoteMerged)
                row += 1
            }
        }

        workbook_close(workbook)
        return tempURL
    }

    // MARK: - Single Session Manifest

    static func generateSingleSessionManifest(
        for session: AttendanceSession,
        list: AttendeeList,
        driverDetails: DriverDetails?,
        passengerNotes: [PassengerNote] = []
    ) -> URL? {
        let filename = generateSingleSessionFilename(for: session, list: list)
        let tempURL  = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let path     = tempURL.path

        guard let workbook = workbook_new((path as NSString).fileSystemRepresentation) else { return nil }
        guard let ws       = workbook_add_worksheet(workbook, nil) else {
            workbook_close(workbook); return nil
        }

        // ── Formats ──────────────────────────────────────────────────────
        let fTitle         = makeFormat(workbook) { f in
            format_set_bold(f); format_set_font_size(f, 14)
        }
        let fMeta          = makeFormat(workbook) { f in format_set_bold(f) }
        let fHeader        = makeFormat(workbook) { f in
            format_set_bold(f)
            format_set_bg_color(f, 0x2E75B6)
            format_set_font_color(f, 0xFFFFFF)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
        }
        let fCell          = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
        }
        let fCellLeft      = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
        }
        let fAbsent        = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
            format_set_font_color(f, 0xFF0000)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
        }
        let fSectionHeader = makeFormat(workbook) { f in
            format_set_bold(f)
            format_set_bg_color(f, 0xD6DCE4)
            format_set_font_size(f, 12)
        }
        let fNoteMerged    = makeFormat(workbook) { f in
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
            format_set_bg_color(f, 0xFFF2CC)
            format_set_align(f, UInt8(LXW_ALIGN_LEFT.rawValue))
            format_set_align(f, UInt8(LXW_ALIGN_VERTICAL_CENTER.rawValue))
        }

        // ── Column widths ─────────────────────────────────────────────────
        worksheet_set_column(ws, 0, 0, 25, nil)   // Name
        worksheet_set_column(ws, 1, 1, 16, nil)   // AM Pickup
        worksheet_set_column(ws, 2, 2, 16, nil)   // PM Dropoff


        var row: lxw_row_t = 0
        let sessionTypeName = session.sessionType == .pickup ? "AM Pickup" : "PM Dropoff"
        let sessionDate     = TimestampFormatter.formatDateLong(session.createdDate)
        let shortDate       = TimestampFormatter.formatDate(session.createdDate)

        // ── Title ─────────────────────────────────────────────────────────
        worksheet_set_row(ws, row, 24, nil)
        worksheet_merge_range(ws, row, 0, row, sessionLastCol,
                              "SESSION REPORT - \(sessionTypeName) - \(sessionDate)", fTitle)
        row += 1; row += 1

        // ── Meta ──────────────────────────────────────────────────────────
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

        // ── Headers ───────────────────────────────────────────────────────
        worksheet_set_row(ws, row, 22, nil)
        writeStr(ws, row, 0, "Name",                   fHeader)
        writeStr(ws, row, 1, "\(shortDate) AM Pickup",  fHeader)
        writeStr(ws, row, 2, "\(shortDate) PM Dropoff", fHeader)
        row += 1

        // ── Data rows ─────────────────────────────────────────────────────
        let sortedAttendees = list.attendees.sorted { $0.orderIndex < $1.orderIndex }

        for attendee in sortedAttendees {
            worksheet_set_row(ws, row, 18, nil)
            writeStr(ws, row, 0, attendee.name, fCellLeft)

            // AM Pickup column
            if session.sessionType == .pickup {
                if let record = session.records.first(where: { $0.attendeeId == attendee.id }) {
                    if record.status == .present, let ts = record.timestamp {
                        writeStr(ws, row, 1, TimestampFormatter.formatTimeShort12Hour(ts), fCell)
                    } else {
                        writeStr(ws, row, 1, "Absent", fAbsent)
                    }
                } else {
                    writeStr(ws, row, 1, "Absent", fAbsent)
                }
            } else {
                writeStr(ws, row, 1, "", fCell)
            }

            // PM Dropoff column
            if session.sessionType == .dropoff {
                if let record = session.records.first(where: { $0.attendeeId == attendee.id }) {
                    if record.status == .present, let ts = record.timestamp {
                        writeStr(ws, row, 2, TimestampFormatter.formatTimeShort12Hour(ts), fCell)
                    } else {
                        writeStr(ws, row, 2, "Absent", fAbsent)
                    }
                } else {
                    writeStr(ws, row, 2, "Absent", fAbsent)
                }
            } else {
                writeStr(ws, row, 2, "", fCell)
            }

            row += 1
        }
        row += 1

        // ── Journey start time ────────────────────────────────────────────
        worksheet_set_row(ws, row, 18, nil)
        writeStr(ws, row, 0, "Journey Start Time", fMeta)
        if session.sessionType == .pickup, let t = session.sessionStartTimestamp {
            writeStr(ws, row, 1, TimestampFormatter.formatTimeShort12Hour(t), fCell)
        }
        if session.sessionType == .dropoff, let t = session.sessionStartTimestamp {
            writeStr(ws, row, 2, TimestampFormatter.formatTimeShort12Hour(t), fCell)
        }
        row += 1

        // ── No child left on bus ──────────────────────────────────────────
        worksheet_set_row(ws, row, 18, nil)
        writeStr(ws, row, 0, "No Child Left On Bus", fMeta)
        if session.sessionType == .pickup, let t = session.finalCheckTimestamp {
            writeStr(ws, row, 1, TimestampFormatter.formatTimeShort12Hour(t), fCell)
        }
        if session.sessionType == .dropoff, let t = session.finalCheckTimestamp {
            writeStr(ws, row, 2, TimestampFormatter.formatTimeShort12Hour(t), fCell)
        }
        row += 1; row += 1

        // ── Travel notes ──────────────────────────────────────────────────
        let travelNotes = sortedAttendees.filter { !$0.notes.isEmpty }
        if !travelNotes.isEmpty {
            worksheet_set_row(ws, row, 22, nil)
            worksheet_merge_range(ws, row, 0, row, sessionLastCol, "TRAVEL NOTES", fSectionHeader)
            row += 1
            for attendee in travelNotes {
                worksheet_set_row(ws, row, 36, nil)
                worksheet_merge_range(ws, row, 0, row, sessionLastCol,
                                      "\(attendee.name): \(attendee.notes)", fNoteMerged)
                row += 1
            }
            row += 1
        }

        // ── Passenger notes ───────────────────────────────────────────────
        if !passengerNotes.isEmpty {
            worksheet_set_row(ws, row, 22, nil)
            worksheet_merge_range(ws, row, 0, row, sessionLastCol, "PASSENGER NOTES", fSectionHeader)
            row += 1
            let sortedNotes = passengerNotes.sorted {
                $0.attendeeName == $1.attendeeName ? $0.fromDate < $1.fromDate : $0.attendeeName < $1.attendeeName
            }
            for note in sortedNotes {
                worksheet_set_row(ws, row, 36, nil)
                let noteText = "\(note.attendeeName): \(formatDateLong(note.fromDate)) to \(formatDateLong(note.toDate)) — \(note.noteText)"
                worksheet_merge_range(ws, row, 0, row, sessionLastCol, noteText, fNoteMerged)
                row += 1
            }
        }

        workbook_close(workbook)
        return tempURL
    }

    // MARK: - Filenames

    static func generateManifestFilename(for list: AttendeeList, weekStartDate: Date) -> String {
        let calendar    = Calendar.current
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
        let start       = TimestampFormatter.formatDate(weekStartDate)
        let end         = TimestampFormatter.formatDate(weekEndDate)
        let name        = sanitizeFilename(list.name)
        return "\(name)_\(start)_to_\(end).xlsx"
    }

    static func generateSingleSessionFilename(for session: AttendanceSession, list: AttendeeList) -> String {
        let dateStr = TimestampFormatter.formatDate(session.createdDate)
        let timeStr = TimestampFormatter.formatTimeShort12Hour(session.createdDate)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let sessionType = session.sessionType == .pickup ? "AMPickup" : "PMDropoff"
        let listName    = sanitizeFilename(list.name)
        return "Session_\(listName)_\(sessionType)_\(dateStr)_\(timeStr).xlsx"
    }

    // MARK: - Private Helpers

    private static func writeStr(
        _ ws: UnsafeMutablePointer<lxw_worksheet>?,
        _ row: lxw_row_t,
        _ col: lxw_col_t,
        _ value: String,
        _ format: UnsafeMutablePointer<lxw_format>?
    ) {
        worksheet_write_string(ws, row, col, (value as NSString).utf8String, format)
    }

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
}

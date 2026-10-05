//
//  XLSXGenerator.swift
//  Buzzer
//

import Foundation
import libxlsxwriter

struct XLSXGenerator {

    // MARK: - Column layout constants (Weekly Manifest)
    // Col 0 (A):  Name
    // Col 1 (B):  Grade
    // Col 2 (C):  Scheduled AM  (shared – same pickup time for all days)
    // Col 3 (D):  Scheduled PM  (shared – same dropoff time for all days)
    // Col 4 (E):  Monday AM Actual
    // Col 5 (F):  Monday PM Actual
    // Col 6 (G):  Tuesday AM Actual
    // Col 7 (H):  Tuesday PM Actual
    // Col 8 (I):  Wednesday AM Actual
    // Col 9 (J):  Wednesday PM Actual
    // Col 10 (K): Thursday AM Actual
    // Col 11 (L): Thursday PM Actual
    // Col 12 (M): Friday AM Actual
    // Col 13 (N): Friday PM Actual
    // Total: 14 columns (0–13)

    private static let weeklyLastCol: lxw_col_t = 13

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
        // Blue header for row 1 labels
        let fHeaderDay     = makeFormat(workbook) { f in
            format_set_bold(f)
            format_set_bg_color(f, 0x2E75B6)
            format_set_font_color(f, 0xFFFFFF)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
        }
        // Lighter blue for AM/PM sub-headers (row 2)
        let fHeaderSub     = makeFormat(workbook) { f in
            format_set_bold(f)
            format_set_bg_color(f, 0x9DC3E6)
            format_set_font_color(f, 0x1F3864)
            format_set_align(f, UInt8(LXW_ALIGN_CENTER.rawValue))
            format_set_border(f, UInt8(LXW_BORDER_THIN.rawValue))
        }
        // Blue header for Name/Grade (matches row 1 style, spans two header rows)
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
        // Widths converted from inches to Excel character units (≈ 1 char = 0.0889 in at default font)
        worksheet_set_column(ws, 0, 0, 13.5, nil)   // A: Name       1.2 in
        worksheet_set_column(ws, 1, 1, 6.75, nil)   // B: Grade      0.6 in
        worksheet_set_column(ws, 2, 3, 6.75, nil)   // C:D Scheduled 0.6 in each
        for col in stride(from: lxw_col_t(4), through: lxw_col_t(13), by: 1) {
            worksheet_set_column(ws, col, col, 7.9, nil)  // E–N: actuals  0.7 in each
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

        // ── Header row 1 ──────────────────────────────────────────────────
        // A=Name, B=Grade, C:D=Scheduled, E:F=Monday Actual, G:H=Tuesday, I:J=Wed, K:L=Thu, M:N=Fri
        let tableRowHeight: Double = 18  // 0.25 inches ≈ 18 pt
        worksheet_set_row(ws, row, tableRowHeight, nil)
        writeStr(ws, row, 0, "Name",      fHeaderMeta)
        writeStr(ws, row, 1, "Grade",     fHeaderMeta)
        worksheet_merge_range(ws, row, 2, row, 3,   "Scheduled",        fHeaderDay)
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        for (i, day) in weekdays.enumerated() {
            let startCol = lxw_col_t(4 + i * 2)
            let endCol   = lxw_col_t(5 + i * 2)
            worksheet_merge_range(ws, row, startCol, row, endCol, "\(day) Actual", fHeaderDay)
        }
        row += 1

        // ── Header row 2 ──────────────────────────────────────────────────
        // blank, blank, AM, PM, AM, PM, AM, PM, AM, PM, AM, PM, AM, PM
        worksheet_set_row(ws, row, tableRowHeight, nil)
        writeStr(ws, row, 0, "", fHeaderMeta)
        writeStr(ws, row, 1, "", fHeaderMeta)
        writeStr(ws, row, 2, "AM", fHeaderSub)
        writeStr(ws, row, 3, "PM", fHeaderSub)
        for i in 0..<5 {
            let base = lxw_col_t(4 + i * 2)
            writeStr(ws, row, base + 0, "AM", fHeaderSub)
            writeStr(ws, row, base + 1, "PM", fHeaderSub)
        }
        row += 1

        // ── Data rows ─────────────────────────────────────────────────────
        let calendar        = Calendar.current
        let today           = Date()
        let sortedAttendees = list.attendees.sorted { $0.orderIndex < $1.orderIndex }

        for attendee in sortedAttendees {
            worksheet_set_row(ws, row, tableRowHeight, nil)
            writeStr(ws, row, 0, attendee.name, fCellLeft)

            // Grade: strip any "Grade " prefix so only the number is written
            let gradeValue = attendee.grade.hasPrefix("Grade ")
                ? String(attendee.grade.dropFirst("Grade ".count))
                : attendee.grade
            writeStr(ws, row, 1, gradeValue, fCell)

            // C: Scheduled AM (shared pickup time)
            if let sched = attendee.pickupTime {
                writeStr(ws, row, 2, TimestampFormatter.formatTimeShort12Hour(sched), fScheduled)
            } else {
                writeStr(ws, row, 2, "", fCell)
            }

            // D: Scheduled PM (shared dropoff time)
            if let sched = attendee.dropoffTime {
                writeStr(ws, row, 3, TimestampFormatter.formatTimeShort12Hour(sched), fScheduled)
            } else {
                writeStr(ws, row, 3, "", fCell)
            }

            // E–N: actual times per day (2 cols per day: AM actual, PM actual)
            for dayOffset in 0..<5 {
                let dayDate  = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
                let isFuture = calendar.compare(dayDate, to: today, toGranularity: .day) == .orderedDescending
                let amCol    = lxw_col_t(4 + dayOffset * 2)
                let pmCol    = lxw_col_t(5 + dayOffset * 2)

                // AM Actual
                if isFuture {
                    writeStr(ws, row, amCol, "", fCell)
                } else if let pickupSession = sessions.first(where: {
                    $0.sessionType == .pickup && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                }) {
                    if let record = pickupSession.records.first(where: { $0.attendeeId == attendee.id }) {
                        if record.status == .present, let ts = record.timestamp {
                            writeStr(ws, row, amCol, TimestampFormatter.formatTimeShort12Hour(ts), fCell)
                        } else {
                            writeStr(ws, row, amCol, "Absent", fAbsent)
                        }
                    } else {
                        writeStr(ws, row, amCol, "Absent", fAbsent)
                    }
                } else {
                    writeStr(ws, row, amCol, "", fCell)
                }

                // PM Actual
                if isFuture {
                    writeStr(ws, row, pmCol, "", fCell)
                } else if let dropoffSession = sessions.first(where: {
                    $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                }) {
                    if let record = dropoffSession.records.first(where: { $0.attendeeId == attendee.id }) {
                        if record.status == .present, let ts = record.timestamp {
                            writeStr(ws, row, pmCol, TimestampFormatter.formatTimeShort12Hour(ts), fCell)
                        } else {
                            writeStr(ws, row, pmCol, "Absent", fAbsent)
                        }
                    } else {
                        writeStr(ws, row, pmCol, "Absent", fAbsent)
                    }
                } else {
                    writeStr(ws, row, pmCol, "", fCell)
                }
            }

            row += 1
        }
        row += 1

        // ── Journey start time row ────────────────────────────────────────
        worksheet_set_row(ws, row, tableRowHeight, nil)
        writeStr(ws, row, 0, "Journey Start Time", fMeta)
        for dayOffset in 0..<5 {
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
            let amCol   = lxw_col_t(4 + dayOffset * 2)
            let pmCol   = lxw_col_t(5 + dayOffset * 2)
            if let t = sessions.first(where: {
                $0.sessionType == .pickup && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
            })?.sessionStartTimestamp {
                writeStr(ws, row, amCol, TimestampFormatter.formatTimeShort12Hour(t), fCell)
            }
            if let t = sessions.first(where: {
                $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
            })?.sessionStartTimestamp {
                writeStr(ws, row, pmCol, TimestampFormatter.formatTimeShort12Hour(t), fCell)
            }
        }
        row += 1

        // ── No child left on bus row ──────────────────────────────────────
        worksheet_set_row(ws, row, tableRowHeight, nil)
        writeStr(ws, row, 0, "No Child Left On Bus", fMeta)
        for dayOffset in 0..<5 {
            let dayDate  = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
            let isFuture = calendar.compare(dayDate, to: today, toGranularity: .day) == .orderedDescending
            let amCol    = lxw_col_t(4 + dayOffset * 2)
            let pmCol    = lxw_col_t(5 + dayOffset * 2)
            if !isFuture {
                if let t = sessions.first(where: {
                    $0.sessionType == .pickup && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                })?.finalCheckTimestamp {
                    writeStr(ws, row, amCol, TimestampFormatter.formatTimeShort12Hour(t), fCell)
                }
                if let t = sessions.first(where: {
                    $0.sessionType == .dropoff && calendar.isDate($0.createdDate, inSameDayAs: dayDate)
                })?.finalCheckTimestamp {
                    writeStr(ws, row, pmCol, TimestampFormatter.formatTimeShort12Hour(t), fCell)
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

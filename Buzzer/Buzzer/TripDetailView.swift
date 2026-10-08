//
//  TripDetailView.swift
//  Buzzer
//
//  Shows a single trip. Driver can start the trip, mark students on/off/absent,
//  and add / edit / delete notes per student (driver can manage own notes only).
//

import SwiftUI
import FirebaseFirestore

struct TripDetailView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var trip: Trip
    @State private var isStarting = false
    @State private var errorMessage: String? = nil
    @State private var routeName: String = ""
    @State private var driverName: String = ""
    @State private var driverId: String = ""

    // Notes: studentId → [FirestorePassengerNote]
    @State private var studentNotes: [String: [FirestorePassengerNote]] = [:]
    @State private var isLoadingNotes = false

    // Note sheet state
    @State private var addNoteForRecord: StudentTripRecord? = nil
    @State private var editNoteItem: FirestorePassengerNote? = nil

    init(trip: Trip) {
        _trip = State(initialValue: trip)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Trip header card
                tripHeaderCard

                // Progress bar
                if trip.status == .inProgress || trip.status == .completed {
                    progressBar
                }

                // Start button
                if trip.status == .scheduled {
                    startButton
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                // Student list with per-student notes
                VStack(spacing: 12) {
                    ForEach($trip.studentRecords) { $record in
                        StudentTripCard(
                            record: $record,
                            tripType: trip.type,
                            isActive: trip.status == .inProgress,
                            tripId: trip.id ?? "",
                            driverName: driverName,
                            notes: studentNotes[record.id] ?? [],
                            driverId: driverId,
                            onAddNote: { addNoteForRecord = record },
                            onEditNote: { editNoteItem = $0 },
                            onDeleteNote: { note in Task { await deleteNote(note, for: record.id) } }
                        )
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.top, 12)
        }
        .navigationTitle(trip.type == .pickup ? "Pick-up" : "Drop-off")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTripInfo() }
        .sheet(item: $addNoteForRecord) { record in
            DriverAddNoteSheet(
                record: record,
                trip: trip,
                driverId: driverId,
                driverName: driverName
            ) { newNote in
                studentNotes[record.id] = (studentNotes[record.id] ?? []) + [newNote]
            }
        }
        .sheet(item: $editNoteItem) { note in
            EditNoteSheet(note: note) { updated in
                for sid in studentNotes.keys {
                    if let idx = studentNotes[sid]?.firstIndex(where: { $0.id == note.id }) {
                        studentNotes[sid]?[idx] = updated
                    }
                }
            }
        }
    }

    // MARK: - Trip Header Card

    private var tripHeaderCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: trip.type == .pickup
                      ? "arrow.up.circle.fill"
                      : "arrow.down.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(trip.type == .pickup ? .green : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(routeName.isEmpty ? "Route" : routeName)
                        .font(.system(size: 22, weight: .bold))
                    Text(trip.type == .pickup ? "Pick-up Run" : "Drop-off Run")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                TripStatusBadge(status: trip.status)
            }

            Divider()

            HStack {
                Label(formattedDate, systemImage: "calendar")
                Spacer()
                Label("\(trip.studentRecords.count) students", systemImage: "person.2")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let done = trip.studentRecords.filter { $0.status != .pending }.count
        let total = trip.studentRecords.count
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Progress")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(done) / \(total)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .tint(trip.type == .pickup ? .green : .orange)
        }
        .padding(.horizontal)
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            Task { await startTrip() }
        } label: {
            Group {
                if isStarting {
                    ProgressView().tint(.white)
                } else {
                    Label("Start \(trip.type == .pickup ? "Pick-up" : "Drop-off")",
                          systemImage: "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(trip.type == .pickup ? Color.green : Color.orange)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(isStarting)
        .padding(.horizontal)
    }

    // MARK: - Data Loading

    private func loadTripInfo() async {
        if let route = try? await FirestoreService.shared.fetchRoute(id: trip.routeId) {
            routeName = route.name
        }
        if let uid = authManager.currentUserId,
           let driver = try? await FirestoreService.shared.fetchDriver(id: uid) {
            driverName = driver.name
            driverId = uid
        }
        // Sort students by stop order for this trip type
        if trip.type == .pickup {
            trip.studentRecords.sort { ($0.orderAM ?? Int.max) < ($1.orderAM ?? Int.max) }
        } else {
            trip.studentRecords.sort { ($0.orderPM ?? Int.max) < ($1.orderPM ?? Int.max) }
        }

        // Load notes for all students on this trip
        await loadNotes()
    }

    private func loadNotes() async {
        isLoadingNotes = true
        var notesMap: [String: [FirestorePassengerNote]] = [:]
        for record in trip.studentRecords {
            notesMap[record.id] = (try? await FirestoreService.shared.fetchActiveNotes(for: record.id)) ?? []
        }
        studentNotes = notesMap
        isLoadingNotes = false
    }

    private func deleteNote(_ note: FirestorePassengerNote, for studentId: String) async {
        guard let noteId = note.id else { return }
        try? await FirestoreService.shared.deletePassengerNote(id: noteId)
        studentNotes[studentId] = studentNotes[studentId]?.filter { $0.id != noteId } ?? []
    }

    private func startTrip() async {
        guard let tripId = trip.id else { return }
        isStarting = true
        do {
            try await FirestoreService.shared.startTrip(id: tripId)
            trip.status = .inProgress
            trip.startedAt = Date()

            if let uid = authManager.currentUserId {
                FirestoreService.shared.logActivity(
                    schoolId: trip.schoolId,
                    actorId: uid,
                    actorName: driverName.isEmpty ? "Driver" : driverName,
                    actorRole: "driver",
                    action: "Started \(trip.type.rawValue) trip for route \(trip.routeId)",
                    metadata: ["tripId": tripId, "routeId": trip.routeId]
                )
            }
        } catch {
            errorMessage = "Failed to start trip. Try again."
        }
        isStarting = false
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f.string(from: trip.date)
    }
}

// MARK: - StudentTripCard

struct StudentTripCard: View {
    @Binding var record: StudentTripRecord
    let tripType: TripType
    let isActive: Bool
    let tripId: String
    let driverName: String
    let notes: [FirestorePassengerNote]
    let driverId: String
    let onAddNote: () -> Void
    let onEditNote: (FirestorePassengerNote) -> Void
    let onDeleteNote: (FirestorePassengerNote) -> Void

    @State private var isUpdating = false
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Student header row
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.studentName)
                        .font(.system(size: 16, weight: .semibold))
                    Text(tripType == .pickup ? record.stopAddressAM : record.stopAddressPM)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    if let ts = record.timestamp {
                        Text(formattedTime(ts))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Action buttons
                if isActive && record.status == .pending {
                    if isUpdating {
                        ProgressView()
                            .frame(width: 80)
                    } else {
                        HStack(spacing: 8) {
                            Button {
                                Task { await markStudent(tripType == .pickup ? .onBus : .offBus) }
                            } label: {
                                Text(tripType == .pickup ? "On Bus" : "Off Bus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(tripType == .pickup ? Color.green : Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }

                            Button {
                                Task { await markStudent(.absent) }
                            } label: {
                                Text("Absent")
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                // Expand/collapse toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Notes section (collapsible)
            if isExpanded {
                Divider()
                    .padding(.leading, 74)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Notes")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(1)
                        Spacer()
                        Button {
                            onAddNote()
                        } label: {
                            Label("Add", systemImage: "plus.circle.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .tint(.blue)
                    }

                    if notes.isEmpty {
                        Text("No notes for this student.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(notes) { note in
                            NoteCard(
                                note: note,
                                canEdit: note.createdById == driverId,
                                canDelete: note.createdById == driverId,
                                onEdit: { onEditNote(note) },
                                onDelete: { onDeleteNote(note) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Computed

    private var statusIcon: String {
        switch record.status {
        case .pending:  return "clock"
        case .onBus:    return "checkmark.circle.fill"
        case .offBus:   return "checkmark.circle.fill"
        case .absent:   return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch record.status {
        case .pending:  return .secondary
        case .onBus:    return .green
        case .offBus:   return .orange
        case .absent:   return .red
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func markStudent(_ newStatus: StudentTripStatus) async {
        guard !tripId.isEmpty else { return }
        isUpdating = true
        do {
            try await FirestoreService.shared.updateStudentStatus(
                tripId: tripId,
                studentId: record.id,
                status: newStatus
            )
            record.status = newStatus
            record.timestamp = Date()

            await NotificationService.shared.notifyParents(
                studentId: record.id,
                studentName: record.studentName,
                status: newStatus,
                tripType: tripType,
                driverName: driverName
            )
        } catch {
            // Silent fail — status updates are best-effort
        }
        isUpdating = false
    }
}

// MARK: - DriverAddNoteSheet

struct DriverAddNoteSheet: View {
    let record: StudentTripRecord
    let trip: Trip
    let driverId: String
    let driverName: String
    let onAdded: (FirestorePassengerNote) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var noteText: String = ""
    @State private var tripType: TripType
    @State private var fromDate: Date = Date()
    @State private var toDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private let service = FirestoreService.shared

    init(record: StudentTripRecord, trip: Trip, driverId: String, driverName: String, onAdded: @escaping (FirestorePassengerNote) -> Void) {
        self.record = record
        self.trip = trip
        self.driverId = driverId
        self.driverName = driverName
        self.onAdded = onAdded
        _tripType = State(initialValue: trip.type)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Note for \(record.studentName)") {
                    TextField("e.g. Student will be absent next week", text: $noteText, axis: .vertical)
                        .lineLimit(3...6)

                    Picker("Trip", selection: $tripType) {
                        Text("Morning Pick-up").tag(TripType.pickup)
                        Text("Afternoon Drop-off").tag(TripType.dropoff)
                    }

                    DatePicker("From", selection: $fromDate, displayedComponents: .date)
                    DatePicker("To", selection: $toDate, in: fromDate..., displayedComponents: .date)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        let routeName = await service.routeName(for: trip.routeId)
        let note = FirestorePassengerNote(
            schoolId: trip.schoolId,
            studentId: record.id,
            studentName: record.studentName,
            routeId: trip.routeId,
            routeName: routeName,
            type: tripType,
            noteText: noteText.trimmingCharacters(in: .whitespaces),
            fromDate: Calendar.current.startOfDay(for: fromDate),
            toDate: Calendar.current.startOfDay(for: toDate),
            createdAt: Date(),
            createdById: driverId,
            createdByName: driverName,
            createdByRole: "driver",
            isDeleted: false
        )

        do {
            let ref = try await service.addPassengerNote(note)
            let saved = FirestorePassengerNote(
                id: ref.documentID,
                schoolId: note.schoolId,
                studentId: note.studentId,
                studentName: note.studentName,
                routeId: note.routeId,
                routeName: note.routeName,
                type: note.type,
                noteText: note.noteText,
                fromDate: note.fromDate,
                toDate: note.toDate,
                createdAt: note.createdAt,
                createdById: note.createdById,
                createdByName: note.createdByName,
                createdByRole: note.createdByRole,
                isDeleted: false
            )
            onAdded(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

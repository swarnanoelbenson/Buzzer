//
//  ParentPortalView.swift
//  Buzzer
//
//  Root view for the Parent portal.
//  Shows today's pickup and dropoff status for each child,
//  plus a section to add / view / delete parent notes per child.
//

import SwiftUI
import FirebaseFirestore

struct ParentPortalView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var parent: Parent? = nil
    @State private var children: [Student] = []
    @State private var todaysTrips: [Trip] = []
    @State private var childNotes: [String: [FirestorePassengerNote]] = [:]   // studentId → notes
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showOnboarding = false

    // Note sheet
    @State private var addNoteForChild: Student? = nil

    // Real-time listener handle
    @State private var tripsListener: ListenerRegistration? = nil

    private let service = FirestoreService.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    errorView(message: error)
                } else {
                    mainContent
                }
            }
            .navigationTitle("Buzzer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        tripsListener?.remove()
                        authManager.signOut()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .task {
            await loadData()
        }
        .onDisappear {
            tripsListener?.remove()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            ParentOnboardingView(onComplete: {
                showOnboarding = false
                Task { await loadData() }
            })
        }
        .sheet(item: $addNoteForChild) { child in
            if let parent {
                AddNoteSheet(child: child, parent: parent) { newNote in
                    let id = child.id ?? ""
                    childNotes[id] = (childNotes[id] ?? []) + [newNote]
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Greeting header
                if let parent {
                    greetingHeader(parent: parent)
                }

                if children.isEmpty {
                    emptyChildrenView
                } else {
                    childrenSection
                }
            }
        }
        .refreshable {
            await loadData()
        }
    }

    private func greetingHeader(parent: Parent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hello, \(parent.name.components(separatedBy: " ").first ?? parent.name)")
                .font(.title2)
                .fontWeight(.semibold)
            Text(todayDateString)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 16)
    }

    private var childrenSection: some View {
        VStack(spacing: 16) {
            ForEach(children) { child in
                ChildStatusCard(
                    child: child,
                    pickupTrip: todaysTrips.first(where: { $0.type == .pickup && $0.studentRecords.contains(where: { $0.id == child.id }) }),
                    dropoffTrip: todaysTrips.first(where: { $0.type == .dropoff && $0.studentRecords.contains(where: { $0.id == child.id }) }),
                    notes: childNotes[child.id ?? ""] ?? [],
                    onAddNote: { addNoteForChild = child },
                    onDeleteNote: { note in Task { await deleteNote(note, for: child) } }
                )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    private var emptyChildrenView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)
            Image(systemName: "person.2.slash")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("No Children Linked")
                .font(.headline)
            Text("Contact your school admin to link your children to your account.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text("Something went wrong")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task { await loadData() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let uid = authManager.currentUserId else { return }
        isLoading = true
        errorMessage = nil

        do {
            let parentDoc = try await service.fetchParent(id: uid)
            parent = parentDoc

            // Show onboarding if this parent hasn't completed their profile yet
            if !parentDoc.profileCompleted {
                isLoading = false
                showOnboarding = true
                return
            }

            let childIds = parentDoc.childIds
            children = try await service.fetchStudents(for: uid, childIds: childIds)

            // Fetch active notes for each child
            var notesMap: [String: [FirestorePassengerNote]] = [:]
            for child in children {
                if let sid = child.id {
                    notesMap[sid] = (try? await service.fetchActiveNotes(for: sid)) ?? []
                }
            }
            childNotes = notesMap

            // Initial trip load
            todaysTrips = try await service.fetchTodaysTrips(forStudentIds: childIds)

            // Start real-time listener for trip updates
            startTripsListener(childIds: childIds)

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func deleteNote(_ note: FirestorePassengerNote, for child: Student) async {
        guard let noteId = note.id else { return }
        try? await service.deletePassengerNote(id: noteId)
        let id = child.id ?? ""
        childNotes[id] = childNotes[id]?.filter { $0.id != noteId } ?? []
    }

    /// Attaches a real-time Firestore listener so trip status updates push to the UI instantly.
    private func startTripsListener(childIds: [String]) {
        tripsListener?.remove()

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        tripsListener = Firestore.db.collection("trips")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .addSnapshotListener { snapshot, error in
                guard let snapshot else { return }
                let trips = snapshot.documents.compactMap { try? $0.data(as: Trip.self) }
                // Filter to trips containing any of the parent's children
                self.todaysTrips = trips.filter { trip in
                    trip.studentRecords.contains { childIds.contains($0.id) }
                }
            }
    }

    // MARK: - Helpers

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: Date())
    }
}

// MARK: - ChildStatusCard

struct ChildStatusCard: View {
    let child: Student
    let pickupTrip: Trip?
    let dropoffTrip: Trip?
    let notes: [FirestorePassengerNote]
    let onAddNote: () -> Void
    let onDeleteNote: (FirestorePassengerNote) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(child.name)
                        .font(.headline)
                    Text(child.grade)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGroupedBackground))

            Divider()

            // Trip rows
            VStack(spacing: 0) {
                TripStatusRow(
                    label: "Morning Pick-up",
                    scheduledTime: child.scheduledPickupTime,
                    systemIcon: "arrow.up.circle.fill",
                    iconColor: .green,
                    trip: pickupTrip,
                    studentId: child.id ?? ""
                )

                Divider().padding(.leading)

                TripStatusRow(
                    label: "Afternoon Drop-off",
                    scheduledTime: child.scheduledDropoffTime,
                    systemIcon: "arrow.down.circle.fill",
                    iconColor: .orange,
                    trip: dropoffTrip,
                    studentId: child.id ?? ""
                )
            }
            .background(Color(.secondarySystemGroupedBackground))

            Divider()

            // Notes section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Notes")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)
                    Spacer()
                    Button(action: onAddNote) {
                        Label("Add Note", systemImage: "plus.circle.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .tint(.orange)
                }
                .padding(.horizontal)
                .padding(.top, 10)

                if notes.isEmpty {
                    Text("No notes for this child.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                } else {
                    ForEach(notes) { note in
                        ParentNoteRow(note: note, onDelete: { onDeleteNote(note) })
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - ParentNoteRow

struct ParentNoteRow: View {
    let note: FirestorePassengerNote
    let onDelete: () -> Void

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: note.type == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(note.type == .pickup ? .green : .orange)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.noteText)
                    .font(.subheadline)
                Text("\(dateFormatter.string(from: note.fromDate)) – \(dateFormatter.string(from: note.toDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - AddNoteSheet

struct AddNoteSheet: View {
    let child: Student
    let parent: Parent
    let onAdded: (FirestorePassengerNote) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var noteText: String = ""
    @State private var tripType: TripType = .pickup
    @State private var fromDate: Date = Date()
    @State private var toDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private let service = FirestoreService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Note Details") {
                    TextField("e.g. Mother picking up on this day", text: $noteText, axis: .vertical)
                        .lineLimit(3...6)

                    Picker("Trip", selection: $tripType) {
                        Text("Morning Pick-up").tag(TripType.pickup)
                        Text("Afternoon Drop-off").tag(TripType.dropoff)
                    }

                    DatePicker("From", selection: $fromDate, in: Date()..., displayedComponents: .date)
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
            .navigationTitle("Add Note for \(child.name.components(separatedBy: " ").first ?? child.name)")
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

        let note = FirestorePassengerNote(
            studentId: child.id ?? "",
            studentName: child.name,
            routeId: child.routeId,
            routeName: "",   // filled by service if needed
            type: tripType,
            noteText: noteText.trimmingCharacters(in: .whitespaces),
            fromDate: Calendar.current.startOfDay(for: fromDate),
            toDate: Calendar.current.startOfDay(for: toDate),
            createdAt: Date(),
            createdByParentId: parent.id ?? "",
            createdByParentName: parent.name,
            isDeleted: false
        )

        do {
            try await service.addPassengerNote(note)
            onAdded(note)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - TripStatusRow

struct TripStatusRow: View {
    let label: String
    let scheduledTime: String
    let systemIcon: String
    let iconColor: Color
    let trip: Trip?
    let studentId: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemIcon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(scheduledTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            statusBadge
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let trip {
            let studentRecord = trip.studentRecords.first(where: { $0.id == studentId })
            let studentStatus = studentRecord?.status ?? .pending
            let tripStatus = trip.status

            Group {
                switch (tripStatus, studentStatus) {
                case (.scheduled, _):
                    pill(text: "Scheduled", color: .gray)
                case (.inProgress, .pending):
                    pill(text: "En Route", color: .blue)
                case (.inProgress, .onBus):
                    pill(text: "On Bus", color: .green)
                case (.inProgress, .offBus):
                    pill(text: "Dropped Off", color: .purple)
                case (.inProgress, .absent):
                    pill(text: "Absent", color: .red)
                case (.completed, .onBus), (.completed, .offBus):
                    pill(text: "Complete", color: .green)
                case (.completed, .absent):
                    pill(text: "Absent", color: .red)
                default:
                    pill(text: "Scheduled", color: .gray)
                }
            }
        } else {
            pill(text: "No Trip", color: .gray.opacity(0.6))
        }
    }

    private func pill(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

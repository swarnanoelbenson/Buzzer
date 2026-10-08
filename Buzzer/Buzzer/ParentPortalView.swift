//
//  ParentPortalView.swift
//  Buzzer
//
//  Parent portal: left-right pager with one screen per child.
//  Each child screen shows: Notes, Live Status, Student Summary, Driver, Bus cards.
//

import SwiftUI
import FirebaseFirestore

struct ParentPortalView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var parent: Parent? = nil
    @State private var children: [Student] = []
    @State private var drivers: [String: Driver] = [:]       // routeId → driver
    @State private var routes: [String: Route] = [:]         // routeId → route
    @State private var todaysTrips: [Trip] = []
    @State private var childNotes: [String: [FirestorePassengerNote]] = [:]   // studentId → notes
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showOnboarding = false
    @State private var selectedPage = 0

    // Note sheet state
    @State private var addNoteForChild: Student? = nil
    @State private var editNote: FirestorePassengerNote? = nil

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
        .sheet(item: $editNote) { note in
            EditNoteSheet(note: note) { updated in
                for child in children {
                    let sid = child.id ?? ""
                    if var notes = childNotes[sid], let idx = notes.firstIndex(where: { $0.id == note.id }) {
                        notes[idx] = updated
                        childNotes[sid] = notes
                    }
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Greeting header
            if let parent {
                greetingHeader(parent: parent)
            }

            if children.isEmpty {
                emptyChildrenView
            } else {
                // Page indicator dots if multiple children
                if children.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(children.indices, id: \.self) { i in
                            Circle()
                                .fill(i == selectedPage ? Color.primary : Color.secondary.opacity(0.35))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                }

                TabView(selection: $selectedPage) {
                    ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                        childPage(child: child)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
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
        .padding(.vertical, 14)
    }

    // MARK: - Child Page

    private func childPage(child: Student) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                // Notes card
                notesCard(child: child)

                // Live Status card
                liveStatusCard(child: child)

                // Student Summary card
                studentSummaryCard(child: child)

                // Driver card
                driverCard(child: child)

                // Bus card
                busCard(child: child)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Notes Card

    private func notesCard(child: Student) -> some View {
        let sid = child.id ?? ""
        let notes = childNotes[sid] ?? []
        let parentId = parent?.id ?? ""

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Notes")
                Spacer()
                Button {
                    addNoteForChild = child
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .tint(.orange)
            }

            if notes.isEmpty {
                Text("No active notes.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(notes) { note in
                        NoteCard(
                            note: note,
                            canEdit: note.createdById == parentId,
                            canDelete: note.createdById == parentId,
                            onEdit: { editNote = note },
                            onDelete: { Task { await deleteNote(note, for: child) } }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Live Status Card

    private func liveStatusCard(child: Student) -> some View {
        let pickupTrip = todaysTrips.first(where: { $0.type == .pickup && $0.studentRecords.contains(where: { $0.id == child.id }) })
        let dropoffTrip = todaysTrips.first(where: { $0.type == .dropoff && $0.studentRecords.contains(where: { $0.id == child.id }) })

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Today's Status")

            VStack(spacing: 0) {
                TripStatusRow(
                    label: "Morning Pick-up",
                    scheduledTime: child.scheduledPickupTime,
                    systemIcon: "arrow.up.circle.fill",
                    iconColor: .green,
                    trip: pickupTrip,
                    studentId: child.id ?? ""
                )

                Divider().padding(.leading, 36)

                TripStatusRow(
                    label: "Afternoon Drop-off",
                    scheduledTime: child.scheduledDropoffTime,
                    systemIcon: "arrow.down.circle.fill",
                    iconColor: .orange,
                    trip: dropoffTrip,
                    studentId: child.id ?? ""
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Student Summary Card

    private func studentSummaryCard(child: Student) -> some View {
        let route = routes[child.routeId]

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Student")

            VStack(spacing: 0) {
                portalInfoRow(icon: "person.fill", iconColor: .indigo, label: "Name", value: child.name)
                Divider().padding(.leading, 36)
                portalInfoRow(icon: "graduationcap.fill", iconColor: .indigo, label: "Grade", value: child.grade)
                if let route {
                    Divider().padding(.leading, 36)
                    portalInfoRow(icon: "calendar", iconColor: .blue, label: "Term", value: "Term \(route.term) · \(route.year)")
                    Divider().padding(.leading, 36)
                    portalInfoRow(icon: "calendar.badge.clock", iconColor: .blue, label: "Schedule", value: "\(shortDate(route.startDate)) – \(shortDate(route.endDate))")
                }
                Divider().padding(.leading, 36)
                portalInfoRow(icon: "arrow.up.circle.fill", iconColor: .green, label: "Pick-up", value: "\(child.scheduledPickupTime)  ·  \(child.stopAddressAM)")
                Divider().padding(.leading, 36)
                portalInfoRow(icon: "arrow.down.circle.fill", iconColor: .orange, label: "Drop-off", value: "\(child.scheduledDropoffTime)  ·  \(child.stopAddressPM)")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Driver Card

    private func driverCard(child: Student) -> some View {
        let driver = drivers[child.routeId]

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Driver")

            if let driver {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(driver.name.prefix(1)))
                                .font(.title3.bold())
                                .foregroundColor(.blue)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(driver.name)
                            .font(.headline)
                        Text(driver.phone)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } else {
                Text("No driver assigned")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Bus Card

    private func busCard(child: Student) -> some View {
        let driver = drivers[child.routeId]
        let busRego = driver?.busRegistration ?? routes[child.routeId]?.busRegistration ?? "—"

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Bus")

            HStack(spacing: 14) {
                Image(systemName: "bus.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Registration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(busRego)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Empty / Error

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

            if !parentDoc.profileCompleted {
                isLoading = false
                showOnboarding = true
                return
            }

            let childIds = parentDoc.childIds
            children = try await service.fetchStudents(for: uid, childIds: childIds)

            // Fetch routes and drivers for each unique routeId
            var routeMap: [String: Route] = [:]
            var driverMap: [String: Driver] = [:]
            let uniqueRouteIds = Set(children.map(\.routeId))
            for routeId in uniqueRouteIds {
                if let route = try? await service.fetchRoute(id: routeId) {
                    routeMap[routeId] = route
                    if let driver = try? await service.fetchDriver(id: route.driverId) {
                        driverMap[routeId] = driver
                    }
                }
            }
            routes = routeMap
            drivers = driverMap

            // Fetch active notes for each child
            var notesMap: [String: [FirestorePassengerNote]] = [:]
            for child in children {
                if let sid = child.id {
                    notesMap[sid] = (try? await service.fetchActiveNotes(for: sid)) ?? []
                }
            }
            childNotes = notesMap

            // Initial trip load
            todaysTrips = try await service.fetchTodaysTrips(forStudentIds: childIds, schoolId: parentDoc.schoolId)

            // Start real-time listener
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
        let sid = child.id ?? ""
        childNotes[sid] = childNotes[sid]?.filter { $0.id != noteId } ?? []
    }

    private func startTripsListener(childIds: [String]) {
        tripsListener?.remove()

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        tripsListener = Firestore.db.collection("trips")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                let trips = snapshot.documents.compactMap { try? $0.data(as: Trip.self) }
                self.todaysTrips = trips.filter { trip in
                    trip.studentRecords.contains { childIds.contains($0.id) }
                }
            }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(1)
    }

    private func portalInfoRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value.isEmpty ? "—" : value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: Date())
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}

// MARK: - NoteCard (shared between Parent, Student, Driver portals)

struct NoteCard: View {
    let note: FirestorePassengerNote
    let canEdit: Bool
    let canDelete: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: note.type == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundColor(note.type == .pickup ? .green : .orange)
                            .font(.caption)
                        Text(note.type == .pickup ? "Pick-up" : "Drop-off")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(note.type == .pickup ? .green : .orange)
                        Spacer()
                        Text("\(dateFormatter.string(from: note.fromDate)) – \(dateFormatter.string(from: note.toDate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text(note.noteText)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("\(note.createdByName) · \(note.createdByRole.capitalized)")
                    .font(.caption2)
                    .foregroundColor(roleColor(note.createdByRole).opacity(0.8))

                Spacer()

                if canEdit {
                    Button { onEdit() } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                if canDelete {
                    Button { onDelete() } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
            }
        }
        .padding(12)
        .background(roleColor(note.createdByRole).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(roleColor(note.createdByRole).opacity(0.2), lineWidth: 1)
        )
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "driver": return .blue
        case "parent": return .orange
        case "admin":  return .purple
        default:       return .secondary
        }
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

        let routeName = await service.routeName(for: child.routeId)
        let note = FirestorePassengerNote(
            schoolId: parent.schoolId,
            studentId: child.id ?? "",
            studentName: child.name,
            routeId: child.routeId,
            routeName: routeName,
            type: tripType,
            noteText: noteText.trimmingCharacters(in: .whitespaces),
            fromDate: Calendar.current.startOfDay(for: fromDate),
            toDate: Calendar.current.startOfDay(for: toDate),
            createdAt: Date(),
            createdById: parent.id ?? "",
            createdByName: parent.name,
            createdByRole: "parent",
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

// MARK: - EditNoteSheet

struct EditNoteSheet: View {
    let note: FirestorePassengerNote
    let onSaved: (FirestorePassengerNote) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var noteText: String
    @State private var tripType: TripType
    @State private var fromDate: Date
    @State private var toDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    init(note: FirestorePassengerNote, onSaved: @escaping (FirestorePassengerNote) -> Void) {
        self.note = note
        self.onSaved = onSaved
        _noteText = State(initialValue: note.noteText)
        _tripType = State(initialValue: note.type)
        _fromDate = State(initialValue: note.fromDate)
        _toDate = State(initialValue: note.toDate)
    }

    private let service = FirestoreService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Edit Note") {
                    TextField("Note text", text: $noteText, axis: .vertical)
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
            .navigationTitle("Edit Note")
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
        guard let noteId = note.id else { return }
        isSaving = true
        errorMessage = nil

        do {
            try await service.updatePassengerNote(
                id: noteId,
                noteText: noteText.trimmingCharacters(in: .whitespaces),
                fromDate: Calendar.current.startOfDay(for: fromDate),
                toDate: Calendar.current.startOfDay(for: toDate),
                type: tripType
            )
            var updated = note
            updated.noteText = noteText.trimmingCharacters(in: .whitespaces)
            updated.type = tripType
            updated.fromDate = Calendar.current.startOfDay(for: fromDate)
            updated.toDate = Calendar.current.startOfDay(for: toDate)
            onSaved(updated)
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

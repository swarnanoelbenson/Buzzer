//
//  AdminStudentsView.swift
//  Buzzer
//
//  Admin view — flat list of students with their route pair.
//  Tapping a student shows full details, all trips, and passenger notes.
//  Admin can add service-suspension notes (e.g. parent will pick up) directly.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Supporting type

private struct StudentListItem: Identifiable {
    let id: String          // studentId
    let student: Student
    let routeName: String
}

// MARK: - Sort option

private enum StudentSortOption: String, CaseIterable {
    case nameAZ   = "Name (A–Z)"
    case nameZA   = "Name (Z–A)"
    case grade    = "Grade"
    case route    = "Route"
}

// MARK: - Main list

struct AdminStudentsView: View {
    @State private var items: [StudentListItem] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortOption: StudentSortOption = .nameAZ
    @State private var filterRoute: String = ""      // "" = all routes

    private let db = Firestore.db

    private var allRouteNames: [String] {
        Array(Set(items.map(\.routeName))).sorted()
    }

    private var filtered: [StudentListItem] {
        var base = items
        if !searchText.isEmpty {
            base = base.filter {
                $0.student.name.localizedCaseInsensitiveContains(searchText) ||
                $0.routeName.localizedCaseInsensitiveContains(searchText) ||
                $0.student.grade.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !filterRoute.isEmpty {
            base = base.filter { $0.routeName == filterRoute }
        }
        switch sortOption {
        case .nameAZ: return base.sorted { $0.student.name < $1.student.name }
        case .nameZA: return base.sorted { $0.student.name > $1.student.name }
        case .grade:  return base.sorted { $0.student.grade < $1.student.grade }
        case .route:  return base.sorted { $0.routeName < $1.routeName }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    ContentUnavailableView("No Students", systemImage: "graduationcap",
                                          description: Text("Create a route with students first."))
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filtered) { item in
                        NavigationLink(destination: AdminStudentDetailView(student: item.student,
                                                                           routeName: item.routeName)) {
                            AdminStudentRow(student: item.student, routeName: item.routeName)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Students")
            .searchable(text: $searchText, prompt: "Search by name, grade or route")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section("Sort") {
                            Picker("Sort", selection: $sortOption) {
                                ForEach(StudentSortOption.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                        }
                        Section("Filter by Route") {
                            Button("All Routes") { filterRoute = "" }
                            ForEach(allRouteNames, id: \.self) { name in
                                Button(name) { filterRoute = name }
                            }
                        }
                    } label: {
                        Image(systemName: filterRoute.isEmpty
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        do {
            let routeSnap = try await db.collection("routes")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            let routes = routeSnap.documents.compactMap { try? $0.data(as: Route.self) }

            var result: [StudentListItem] = []
            for route in routes {
                guard !route.studentIds.isEmpty else { continue }
                let chunks = stride(from: 0, to: route.studentIds.count, by: 30).map {
                    Array(route.studentIds[$0..<min($0 + 30, route.studentIds.count)])
                }
                for chunk in chunks {
                    let snap = try await db.collection("students")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                    for doc in snap.documents {
                        if let s = try? doc.data(as: Student.self), let sid = s.id {
                            result.append(StudentListItem(id: sid, student: s, routeName: route.name))
                        }
                    }
                }
            }

            await MainActor.run {
                items = result.sorted { $0.student.name < $1.student.name }
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Student Row

private struct AdminStudentRow: View {
    let student: Student
    let routeName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(student.name)
                .font(.headline)
            HStack(spacing: 10) {
                Label(routeName, systemImage: "bus")
                Label("Grade \(student.grade)", systemImage: "graduationcap")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Student Detail

struct AdminStudentDetailView: View {
    let student: Student
    let routeName: String

    @State private var trips: [Trip] = []
    @State private var notes: [FirestorePassengerNote] = []
    @State private var isLoading = true
    @State private var showAddNote = false

    private let db = Firestore.db

    private var pastTrips: [Trip]   { trips.filter { $0.status == .completed } }
    private var todayTrips: [Trip]  { trips.filter { Calendar.current.isDateInToday($0.date) && $0.status != .completed } }
    private var futureTrips: [Trip] { trips.filter { $0.date > Date() && !Calendar.current.isDateInToday($0.date) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: Student info card
                studentInfoCard

                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
                } else {
                    // MARK: Passenger Notes section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Service Notes")
                                .font(.headline)
                            Spacer()
                            Button {
                                showAddNote = true
                            } label: {
                                Label("Add Note", systemImage: "plus.circle.fill")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.purple)
                            }
                        }

                        if notes.isEmpty {
                            Text("No active notes for this student.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(notes) { note in
                                AdminPassengerNoteCard(note: note) {
                                    await deleteNote(note)
                                }
                            }
                        }
                    }

                    Divider()

                    // MARK: Trips
                    if !todayTrips.isEmpty  { TripSection(title: "Today",     trips: todayTrips,  routeNames: [student.routeId: routeName]) }
                    if !futureTrips.isEmpty { TripSection(title: "Upcoming",  trips: futureTrips, routeNames: [student.routeId: routeName]) }
                    if !pastTrips.isEmpty   { TripSection(title: "Completed", trips: pastTrips,   routeNames: [student.routeId: routeName]) }
                    if trips.isEmpty {
                        ContentUnavailableView("No Trips", systemImage: "calendar",
                                              description: Text("No trips found for this student."))
                    }
                }
            }
            .padding()
        }
        .navigationTitle(student.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showAddNote) {
            AdminAddNoteSheet(student: student, routeName: routeName) { newNote in
                notes.insert(newNote, at: 0)
            }
        }
    }

    // MARK: - Info Card

    private var studentInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoRow(label: "Grade",           value: student.grade)
            InfoRow(label: "Route",           value: routeName)
            if let phone = student.phone, !phone.isEmpty {
                InfoRow(label: "Phone",       value: phone)
            }
            if let email = student.email, !email.isEmpty {
                InfoRow(label: "Email",       value: email)
            }
            InfoRow(label: "Stop Location AM", value: student.stopAddressAM)
            if let orderAM = student.orderAM {
                InfoRow(label: "Order AM",    value: "\(orderAM)")
            }
            InfoRow(label: "Pick-up",         value: student.scheduledPickupTime)
            InfoRow(label: "Stop Location PM", value: student.stopAddressPM)
            if let orderPM = student.orderPM {
                InfoRow(label: "Order PM",    value: "\(orderPM)")
            }
            InfoRow(label: "Drop-off",        value: student.scheduledDropoffTime)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        guard let studentId = student.id else { isLoading = false; return }

        async let tripsTask = fetchStudentTrips(studentId: studentId)
        async let notesTask = fetchAllNotes(studentId: studentId)

        let (loadedTrips, loadedNotes) = await (tripsTask, notesTask)
        await MainActor.run {
            trips = loadedTrips.sorted { $0.date > $1.date }
            notes = loadedNotes.sorted { $0.fromDate < $1.fromDate }
            isLoading = false
        }
    }

    /// Fetch all non-deleted notes including past ones so admin sees full history.
    private func fetchAllNotes(studentId: String) async -> [FirestorePassengerNote] {
        let snap = try? await db.collection("passengerNotes")
            .whereField("studentId", isEqualTo: studentId)
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "fromDate", descending: false)
            .getDocuments()
        return (snap?.documents ?? []).compactMap { try? $0.data(as: FirestorePassengerNote.self) }
    }

    /// Fetch all trips that include this student in their studentRecords.
    private func fetchStudentTrips(studentId: String) async -> [Trip] {
        guard !student.routeId.isEmpty else { return [] }
        let snap = try? await db.collection("trips")
            .whereField("routeId", isEqualTo: student.routeId)
            .order(by: "date", descending: false)
            .getDocuments()
        let all = (snap?.documents ?? []).compactMap { try? $0.data(as: Trip.self) }
        return all.filter { $0.studentRecords.contains { $0.id == studentId } }
    }

    private func deleteNote(_ note: FirestorePassengerNote) async {
        guard let noteId = note.id else { return }
        try? await db.collection("passengerNotes").document(noteId).updateData(["isDeleted": true])
        await MainActor.run {
            notes.removeAll { $0.id == note.id }
        }
    }
}

// MARK: - Admin Add Note Sheet

struct AdminAddNoteSheet: View {
    let student: Student
    let routeName: String
    let onSaved: (FirestorePassengerNote) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fromDate = Date()
    @State private var toDate = Date()
    @State private var noteText = ""
    @State private var tripType: TripType = .pickup
    @State private var isSaving = false
    @State private var dateError = false

    private let db = Firestore.db

    var body: some View {
        NavigationStack {
            Form {
                // Student context
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(student.name)
                                .font(.headline)
                            Text(routeName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Date range
                Section {
                    DatePicker("From", selection: $fromDate, in: Date()..., displayedComponents: .date)
                    DatePicker("To", selection: $toDate, in: fromDate..., displayedComponents: .date)
                } header: {
                    Text("No-Service Date Range")
                } footer: {
                    Text("The driver, student, and parent will see this note on all trips within this range.")
                }

                // Trip type
                Section("Applies To") {
                    Picker("Trip Type", selection: $tripType) {
                        Label("Morning Pick-up", systemImage: "arrow.up.circle.fill")
                            .tag(TripType.pickup)
                        Label("Afternoon Drop-off", systemImage: "arrow.down.circle.fill")
                            .tag(TripType.dropoff)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Note text
                Section("Note") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 90)
                        .overlay(alignment: .topLeading) {
                            if noteText.isEmpty {
                                Text("e.g. Parent picking up — no bus service needed.")
                                    .foregroundStyle(Color(.placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                // Save
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save Note")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .navigationTitle("Add Service Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Invalid Date Range", isPresented: $dateError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\"From\" date must be on or before \"To\" date.")
            }
        }
    }

    private func save() async {
        let cal = Calendar.current
        let from = cal.startOfDay(for: fromDate)
        let to   = cal.startOfDay(for: toDate)
        guard from <= to else { dateError = true; return }

        isSaving = true
        let adminUid = Auth.auth().currentUser?.uid ?? "admin"
        let adminName = Auth.auth().currentUser?.displayName ?? "Admin"
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let studentId = student.id else { isSaving = false; return }

        let newNote = FirestorePassengerNote(
            schoolId: student.schoolId,
            studentId: studentId,
            studentName: student.name,
            routeId: student.routeId,
            routeName: routeName,
            type: tripType,
            noteText: trimmed,
            fromDate: from,
            toDate: to,
            createdAt: Date(),
            createdById: adminUid,
            createdByName: adminName.isEmpty ? "Admin" : adminName,
            createdByRole: "admin",
            isDeleted: false
        )

        do {
            let ref = try await FirestoreService.shared.addPassengerNote(newNote)
            let saved = FirestorePassengerNote(
                id: ref.documentID,
                schoolId: newNote.schoolId,
                studentId: newNote.studentId,
                studentName: newNote.studentName,
                routeId: newNote.routeId,
                routeName: newNote.routeName,
                type: newNote.type,
                noteText: newNote.noteText,
                fromDate: newNote.fromDate,
                toDate: newNote.toDate,
                createdAt: newNote.createdAt,
                createdById: newNote.createdById,
                createdByName: newNote.createdByName,
                createdByRole: newNote.createdByRole,
                isDeleted: false
            )
            await MainActor.run {
                onSaved(saved)
                dismiss()
            }
        } catch {
            isSaving = false
        }
    }
}

// MARK: - Admin Passenger Note Card

private struct AdminPassengerNoteCard: View {
    let note: FirestorePassengerNote
    let onDelete: () async -> Void

    @State private var showDeleteConfirm = false

    private var dateRange: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return "\(f.string(from: note.fromDate)) – \(f.string(from: note.toDate))"
    }

    private var isActive: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return note.toDate >= today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Type badge
                Label(
                    note.type == .pickup ? "Pick-up" : "Drop-off",
                    systemImage: note.type == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(note.type == .pickup ? .green : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((note.type == .pickup ? Color.green : Color.orange).opacity(0.12))
                .clipShape(Capsule())

                Spacer()

                // Active/expired badge
                Text(isActive ? "Active" : "Expired")
                    .font(.caption2.bold())
                    .foregroundStyle(isActive ? .purple : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isActive ? Color.purple : Color.gray).opacity(0.1))
                    .clipShape(Capsule())

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Circle())
                }
            }

            // Date range
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(dateRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Note text
            Text(note.noteText)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            // Created by
            Text("Added by \(note.createdByName) (\(note.createdByRole))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isActive ? Color.purple.opacity(0.2) : Color.gray.opacity(0.15), lineWidth: 1)
        )
        .confirmationDialog("Delete this note?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await onDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the note for the driver, student, and parent.")
        }
    }
}

// MARK: - Passenger Note Card (legacy — used in other views)

struct PassengerNoteCard: View {
    let note: FirestorePassengerNote

    private var dateRange: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return "\(f.string(from: note.fromDate)) – \(f.string(from: note.toDate))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(note.type == .pickup ? "Pick-up" : "Drop-off",
                      systemImage: note.type == .pickup ? "arrow.up.circle" : "arrow.down.circle")
                    .font(.caption.bold())
                    .foregroundStyle(note.type == .pickup ? .green : .orange)
                Spacer()
                Text(dateRange)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(note.noteText)
                .font(.subheadline)
            Text("By \(note.createdByName) (\(note.createdByRole))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Info Row helper

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

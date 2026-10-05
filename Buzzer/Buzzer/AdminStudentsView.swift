//
//  AdminStudentsView.swift
//  Buzzer
//
//  Admin view — flat list of students with their route pair.
//  Tapping a student shows full details, all trips, and passenger notes.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Supporting type

private struct StudentListItem: Identifiable {
    let id: String          // studentId
    let student: Student
    let routeName: String
}

// MARK: - Main list

struct AdminStudentsView: View {
    @State private var items: [StudentListItem] = []
    @State private var isLoading = true
    @State private var searchText = ""

    private let db = Firestore.db

    private var filtered: [StudentListItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.student.name.localizedCaseInsensitiveContains(searchText) ||
            $0.routeName.localizedCaseInsensitiveContains(searchText)
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
            .searchable(text: $searchText, prompt: "Search by name or route")
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        do {
            let routeSnap = try await db.collection("routes")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            let routes = try routeSnap.documents.compactMap { try? $0.data(as: Route.self) }

            var result: [StudentListItem] = []
            for route in routes {
                guard let routeId = route.id, !route.studentIds.isEmpty else { continue }
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
                    // MARK: Trips
                    if !todayTrips.isEmpty  { TripSection(title: "Today",     trips: todayTrips,  routeNames: [student.routeId: routeName]) }
                    if !futureTrips.isEmpty { TripSection(title: "Upcoming",  trips: futureTrips, routeNames: [student.routeId: routeName]) }
                    if !pastTrips.isEmpty   { TripSection(title: "Completed", trips: pastTrips,   routeNames: [student.routeId: routeName]) }
                    if trips.isEmpty {
                        ContentUnavailableView("No Trips", systemImage: "calendar",
                                              description: Text("No trips found for this student."))
                    }

                    // MARK: Passenger Notes
                    if !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Passenger Notes")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            ForEach(notes) { note in
                                PassengerNoteCard(note: note)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(student.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Info Card

    private var studentInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoRow(label: "Grade",      value: student.grade)
            InfoRow(label: "Route",      value: routeName)
            InfoRow(label: "AM Stop",    value: student.stopAddressAM)
            InfoRow(label: "PM Stop",    value: student.stopAddressPM)
            InfoRow(label: "Pickup",     value: student.scheduledPickupTime)
            InfoRow(label: "Drop-off",   value: student.scheduledDropoffTime)
            if let phone = student.phone {
                InfoRow(label: "Phone", value: phone)
            }
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
        async let notesTask = (try? FirestoreService.shared.fetchActiveNotes(for: studentId)) ?? []

        let (loadedTrips, loadedNotes) = await (tripsTask, notesTask)
        await MainActor.run {
            trips = loadedTrips.sorted { $0.date > $1.date }
            notes = loadedNotes.sorted { $0.fromDate < $1.fromDate }
            isLoading = false
        }
    }

    /// Fetch all trips that include this student in their studentRecords.
    private func fetchStudentTrips(studentId: String) async -> [Trip] {
        // Query trips by routeId, then filter client-side for this student
        guard !student.routeId.isEmpty else { return [] }
        let snap = try? await db.collection("trips")
            .whereField("routeId", isEqualTo: student.routeId)
            .order(by: "date", descending: false)
            .getDocuments()
        let all = (snap?.documents ?? []).compactMap { try? $0.data(as: Trip.self) }
        return all.filter { $0.studentRecords.contains { $0.id == studentId } }
    }
}

// MARK: - Passenger Note Card

private struct PassengerNoteCard: View {
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
            Text("By \(note.createdByParentName)")
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
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
    }
}

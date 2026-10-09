//
//  AdminDashboardView.swift
//  Buzzer
//
//  Admin dashboard — shows school name, today's date, a Notes card, and today's schedule.
//

import SwiftUI
import FirebaseFirestore

struct AdminDashboardView: View {
    @Environment(AuthManager.self) private var authManager

    var onNavigateToStudents: (() -> Void)? = nil

    @State private var schoolName: String = ""
    @State private var trips: [Trip] = []
    @State private var routeNames: [String: String] = [:]
    @State private var driverNames: [String: String] = [:]
    @State private var recentNotes: [FirestorePassengerNote] = []
    @State private var isLoading = true

    private let db = Firestore.db

    // MARK: - Date helpers

    private var todayDateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, dd MMM yyyy"
        return f.string(from: Date())
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: School name + date header (no card — sits on screen background)
                VStack(alignment: .center, spacing: 4) {
                    if !schoolName.isEmpty {
                        Text(schoolName.uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                    Text(todayDateLine)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Text("Dashboard")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

                // MARK: Notes card
                notesCard

                // MARK: Today's schedule card
                scheduleCard
            }
            .padding()
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Notes", systemImage: "note.text")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    onNavigateToStudents?()
                } label: {
                    Label("Add Note", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
            }

            if recentNotes.isEmpty {
                Text("No active notes.")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentNotes.prefix(5)) { note in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: note.type == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle(note.type == .pickup ? .green : .orange)
                                .font(.caption)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.studentName)
                                    .font(.caption.bold())
                                Text(note.noteText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text("\(formattedDate(note.fromDate)) – \(formattedDate(note.toDate))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Schedule Card

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Today's Schedule", systemImage: "calendar")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if trips.isEmpty {
                Text("No trips scheduled for today.")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(trips) { trip in
                        DashboardTripCard(
                            trip: trip,
                            routeName: routeNames[trip.routeId] ?? trip.routeId,
                            driverName: driverNames[trip.driverId] ?? "Unknown Driver"
                        )
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        guard let schoolId = authManager.schoolId else {
            isLoading = false
            return
        }

        // Fetch school name
        if let schoolDoc = try? await db.collection("schools").document(schoolId).getDocument(),
           let school = try? schoolDoc.data(as: School.self) {
            await MainActor.run { schoolName = school.schoolName }
        }

        // Fetch today's trips scoped to this school
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay   = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            let snap = try await db.collection("trips")
                .whereField("schoolId", isEqualTo: schoolId)
                .whereField("date", isGreaterThanOrEqualTo: startOfDay)
                .whereField("date", isLessThan: endOfDay)
                .order(by: "date")
                .getDocuments()
            let loaded = try snap.documents.map { try $0.data(as: Trip.self) }

            var rNames: [String: String] = [:]
            var dNames: [String: String] = [:]
            let routeIds  = Set(loaded.map(\.routeId))
            let driverIds = Set(loaded.map(\.driverId))

            await withTaskGroup(of: Void.self) { group in
                for id in routeIds {
                    group.addTask {
                        let name = await FirestoreService.shared.routeName(for: id)
                        await MainActor.run { rNames[id] = name }
                    }
                }
                for id in driverIds {
                    group.addTask {
                        let name = (try? await FirestoreService.shared.fetchDriver(id: id))?.name ?? id
                        await MainActor.run { dNames[id] = name }
                    }
                }
            }

            await MainActor.run {
                trips = loaded.sorted {
                    if $0.type != $1.type { return $0.type == .pickup }
                    return (rNames[$0.routeId] ?? "") < (rNames[$1.routeId] ?? "")
                }
                routeNames  = rNames
                driverNames = dNames
                isLoading   = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }

        // Fetch recent active notes for this school
        if let snap = try? await db.collection("passengerNotes")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("isDeleted", isEqualTo: false)
            .whereField("toDate", isGreaterThanOrEqualTo: Calendar.current.startOfDay(for: Date()))
            .order(by: "toDate", descending: true)
            .limit(to: 20)
            .getDocuments() {
            let notes = (try? snap.documents.map { try $0.data(as: FirestorePassengerNote.self) }) ?? []
            await MainActor.run { recentNotes = notes }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}

// MARK: - Dashboard Trip Card

private struct DashboardTripCard: View {
    let trip: Trip
    let routeName: String
    let driverName: String

    private var accentColor: Color { trip.type == .pickup ? .green : .orange }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: trip.type == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(routeName)
                    .font(.headline)
                HStack(spacing: 10) {
                    Label(driverName, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("\(trip.studentRecords.count) students", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
            TripStatusBadge(status: trip.status)
        }
        .padding(14)
        .background(accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}

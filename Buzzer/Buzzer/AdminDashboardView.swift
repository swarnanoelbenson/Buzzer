//
//  AdminDashboardView.swift
//  Buzzer
//
//  Admin dashboard — shows today's date/day and the list of trips scheduled for today.
//

import SwiftUI
import FirebaseFirestore

struct AdminDashboardView: View {
    @State private var trips: [Trip] = []
    @State private var routeNames: [String: String] = [:]
    @State private var driverNames: [String: String] = [:]
    @State private var isLoading = true

    private let db = Firestore.db

    // MARK: - Date helpers

    private var todayWeekday: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: Date())
    }

    private var todayFull: String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: Date())
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Date header card
                    VStack(alignment: .leading, spacing: 4) {
                        Text(todayWeekday)
                            .font(.system(size: 34, weight: .bold))
                        Text(todayFull)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // MARK: Today's trips
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading today's schedule…")
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else if trips.isEmpty {
                        ContentUnavailableView(
                            "No Trips Today",
                            systemImage: "calendar.badge.checkmark",
                            description: Text("There are no trips scheduled for today.")
                        )
                        .padding(.top, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Schedule")
                                .font(.headline)
                                .foregroundStyle(.secondary)

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
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay   = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            let snap = try await db.collection("trips")
                .whereField("date", isGreaterThanOrEqualTo: startOfDay)
                .whereField("date", isLessThan: endOfDay)
                .order(by: "date")
                .getDocuments()
            let loaded = try snap.documents.map { try $0.data(as: Trip.self) }

            // Pre-fetch route + driver names
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
                // Sort: pickup before dropoff, then by route name
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
            // Type indicator
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

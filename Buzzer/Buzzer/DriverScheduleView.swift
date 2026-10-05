//
//  DriverScheduleView.swift
//  Buzzer
//
//  Shows the driver's trips for today. Green = pick-up, Orange = drop-off.
//  Tapping a row navigates to the trip detail to start and action the trip.
//

import SwiftUI
import FirebaseFirestore

struct DriverScheduleView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var trips: [Trip] = []
    @State private var routeNames: [String: String] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading today's schedule...")
                    Spacer()
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await loadTrips() }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()
            } else if trips.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No trips scheduled for today")
                        .font(.headline)
                    Text("Check back on your next scheduled day.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                List {
                    Section {
                        ForEach(trips) { trip in
                            NavigationLink(destination: TripDetailView(trip: trip)) {
                                TripRow(trip: trip, routeName: routeNames[trip.routeId])
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(trip.type == .pickup
                                          ? Color.green.opacity(0.12)
                                          : Color.orange.opacity(0.12))
                                    .padding(.vertical, 3)
                            )
                        }
                    } header: {
                        Text(todayHeader)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .textCase(nil)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await loadTrips() }
            }
        }
        .task { await loadTrips() }
    }

    // MARK: - Helpers

    private var todayHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: Date())
    }

    private func loadTrips() async {
        guard let driverId = authManager.currentUserId else { return }
        isLoading = true
        errorMessage = nil
        do {
            trips = try await FirestoreService.shared.fetchTodaysTrips(for: driverId)
            trips.sort {
                if $0.type != $1.type { return $0.type == .pickup }
                return $0.routeId < $1.routeId
            }
            // Pre-load route names for all unique route IDs
            let uniqueRouteIds = Set(trips.map(\.routeId))
            for id in uniqueRouteIds {
                routeNames[id] = await FirestoreService.shared.routeName(for: id)
            }
        } catch {
            errorMessage = "Failed to load schedule. Check your connection."
        }
        isLoading = false
    }
}

// MARK: - Trip Row

struct TripRow: View {
    let trip: Trip
    var routeName: String?

    var body: some View {
        HStack(spacing: 14) {
            // Type indicator pill
            VStack(spacing: 4) {
                Image(systemName: trip.type == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(trip.type == .pickup ? .green : .orange)
                Text(trip.type == .pickup ? "Pick-up" : "Drop-off")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(trip.type == .pickup ? .green : .orange)
            }
            .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(routeName ?? trip.routeId)
                    .font(.system(size: 17, weight: .semibold))
                HStack(spacing: 8) {
                    Label("\(trip.studentRecords.count) students", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    TripStatusBadge(status: trip.status)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Status Badge

struct TripStatusBadge: View {
    let status: TripStatus

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .scheduled:  return "Scheduled"
        case .inProgress: return "In Progress"
        case .completed:  return "Completed"
        case .cancelled:  return "Cancelled"
        }
    }

    private var color: Color {
        switch status {
        case .scheduled:  return .blue
        case .inProgress: return .orange
        case .completed:  return .green
        case .cancelled:  return .red
        }
    }
}

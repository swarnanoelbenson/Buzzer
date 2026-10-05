//
//  DriverAllRoutesView.swift
//  Buzzer
//
//  Shows all trips assigned to the driver, grouped by date.
//

import SwiftUI

struct DriverAllRoutesView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var groupedTrips: [(date: String, trips: [Trip])] = []
    @State private var routeNames: [String: String] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading routes...")
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
                    Button("Retry") { Task { await loadAllTrips() } }
                        .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()
            } else if groupedTrips.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "map")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No routes assigned")
                        .font(.headline)
                    Text("Your scheduled routes will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                List {
                    ForEach(groupedTrips, id: \.date) { group in
                        Section(header:
                            Text(group.date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .textCase(nil)
                        ) {
                            ForEach(group.trips) { trip in
                                NavigationLink(destination: TripDetailView(trip: trip)) {
                                    TripRow(trip: trip, routeName: routeNames[trip.routeId])
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(trip.type == .pickup
                                              ? Color.green.opacity(0.10)
                                              : Color.orange.opacity(0.10))
                                        .padding(.vertical, 3)
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await loadAllTrips() }
            }
        }
        .task { await loadAllTrips() }
    }

    // MARK: - Data

    private func loadAllTrips() async {
        guard let driverId = authManager.currentUserId else { return }
        isLoading = true
        errorMessage = nil
        do {
            let trips = try await FirestoreService.shared.fetchAllTrips(for: driverId)
            groupedTrips = groupByDate(trips)
            let uniqueRouteIds = Set(trips.map(\.routeId))
            for id in uniqueRouteIds {
                routeNames[id] = await FirestoreService.shared.routeName(for: id)
            }
        } catch {
            errorMessage = "Failed to load routes. Check your connection."
        }
        isLoading = false
    }

    private func groupByDate(_ trips: [Trip]) -> [(date: String, trips: [Trip])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"

        var dict: [String: [Trip]] = [:]
        for trip in trips {
            let key = formatter.string(from: trip.date)
            dict[key, default: []].append(trip)
        }

        // Sort groups by date ascending
        return dict
            .map { (date: $0.key, trips: $0.value.sorted { $0.type == .pickup && $1.type != .pickup }) }
            .sorted { lhs, rhs in
                // Re-parse to sort chronologically
                guard let d1 = formatter.date(from: lhs.date),
                      let d2 = formatter.date(from: rhs.date) else { return false }
                return d1 < d2
            }
    }
}

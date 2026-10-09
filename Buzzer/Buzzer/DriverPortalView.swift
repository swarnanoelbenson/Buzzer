//
//  DriverPortalView.swift
//  Buzzer
//
//  Driver portal dashboard: welcome card, driver info, upcoming schedule list
//  with search / filter / sort and a "Last 3 Days" history button.
//

import SwiftUI

struct DriverPortalView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var driver: Driver? = nil
    @State private var upcomingTrips: [Trip] = []
    @State private var completedTrips: [Trip] = []
    @State private var routeNames: [String: String] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    // Search / filter / sort
    @State private var searchText = ""
    @State private var filterType: TripTypeFilter = .all
    @State private var sortOrder: TripSortOrder = .dateAscending
    @State private var showFilterSheet = false

    // History
    @State private var showHistory = false

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
            .navigationTitle("BusMate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .task { await loadData() }
        .sheet(isPresented: $showHistory) {
            DriverHistoryView()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Dashboard header
            VStack(alignment: .center, spacing: 4) {
                Text((driver?.name ?? "Driver").uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(todayDateString)
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
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search routes...", text: $searchText)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Filter/Sort toolbar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Type filter chips
                    ForEach(TripTypeFilter.allCases, id: \.self) { filter in
                        FilterChip(title: filter.label, isSelected: filterType == filter) {
                            filterType = filter
                        }
                    }

                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 2)

                    // Sort chips
                    ForEach(TripSortOrder.allCases, id: \.self) { order in
                        FilterChip(title: order.label, isSelected: sortOrder == order) {
                            sortOrder = order
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

            List {
                // Driver card section
                if let driver {
                    Section {
                        DriverInfoCard(driver: driver)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                // Schedule
                let filtered = filteredSortedTrips
                if filtered.isEmpty {
                    Section {
                        emptyScheduleRow
                            .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(filtered) { trip in
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
                        Text("Upcoming Schedule")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .textCase(nil)
                    }
                }

                // Completed trips — last 2 weeks
                if !completedTrips.isEmpty {
                    Section {
                        ForEach(completedTrips) { trip in
                            NavigationLink(destination: TripDetailView(trip: trip)) {
                                TripRow(trip: trip, routeName: routeNames[trip.routeId])
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.secondary.opacity(0.08))
                                    .padding(.vertical, 3)
                            )
                        }
                    } header: {
                        Text("Completed — Last 2 Weeks")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await loadData() }
        }
    }

    private var emptyScheduleRow: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty && filterType == .all
                 ? "No upcoming trips"
                 : "No trips match your search")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Error View

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

    // MARK: - Filtered + Sorted Trips

    private var filteredSortedTrips: [Trip] {
        var result = upcomingTrips

        // Type filter
        switch filterType {
        case .all:     break
        case .pickup:  result = result.filter { $0.type == .pickup }
        case .dropoff: result = result.filter { $0.type == .dropoff }
        }

        // Search text
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                (routeNames[$0.routeId] ?? $0.routeId).lowercased().contains(q)
            }
        }

        // Sort
        switch sortOrder {
        case .dateAscending:
            result.sort { $0.date < $1.date }
        case .dateDescending:
            result.sort { $0.date > $1.date }
        case .typePickupFirst:
            result.sort {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.type == .pickup && $1.type != .pickup
            }
        case .typeDropoffFirst:
            result.sort {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.type == .dropoff && $1.type != .dropoff
            }
        }

        return result
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let driverId = authManager.currentUserId else { return }
        isLoading = true
        errorMessage = nil

        do {
            let driverDoc = try await service.fetchDriver(id: driverId)
            driver = driverDoc

            let trips = try await service.fetchAllTrips(for: driverId, schoolId: driverDoc.schoolId)
            upcomingTrips = trips
            completedTrips = (try? await service.fetchCompletedTrips(for: driverId, schoolId: driverDoc.schoolId)) ?? []

            let uniqueRouteIds = Set((trips + completedTrips).map(\.routeId))
            for id in uniqueRouteIds {
                routeNames[id] = await service.routeName(for: id)
            }
        } catch {
            errorMessage = "Failed to load schedule. Check your connection."
        }

        isLoading = false
    }

    // MARK: - Helpers

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: Date())
    }
}

// MARK: - DriverInfoCard

struct DriverInfoCard: View {
    let driver: Driver

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 60, height: 60)
                Text(String(driver.name.prefix(1)))
                    .font(.title2.bold())
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name)
                    .font(.headline)
                HStack(spacing: 12) {
                    Label(driver.phone, systemImage: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Label("Bus: \(driver.busRegistration)", systemImage: "bus.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - TripTypeFilter

enum TripTypeFilter: CaseIterable {
    case all, pickup, dropoff

    var label: String {
        switch self {
        case .all:     return "All"
        case .pickup:  return "Pick-up"
        case .dropoff: return "Drop-off"
        }
    }
}

// MARK: - TripSortOrder

enum TripSortOrder: CaseIterable {
    case dateAscending, dateDescending, typePickupFirst, typeDropoffFirst

    var label: String {
        switch self {
        case .dateAscending:    return "Date ↑"
        case .dateDescending:   return "Date ↓"
        case .typePickupFirst:  return "Pick-up First"
        case .typeDropoffFirst: return "Drop-off First"
        }
    }
}

// MARK: - DriverHistoryView

struct DriverHistoryView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var historyTrips: [Trip] = []
    @State private var routeNames: [String: String] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private let service = FirestoreService.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading history...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { Task { await loadHistory() } }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                } else if historyTrips.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("No trips in the last 3 days")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(groupedByDate, id: \.date) { group in
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
                                                  ? Color.green.opacity(0.12)
                                                  : Color.orange.opacity(0.12))
                                            .padding(.vertical, 3)
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Last 3 Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .task { await loadHistory() }
    }

    private var groupedByDate: [(date: String, trips: [Trip])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        var dict: [String: [Trip]] = [:]
        for trip in historyTrips {
            let key = formatter.string(from: trip.date)
            dict[key, default: []].append(trip)
        }
        return dict
            .map { (date: $0.key, trips: $0.value.sorted { $0.type == .pickup && $1.type != .pickup }) }
            .sorted {
                guard let d1 = formatter.date(from: $0.date), let d2 = formatter.date(from: $1.date) else { return false }
                return d1 > d2  // most recent first
            }
    }

    private func loadHistory() async {
        guard let driverId = authManager.currentUserId else { return }
        isLoading = true
        errorMessage = nil

        do {
            let driver = try await service.fetchDriver(id: driverId)
            let trips = try await service.fetchRecentCompletedTrips(for: driverId, schoolId: driver.schoolId)
            historyTrips = trips
            let uniqueRouteIds = Set(trips.map(\.routeId))
            for id in uniqueRouteIds {
                routeNames[id] = await service.routeName(for: id)
            }
        } catch {
            errorMessage = "Failed to load history."
        }

        isLoading = false
    }
}

// MARK: - Trip Row (shared with history)

struct TripRow: View {
    let trip: Trip
    var routeName: String?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f
    }()

    var body: some View {
        HStack(spacing: 14) {
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
                    Text(dateFormatter.string(from: trip.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label("\(trip.studentRecords.count)", systemImage: "person.2")
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

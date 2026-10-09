//
//  AdminDriversView.swift
//  Buzzer
//
//  Admin view — list of drivers with their assigned routes.
//  Tapping a driver shows all trips (past, today, future) for that driver.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Main list

enum AdminSortOption: String, CaseIterable {
    case recent  = "Recent"
    case nameAZ  = "Name (A–Z)"
    case nameZA  = "Name (Z–A)"
}

struct AdminDriversView: View {
    @State private var drivers: [Driver] = []
    @State private var routesByDriver: [String: [Route]] = [:]
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortOption: AdminSortOption = .nameAZ
    @State private var filterActiveOnly: Bool = false

    private let db = Firestore.db

    private var filtered: [Driver] {
        var base = searchText.isEmpty ? drivers : drivers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phone.localizedCaseInsensitiveContains(searchText) ||
            (routesByDriver[$0.id ?? ""] ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if filterActiveOnly {
            base = base.filter { !(routesByDriver[$0.id ?? ""] ?? []).isEmpty }
        }
        switch sortOption {
        case .recent: return base.sorted { $0.createdAt > $1.createdAt }
        case .nameAZ: return base.sorted { $0.name < $1.name }
        case .nameZA: return base.sorted { $0.name > $1.name }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter / sort bar
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        // Filter — left
                        Menu {
                            Button("All Drivers") { filterActiveOnly = false }
                            Button("With Routes") { filterActiveOnly = true }
                        } label: {
                            Label(filterActiveOnly ? "With Routes" : "All Drivers",
                                  systemImage: filterActiveOnly
                                    ? "line.3.horizontal.decrease.circle.fill"
                                    : "line.3.horizontal.decrease.circle")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        // Sort — right
                        Menu {
                            Picker("Sort by", selection: $sortOption) {
                                ForEach(AdminSortOption.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                        } label: {
                            Label(sortOption.rawValue, systemImage: "arrow.up.arrow.down.circle")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 12)
                .padding(.bottom, 8)

                Group {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if drivers.isEmpty {
                        ContentUnavailableView("No Drivers", systemImage: "person.2",
                                              description: Text("No active drivers found."))
                    } else if filtered.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        List(filtered) { driver in
                            NavigationLink(destination: AdminDriverDetailView(driver: driver)) {
                                AdminDriverRow(driver: driver, routes: routesByDriver[driver.id ?? ""] ?? [])
                            }
                        }
                        .listStyle(.insetGrouped)
                        .refreshable { await load() }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by name, phone or route")
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        do {
            let dSnap = try await db.collection("drivers")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            let loaded = try dSnap.documents.compactMap { try $0.data(as: Driver.self) }

            // Fetch routes for each driver
            var map: [String: [Route]] = [:]
            try await withThrowingTaskGroup(of: (String, [Route]).self) { group in
                for driver in loaded {
                    guard let did = driver.id else { continue }
                    group.addTask { [schoolId = driver.schoolId] in
                        let routes = try await FirestoreService.shared.fetchRoutes(for: did, schoolId: schoolId)
                        return (did, routes)
                    }
                }
                for try await (did, routes) in group {
                    map[did] = routes.sorted { $0.name < $1.name }
                }
            }

            await MainActor.run {
                drivers = loaded.sorted { $0.name < $1.name }
                routesByDriver = map
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Driver Row

private struct AdminDriverRow: View {
    let driver: Driver
    let routes: [Route]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(driver.name)
                .font(.headline)

            if routes.isEmpty {
                Text("No active routes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(routes) { route in
                    HStack(spacing: 6) {
                        Image(systemName: "bus")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("\(route.name) · Term \(route.term) \(route.year)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Driver Detail

struct AdminDriverDetailView: View {
    let driver: Driver

    @State private var trips: [Trip] = []
    @State private var routeNames: [String: String] = [:]
    @State private var isLoading = true

    private let db = Firestore.db

    private var pastTrips: [Trip]   { trips.filter { $0.status == .completed } }
    private var todayTrips: [Trip]  { trips.filter { Calendar.current.isDateInToday($0.date) && $0.status != .completed } }
    private var futureTrips: [Trip] { trips.filter { $0.date > Date() && !Calendar.current.isDateInToday($0.date) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Driver info card
                VStack(alignment: .leading, spacing: 8) {
                    Label(driver.phone, systemImage: "phone")
                    Label(driver.busRegistration, systemImage: "bus")
                    Label(driver.driversLicense, systemImage: "creditcard")
                    Label("Licence expires \(driver.licenseExpiry.formatted(date: .abbreviated, time: .omitted))",
                          systemImage: "calendar.badge.clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 24)
                } else {
                    if !todayTrips.isEmpty {
                        TripSection(title: "Today", trips: todayTrips, routeNames: routeNames)
                    }
                    if !futureTrips.isEmpty {
                        TripSection(title: "Upcoming", trips: futureTrips, routeNames: routeNames)
                    }
                    if !pastTrips.isEmpty {
                        TripSection(title: "Completed", trips: pastTrips, routeNames: routeNames)
                    }
                    if trips.isEmpty {
                        ContentUnavailableView("No Trips", systemImage: "calendar",
                                              description: Text("No trips found for this driver."))
                    }
                }
            }
            .padding()
        }
        .navigationTitle(driver.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            let all = try await FirestoreService.shared.fetchAllTrips(for: driver.id ?? "", schoolId: driver.schoolId)
            var names: [String: String] = [:]
            for id in Set(all.map(\.routeId)) {
                names[id] = await FirestoreService.shared.routeName(for: id)
            }
            await MainActor.run {
                trips = all.sorted { $0.date > $1.date }
                routeNames = names
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Shared Trip Section

struct TripSection: View {
    let title: String
    let trips: [Trip]
    let routeNames: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(trips) { trip in
                TripSummaryCard(trip: trip, routeName: routeNames[trip.routeId] ?? trip.routeId)
            }
        }
    }
}

// MARK: - Trip Summary Card (read-only, admin view)

struct TripSummaryCard: View {
    let trip: Trip
    let routeName: String

    private var accentColor: Color { trip.type == .pickup ? .green : .orange }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: trip.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trip.type == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(routeName)
                    .font(.subheadline).fontWeight(.semibold)
                HStack(spacing: 8) {
                    Text(dateString)
                        .font(.caption).foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(trip.studentRecords.count) students")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()
            TripStatusBadge(status: trip.status)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Add Driver Sheet (unchanged)

struct AddDriverSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var age = ""
    @State private var gender = "Male"
    @State private var address = ""
    @State private var childrenCheck = ""
    @State private var driversLicense = ""
    @State private var licenseExpiry = Date()
    @State private var busRegistration = ""

    @State private var isSaving = false
    @State private var errorMessage = ""

    private let db = Firestore.db
    private let genders = ["Male", "Female", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal") {
                    TextField("Full Name", text: $name)
                    TextField("Phone (e.g. 0412 345 678)", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                    Picker("Gender", selection: $gender) {
                        ForEach(genders, id: \.self) { Text($0) }
                    }
                    TextField("Address", text: $address)
                }

                Section("Licence & Compliance") {
                    TextField("Drivers Licence Number", text: $driversLicense)
                    DatePicker("Licence Expiry", selection: $licenseExpiry, displayedComponents: .date)
                    TextField("Working with Children Check", text: $childrenCheck)
                }

                Section("Vehicle") {
                    TextField("Bus Registration", text: $busRegistration)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Add Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(isSaving || name.isEmpty || phone.isEmpty)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = ""
        Task {
            do {
                let ref = db.collection("drivers").document()
                try await ref.setData([
                    "name": name.trimmingCharacters(in: .whitespaces),
                    "phone": phone.trimmingCharacters(in: .whitespaces),
                    "age": Int(age) ?? 0,
                    "gender": gender,
                    "address": address.trimmingCharacters(in: .whitespaces),
                    "childrenCheck": childrenCheck.trimmingCharacters(in: .whitespaces),
                    "driversLicense": driversLicense.trimmingCharacters(in: .whitespaces),
                    "licenseExpiry": Timestamp(date: licenseExpiry),
                    "busRegistration": busRegistration.trimmingCharacters(in: .whitespaces).uppercased(),
                    "isActive": true,
                    "createdAt": Timestamp(date: Date()),
                ])
                await MainActor.run { isSaving = false; dismiss() }
            } catch {
                await MainActor.run { isSaving = false; errorMessage = error.localizedDescription }
            }
        }
    }
}

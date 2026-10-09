//
//  AdminScheduleView.swift
//  Buzzer
//
//  Admin view — list of routes (name · term number).
//  Tapping a route shows all trips, the assigned driver, student list,
//  and a button to generate a report for a selected week.
//

import SwiftUI
import FirebaseFirestore

private let DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

// MARK: - Supporting type

struct RouteListItem: Identifiable {
    let id: String
    let name: String
    let term: Int
    let year: Int
    let studentCount: Int
    let startDate: Date?
    let endDate: Date?
    let driverId: String
    let busRegistration: String?
}

// MARK: - Main list

struct AdminScheduleView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var routes: [RouteListItem] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortOption: AdminSortOption = .recent
    @State private var filterTerm: Int = 0    // 0 = all terms

    private let db = Firestore.db

    private var filtered: [RouteListItem] {
        var base = routes
        if !searchText.isEmpty {
            base = base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if filterTerm != 0 {
            base = base.filter { $0.term == filterTerm }
        }
        switch sortOption {
        case .recent:  return base.sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
        case .nameAZ:  return base.sorted { $0.name < $1.name }
        case .nameZA:  return base.sorted { $0.name > $1.name }
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
                            Button("All Terms") { filterTerm = 0 }
                            ForEach(1...4, id: \.self) { t in
                                Button("Term \(t)") { filterTerm = t }
                            }
                        } label: {
                            Label(filterTerm == 0 ? "All Terms" : "Term \(filterTerm)",
                                  systemImage: filterTerm == 0
                                    ? "line.3.horizontal.decrease.circle"
                                    : "line.3.horizontal.decrease.circle.fill")
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
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if routes.isEmpty {
                        ContentUnavailableView("No Routes", systemImage: "calendar",
                                              description: Text("No active routes found."))
                    } else if filtered.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        List(filtered) { route in
                            NavigationLink(destination: AdminRouteDetailView(route: route)) {
                                RouteListRow(route: route)
                            }
                        }
                        .listStyle(.insetGrouped)
                        .refreshable { loadRoutes() }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search routes")
            .task { loadRoutes() }
        }
    }

    private func loadRoutes() {
        isLoading = true
        Task {
            do {
                let snap = try await db.collection("routes")
                    .whereField("isActive", isEqualTo: true)
                    .getDocuments()
                let loaded: [RouteListItem] = snap.documents.compactMap { doc in
                    let d = doc.data()
                    guard let name = d["name"] as? String else { return nil }
                    let term       = d["term"] as? Int ?? 0
                    let year       = d["year"] as? Int ?? 0
                    let studentIds = d["studentIds"] as? [String] ?? []
                    let startDate  = (d["startDate"] as? Timestamp)?.dateValue()
                    let endDate    = (d["endDate"] as? Timestamp)?.dateValue()
                    let driverId        = d["driverId"] as? String ?? ""
                    let busRegistration = d["busRegistration"] as? String
                    return RouteListItem(id: doc.documentID, name: name, term: term, year: year,
                                        studentCount: studentIds.count, startDate: startDate,
                                        endDate: endDate, driverId: driverId,
                                        busRegistration: busRegistration)
                }
                await MainActor.run {
                    routes = loaded.sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Route list row

private struct RouteListRow: View {
    let route: RouteListItem
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(route.name).font(.headline)
            HStack(spacing: 16) {
                Label("Term \(route.term) · \(route.year)", systemImage: "calendar")
                Label("\(route.studentCount) students", systemImage: "person.2")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Route Detail

struct AdminRouteDetailView: View {
    let route: RouteListItem

    @State private var driver: Driver? = nil
    @State private var students: [Student] = []
    @State private var trips: [Trip] = []
    @State private var isLoading = true

    // Substitute driver
    @State private var showSubstituteSheet = false

    // Report generation
    @State private var reportWeekStart: Date = Calendar.current.startOfWeek(for: Date())

    private let db = Firestore.db

    private var pastTrips: [Trip]   { trips.filter { $0.status == .completed } }
    private var todayTrips: [Trip]  { trips.filter { Calendar.current.isDateInToday($0.date) && $0.status != .completed } }
    private var futureTrips: [Trip] { trips.filter { $0.date > Date() && !Calendar.current.isDateInToday($0.date) } }

    /// IDs of upcoming trips that currently have a substitute assigned.
    private var substitutedTripIds: Set<String> {
        Set(futureTrips.compactMap { $0.substituteDriverId != nil ? $0.id : nil })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: Route meta card
                routeMetaCard

                // MARK: Driver card
                driverCard

                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
                } else {
                    // MARK: Substitute driver banner (if any upcoming trips have a sub)
                    if !substitutedTripIds.isEmpty {
                        substituteActiveBanner
                    }

                    // MARK: Assign substitute button
                    Button {
                        showSubstituteSheet = true
                    } label: {
                        Label("Assign Substitute Driver", systemImage: "arrow.left.arrow.right.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple.opacity(0.12))
                            .foregroundStyle(.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // MARK: Students
                    if !students.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Students (\(students.count))")
                                .font(.headline).foregroundStyle(.secondary)
                            ForEach(students) { student in
                                StudentSummaryCard(student: student)
                            }
                        }
                    }

                    // MARK: Trips
                    if !todayTrips.isEmpty  { TripSection(title: "Today",     trips: todayTrips,  routeNames: [route.id: route.name]) }
                    if !futureTrips.isEmpty { TripSection(title: "Upcoming",  trips: futureTrips, routeNames: [route.id: route.name]) }
                    if !pastTrips.isEmpty   { TripSection(title: "Completed", trips: pastTrips,   routeNames: [route.id: route.name]) }
                    if trips.isEmpty {
                        ContentUnavailableView("No Trips", systemImage: "calendar",
                                              description: Text("No trips found for this route."))
                    }

                    // MARK: Generate Report
                    Divider()
                    generateReportSection
                }
            }
            .padding()
        }
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showSubstituteSheet) {
            AssignSubstituteSheet(route: route, originalDriver: driver) {
                Task { await load() }
            }
        }
    }

    // MARK: - Substitute active banner

    private var substituteActiveBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("\(substitutedTripIds.count) upcoming trip(s) have a substitute driver assigned.")
                .font(.caption.bold())
                .foregroundStyle(.orange)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Route meta

    private var routeMetaCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Term \(route.term) · \(route.year)")
                    .font(.headline)
                if let start = route.startDate, let end = route.endDate {
                    Text(routeDateRange(start: start, end: end))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let rego = route.busRegistration, !rego.isEmpty {
                    Label(rego, systemImage: "bus")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(route.studentCount)")
                    .font(.title2.bold())
                Text("students")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Driver card

    private var driverCard: some View {
        Group {
            if let driver {
                HStack(spacing: 14) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.purple)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(driver.name).font(.headline)
                        Text(driver.phone).font(.caption).foregroundStyle(.secondary)
                        Text(driver.busRegistration).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Helpers

    private func routeDateRange(start: Date, end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    // MARK: - Generate Report

    private var generateReportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generate Report")
                .font(.headline).foregroundStyle(.secondary)

            DatePicker("Select week starting",
                       selection: $reportWeekStart,
                       displayedComponents: .date)
                .datePickerStyle(.compact)

            Button {
                generateReport()
            } label: {
                Label("Generate Weekly Report", systemImage: "doc.text.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Load

    private func load() async {
        isLoading = true

        async let driverTask: Driver? = route.driverId.isEmpty ? nil :
            (try? await FirestoreService.shared.fetchDriver(id: route.driverId))

        async let tripsTask: [Trip] = {
            let snap = try? await Firestore.db.collection("trips")
                .whereField("routeId", isEqualTo: route.id)
                .order(by: "date", descending: false)
                .getDocuments()
            return (snap?.documents ?? []).compactMap { try? $0.data(as: Trip.self) }
        }()

        async let studentsTask: [Student] = {
            let snap = try? await Firestore.db.collection("students")
                .whereField("routeId", isEqualTo: route.id)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            return (snap?.documents ?? []).compactMap { try? $0.data(as: Student.self) }
        }()

        let (d, t, s) = await (driverTask, tripsTask, studentsTask)
        await MainActor.run {
            driver   = d
            trips    = t.sorted { $0.date > $1.date }
            students = s.sorted { $0.name < $1.name }
            isLoading = false
        }
    }

    // MARK: - Report generation

    private func generateReport() {
        let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: reportWeekStart)!
        let f = DateFormatter(); f.dateFormat = "d MMM"
        let range = "\(f.string(from: reportWeekStart)) – \(f.string(from: weekEnd))"

        // Filter completed trips in the selected week
        let weekTrips = trips.filter { trip in
            trip.status == .completed &&
            trip.date >= reportWeekStart &&
            trip.date <= weekEnd
        }

        var lines: [String] = []
        lines.append("BUSMATE ROUTE REPORT")
        lines.append("Route: \(route.name)")
        lines.append("Term \(route.term) \(route.year)  |  Week: \(range)")
        if let d = driver { lines.append("Driver: \(d.name)") }
        lines.append("Students: \(students.count)")
        lines.append(String(repeating: "-", count: 40))
        lines.append("Completed trips this week: \(weekTrips.count)")
        lines.append("")

        for trip in weekTrips.sorted(by: { $0.date < $1.date }) {
            let dayStr = DateFormatter()
            dayStr.dateFormat = "EEEE d MMM"
            lines.append("\(dayStr.string(from: trip.date)) – \(trip.type.rawValue.capitalized)")
            let onBus = trip.studentRecords.filter { $0.status == .onBus || $0.status == .offBus }.count
            let absent = trip.studentRecords.filter { $0.status == .absent }.count
            lines.append("  Boarded: \(onBus)  Absent: \(absent)")
        }

        let report = lines.joined(separator: "\n")
        // Share via share sheet
        let av = UIActivityViewController(activityItems: [report], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - Student summary card

private struct StudentSummaryCard: View {
    let student: Student

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .font(.system(size: 20))
                .foregroundStyle(.purple.opacity(0.7))
                .frame(width: 36, height: 36)
                .background(Color.purple.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(student.name).font(.subheadline).fontWeight(.semibold)
                HStack(spacing: 8) {
                    Text("Grade \(student.grade)")
                    Text("·")
                    Text("AM: \(student.scheduledPickupTime)")
                    Text("·")
                    Text("PM: \(student.scheduledDropoffTime)")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Assign Substitute Sheet

struct AssignSubstituteSheet: View {
    let route: RouteListItem
    let originalDriver: Driver?
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var availableDrivers: [Driver] = []
    @State private var selectedDriverId: String = ""
    @State private var fromDate: Date = Date()
    @State private var toDate: Date = Date()
    @State private var isSaving = false
    @State private var isClearing = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    private let db = Firestore.db

    var body: some View {
        NavigationStack {
            Form {
                // Context
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(route.name)
                                .font(.headline)
                            if let orig = originalDriver {
                                Text("Currently: \(orig.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Date range
                Section {
                    DatePicker("From", selection: $fromDate, in: Date()..., displayedComponents: .date)
                    DatePicker("To",   selection: $toDate,   in: fromDate..., displayedComponents: .date)
                } header: {
                    Text("Substitution Period")
                } footer: {
                    Text("Only scheduled (not yet started) trips in this range will be updated.")
                }

                // Driver selection
                Section("Substitute Driver") {
                    if availableDrivers.isEmpty {
                        Text("No other active drivers available.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        Picker("Select Driver", selection: $selectedDriverId) {
                            Text("— select —").tag("")
                            ForEach(availableDrivers) { d in
                                HStack {
                                    Text(d.name)
                                    Spacer()
                                    Text(d.phone)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(d.id ?? "")
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }

                // Assign button
                Section {
                    Button {
                        Task { await assign() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Assign Substitute")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(selectedDriverId.isEmpty || isSaving || isClearing)
                }

                // Clear button
                Section {
                    Button(role: .destructive) {
                        Task { await clearSubstitute() }
                    } label: {
                        HStack {
                            Spacer()
                            if isClearing {
                                ProgressView()
                            } else {
                                Text("Clear Substitute for This Period")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving || isClearing)
                } footer: {
                    Text("Removes any substitute assignment from trips in the selected date range, restoring the original driver.")
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Substitute Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss(); onDone() }
                }
            }
            .task { await loadDrivers() }
        }
    }

    private func loadDrivers() async {
        let snap = try? await db.collection("drivers")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        let all = (snap?.documents ?? []).compactMap { try? $0.data(as: Driver.self) }
        // Exclude the original driver from the substitute list
        let origId = originalDriver?.id ?? route.driverId
        await MainActor.run {
            availableDrivers = all.filter { $0.id != origId }.sorted { $0.name < $1.name }
        }
    }

    private func assign() async {
        guard !selectedDriverId.isEmpty else { return }
        isSaving = true
        errorMessage = ""
        successMessage = ""
        do {
            try await FirestoreService.shared.assignSubstituteDriver(
                routeId: route.id,
                substituteDriverId: selectedDriverId,
                from: fromDate,
                to: toDate
            )
            let subName = availableDrivers.first { $0.id == selectedDriverId }?.name ?? "Selected driver"
            await MainActor.run {
                successMessage = "\(subName) assigned as substitute for the selected period."
                isSaving = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to assign substitute: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }

    private func clearSubstitute() async {
        isClearing = true
        errorMessage = ""
        successMessage = ""
        do {
            try await FirestoreService.shared.assignSubstituteDriver(
                routeId: route.id,
                substituteDriverId: nil,
                from: fromDate,
                to: toDate
            )
            await MainActor.run {
                successMessage = "Substitute cleared. Original driver restored."
                isClearing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to clear substitute: \(error.localizedDescription)"
                isClearing = false
            }
        }
    }
}

// MARK: - Calendar extension

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps) ?? date
    }
}

// MARK: - Create Route Sheet (unchanged from before)

struct CreateRouteSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var routeName = ""
    @State private var busRegistration = ""
    @State private var selectedDriverId = ""
    @State private var term = 1
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedDays: Set<String> = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    @State private var students: [StudentEntry] = []
    @State private var drivers: [Driver] = []

    @State private var showAddStudent = false
    @State private var isSaving = false
    @State private var errorMessage = ""

    private let db = Firestore.db

    var body: some View {
        NavigationStack {
            Form {
                Section("Route Details") {
                    TextField("Route Name", text: $routeName)
                    TextField("Bus Registration", text: $busRegistration)
                    Picker("Driver", selection: $selectedDriverId) {
                        Text("— select —").tag("")
                        ForEach(drivers) { d in
                            Text(d.name).tag(d.id ?? "")
                        }
                    }
                    Picker("Term", selection: $term) {
                        ForEach(1...4, id: \.self) { Text("Term \($0)").tag($0) }
                    }
                    Stepper("Year: \(year)", value: $year, in: 2020...2040)
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section("Scheduled Days") {
                    ForEach(DAYS, id: \.self) { day in
                        Toggle(day, isOn: Binding(
                            get: { selectedDays.contains(day) },
                            set: { on in
                                if on { selectedDays.insert(day) } else { selectedDays.remove(day) }
                            }
                        ))
                    }
                }

                Section {
                    ForEach(students) { s in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.subheadline).fontWeight(.semibold)
                            Text("Grade \(s.grade) · Stop Location AM: \(s.stopLocationAM)").font(.caption).foregroundStyle(.secondary)
                            Text("AM \(s.pickupTime) · PM \(s.dropoffTime)").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { students.remove(atOffsets: $0) }

                    Button { showAddStudent = true } label: {
                        Label("Add Student", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Students (\(students.count))")
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Create Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { save() }
                        .fontWeight(.bold)
                        .disabled(isSaving || routeName.isEmpty || selectedDriverId.isEmpty || students.isEmpty)
                }
            }
            .sheet(isPresented: $showAddStudent) {
                AddStudentEntrySheet { entry in students.append(entry) }
            }
            .task { await loadDrivers() }
        }
    }

    private func loadDrivers() async {
        let snap = try? await db.collection("drivers").whereField("isActive", isEqualTo: true).getDocuments()
        let loaded = (snap?.documents ?? []).compactMap { try? $0.data(as: Driver.self) }
        await MainActor.run { drivers = loaded.sorted { $0.name < $1.name } }
    }

    private func scheduledDates() -> [Date] {
        let dayIndexMap: [String: Int] = ["Sunday":0,"Monday":1,"Tuesday":2,"Wednesday":3,"Thursday":4,"Friday":5,"Saturday":6]
        let allowed = Set(selectedDays.compactMap { dayIndexMap[$0] })
        var dates: [Date] = []
        var cur = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        while cur <= end {
            if allowed.contains(Calendar.current.component(.weekday, from: cur) - 1) {
                dates.append(cur)
            }
            cur = Calendar.current.date(byAdding: .day, value: 1, to: cur)!
        }
        return dates
    }

    private func save() {
        guard !selectedDriverId.isEmpty else { errorMessage = "Please select a driver."; return }
        isSaving = true
        errorMessage = ""
        Task {
            do {
                // Check for a duplicate route with the same name and term
                let trimmedName = routeName.trimmingCharacters(in: .whitespaces)
                let dupSnap = try await db.collection("routes")
                    .whereField("name", isEqualTo: trimmedName)
                    .whereField("term", isEqualTo: term)
                    .whereField("year", isEqualTo: year)
                    .whereField("isActive", isEqualTo: true)
                    .getDocuments()
                if !dupSnap.documents.isEmpty {
                    await MainActor.run {
                        isSaving = false
                        errorMessage = "A route named \"\(trimmedName)\" already exists for Term \(term) \(year)."
                    }
                    return
                }

                let batch = db.batch()
                let routeRef = db.collection("routes").document()
                var studentIds: [String] = []
                var studentRecords: [[String: Any]] = []

                for s in students {
                    let ref = db.collection("students").document()
                    let orderAM = Int(s.orderAM) as Any
                    let orderPM = Int(s.orderPM) as Any

                    // Create parent doc if parent info provided
                    var authorisedParentIds: [String] = []
                    if !s.parentName.trimmingCharacters(in: .whitespaces).isEmpty {
                        let parentRef = db.collection("parents").document()
                        batch.setData([
                            "name": s.parentName.trimmingCharacters(in: .whitespaces),
                            "relationship": s.relationship.trimmingCharacters(in: .whitespaces),
                            "phone": s.parentPhone.trimmingCharacters(in: .whitespaces),
                            "email": s.parentEmail.trimmingCharacters(in: .whitespaces),
                            "fcmToken": NSNull(),
                            "childIds": [ref.documentID],
                            "isActive": true,
                            "profileCompleted": false,
                            "createdAt": Timestamp(date: Date()),
                        ], forDocument: parentRef)
                        authorisedParentIds.append(parentRef.documentID)
                    }

                    batch.setData([
                        "name": s.name,
                        "grade": s.grade,
                        "phone": s.studentPhone.trimmingCharacters(in: .whitespaces),
                        "email": s.studentEmail.trimmingCharacters(in: .whitespaces),
                        "stopAddressAM": s.stopLocationAM,
                        "stopAddressPM": s.stopLocationPM,
                        "orderAM": orderAM,
                        "orderPM": orderPM,
                        "routeId": routeRef.documentID,
                        "scheduledPickupTime": s.pickupTime,
                        "scheduledDropoffTime": s.dropoffTime,
                        "authorisedParentIds": authorisedParentIds,
                        "isActive": true,
                        "createdAt": Timestamp(date: Date()),
                    ], forDocument: ref)
                    studentIds.append(ref.documentID)
                    studentRecords.append([
                        "id": ref.documentID, "studentName": s.name,
                        "stopAddressAM": s.stopLocationAM, "stopAddressPM": s.stopLocationPM,
                        "orderAM": orderAM, "orderPM": orderPM,
                        "status": "pending", "timestamp": NSNull()
                    ])
                }

                batch.setData([
                    "name": routeName.trimmingCharacters(in: .whitespaces).uppercased(),
                    "driverId": selectedDriverId,
                    "busRegistration": busRegistration.trimmingCharacters(in: .whitespaces).uppercased(),
                    "term": term,
                    "year": year,
                    "scheduledDays": Array(selectedDays),
                    "startDate": Timestamp(date: startDate),
                    "endDate": Timestamp(date: endDate),
                    "studentIds": studentIds,
                    "isActive": true,
                    "createdAt": Timestamp(date: Date()),
                ], forDocument: routeRef)

                for date in scheduledDates() {
                    for type in ["pickup", "dropoff"] {
                        let tripRef = db.collection("trips").document()
                        batch.setData([
                            "routeId": routeRef.documentID,
                            "driverId": selectedDriverId,
                            "date": Timestamp(date: date),
                            "type": type,
                            "status": "scheduled",
                            "studentRecords": studentRecords,
                            "startedAt": NSNull(),
                            "completedAt": NSNull(),
                        ], forDocument: tripRef)
                    }
                }

                try await batch.commit()
                await MainActor.run { isSaving = false; dismiss() }
            } catch {
                await MainActor.run { isSaving = false; errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - Student Entry Model

struct StudentEntry: Identifiable {
    let id = UUID()
    var name: String
    var grade: String
    var studentPhone: String
    var studentEmail: String
    var orderAM: String
    var pickupTime: String
    var stopLocationAM: String
    var orderPM: String
    var dropoffTime: String
    var stopLocationPM: String
    var parentName: String
    var parentPhone: String
    var parentEmail: String
    var relationship: String
}

// MARK: - Add Student Entry Sheet

struct AddStudentEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (StudentEntry) -> Void

    @State private var name = ""
    @State private var grade = ""
    @State private var studentPhone = ""
    @State private var studentEmail = ""
    @State private var orderAM = ""
    @State private var pickupTime = ""
    @State private var stopLocationAM = ""
    @State private var orderPM = ""
    @State private var dropoffTime = ""
    @State private var stopLocationPM = ""
    @State private var parentName = ""
    @State private var parentPhone = ""
    @State private var parentEmail = ""
    @State private var relationship = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Student") {
                    TextField("Full Name", text: $name)
                    TextField("Grade", text: $grade)
                    TextField("Phone (e.g. 0412 345 678)", text: $studentPhone)
                        .keyboardType(.phonePad)
                    TextField("Email (optional)", text: $studentEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("Morning Pick-up") {
                    TextField("Order AM (stop sequence)", text: $orderAM)
                        .keyboardType(.numberPad)
                    TextField("Scheduled AM (e.g. 08:00 AM)", text: $pickupTime)
                    TextField("Stop Location AM", text: $stopLocationAM)
                }
                Section("Afternoon Drop-off") {
                    TextField("Order PM (stop sequence)", text: $orderPM)
                        .keyboardType(.numberPad)
                    TextField("Scheduled PM (e.g. 03:30 PM)", text: $dropoffTime)
                    TextField("Stop Location PM", text: $stopLocationPM)
                }
                Section("Parent / Guardian") {
                    TextField("Parent Name", text: $parentName)
                    TextField("Parent Phone (e.g. 0412 345 678)", text: $parentPhone)
                        .keyboardType(.phonePad)
                    TextField("Parent Email (optional)", text: $parentEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Relationship (e.g. Mother, Father, Guardian)", text: $relationship)
                }
            }
            .navigationTitle("Add Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(StudentEntry(
                            name: name, grade: grade,
                            studentPhone: studentPhone, studentEmail: studentEmail,
                            orderAM: orderAM, pickupTime: pickupTime, stopLocationAM: stopLocationAM,
                            orderPM: orderPM, dropoffTime: dropoffTime, stopLocationPM: stopLocationPM,
                            parentName: parentName, parentPhone: parentPhone,
                            parentEmail: parentEmail, relationship: relationship
                        ))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.isEmpty || stopLocationAM.isEmpty)
                }
            }
        }
    }
}

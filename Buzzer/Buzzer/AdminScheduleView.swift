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
}

// MARK: - Main list

struct AdminScheduleView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var routes: [RouteListItem] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false

    private let db = Firestore.db

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if routes.isEmpty {
                    ContentUnavailableView("No Routes", systemImage: "calendar",
                                          description: Text("Create a route to get started."))
                } else {
                    List(routes) { route in
                        NavigationLink(destination: AdminRouteDetailView(route: route)) {
                            RouteListRow(route: route)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { loadRoutes() }
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreateSheet = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showCreateSheet, onDismiss: loadRoutes) {
                CreateRouteSheet()
            }
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
                    let driverId   = d["driverId"] as? String ?? ""
                    return RouteListItem(id: doc.documentID, name: name, term: term, year: year,
                                        studentCount: studentIds.count, startDate: startDate,
                                        endDate: endDate, driverId: driverId)
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

    // Report generation
    @State private var showReportPicker = false
    @State private var reportWeekStart: Date = Calendar.current.startOfWeek(for: Date())

    private let db = Firestore.db

    private var pastTrips: [Trip]   { trips.filter { $0.status == .completed } }
    private var todayTrips: [Trip]  { trips.filter { Calendar.current.isDateInToday($0.date) && $0.status != .completed } }
    private var futureTrips: [Trip] { trips.filter { $0.date > Date() && !Calendar.current.isDateInToday($0.date) } }

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
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
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
                            Text("Grade \(s.grade) · AM: \(s.stopAddressAM)").font(.caption).foregroundStyle(.secondary)
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
                let batch = db.batch()
                var studentIds: [String] = []
                var studentRecords: [[String: Any]] = []

                for s in students {
                    let ref = db.collection("students").document()
                    batch.setData([
                        "name": s.name,
                        "grade": s.grade,
                        "stopAddressAM": s.stopAddressAM,
                        "stopAddressPM": s.stopAddressPM,
                        "routeId": "",
                        "scheduledPickupTime": s.pickupTime,
                        "scheduledDropoffTime": s.dropoffTime,
                        "authorisedParentIds": [String](),
                        "isActive": true,
                        "createdAt": Timestamp(date: Date()),
                    ], forDocument: ref)
                    studentIds.append(ref.documentID)
                    studentRecords.append(["id": ref.documentID, "studentName": s.name,
                                           "stopAddressAM": s.stopAddressAM, "stopAddressPM": s.stopAddressPM,
                                           "status": "pending", "timestamp": NSNull()])
                }

                let routeRef = db.collection("routes").document()
                batch.setData([
                    "name": routeName.trimmingCharacters(in: .whitespaces),
                    "driverId": selectedDriverId,
                    "busRegistration": busRegistration.trimmingCharacters(in: .whitespaces),
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
    var pickupTime: String
    var dropoffTime: String
    var stopAddressAM: String
    var stopAddressPM: String
    var parentPhone: String
    var parentName: String
}

// MARK: - Add Student Entry Sheet

struct AddStudentEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (StudentEntry) -> Void

    @State private var name = ""
    @State private var grade = ""
    @State private var pickupTime = ""
    @State private var dropoffTime = ""
    @State private var stopAddressAM = ""
    @State private var stopAddressPM = ""
    @State private var parentPhone = ""
    @State private var parentName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Student") {
                    TextField("Full Name", text: $name)
                    TextField("Grade", text: $grade)
                }
                Section("Schedule") {
                    TextField("Scheduled AM (e.g. 08:00 AM)", text: $pickupTime)
                    TextField("Scheduled PM (e.g. 03:30 PM)", text: $dropoffTime)
                    TextField("Stop Location AM (Morning Pick-up)", text: $stopAddressAM)
                    TextField("Stop Location PM (Afternoon Drop-off)", text: $stopAddressPM)
                }
                Section("Parent") {
                    TextField("Parent Name", text: $parentName)
                    TextField("Parent Contact", text: $parentPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Add Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(StudentEntry(name: name, grade: grade, pickupTime: pickupTime,
                                          dropoffTime: dropoffTime, stopAddressAM: stopAddressAM,
                                          stopAddressPM: stopAddressPM, parentPhone: parentPhone,
                                          parentName: parentName))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.isEmpty || stopAddressAM.isEmpty)
                }
            }
        }
    }
}

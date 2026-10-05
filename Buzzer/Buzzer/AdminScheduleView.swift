//
//  AdminScheduleView.swift
//  Buzzer
//
//  Admin view to create routes. Mirrors the web admin schedule creation flow:
//  fill in route details + paste student data manually (no .xlsx on iOS).
//  Students are entered one-by-one via a sub-form.
//

import SwiftUI
import FirebaseFirestore

private let DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

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
                    ContentUnavailableView("No Routes", systemImage: "calendar", description: Text("Create a route to get started."))
                } else {
                    List(routes) { route in
                        RouteListRow(route: route)
                    }
                    .listStyle(.insetGrouped)
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
                    let term = d["term"] as? Int ?? 0
                    let year = d["year"] as? Int ?? 0
                    let studentIds = d["studentIds"] as? [String] ?? []
                    let startDate = (d["startDate"] as? Timestamp)?.dateValue()
                    return RouteListItem(id: doc.documentID, name: name, term: term, year: year, studentCount: studentIds.count, startDate: startDate)
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

// MARK: - Supporting Types

private struct RouteListItem: Identifiable {
    let id: String
    let name: String
    let term: Int
    let year: Int
    let studentCount: Int
    let startDate: Date?
}

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

// MARK: - Create Route Sheet

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
                            Text("Grade \(s.grade) · \(s.stopAddress)").font(.caption).foregroundStyle(.secondary)
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
                        "stopAddress": s.stopAddress,
                        "routeId": "",
                        "scheduledPickupTime": s.pickupTime,
                        "scheduledDropoffTime": s.dropoffTime,
                        "authorisedParentIds": [String](),
                        "isActive": true,
                        "createdAt": Timestamp(date: Date()),
                    ], forDocument: ref)
                    studentIds.append(ref.documentID)
                    studentRecords.append(["id": ref.documentID, "studentName": s.name, "stopAddress": s.stopAddress, "status": "pending", "timestamp": NSNull()])
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
    var stopAddress: String
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
    @State private var stopAddress = ""
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
                    TextField("Scheduled AM (e.g. 08:00)", text: $pickupTime)
                    TextField("Scheduled PM (e.g. 15:30)", text: $dropoffTime)
                    TextField("STOP Location", text: $stopAddress)
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
                        onAdd(StudentEntry(name: name, grade: grade, pickupTime: pickupTime, dropoffTime: dropoffTime, stopAddress: stopAddress, parentPhone: parentPhone, parentName: parentName))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.isEmpty || stopAddress.isEmpty)
                }
            }
        }
    }
}

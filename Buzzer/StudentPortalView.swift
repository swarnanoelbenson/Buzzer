//
//  StudentPortalView.swift
//  Buzzer
//
//  Read-only portal for students.
//  Shows: assigned driver info, bus registration, route, pickup/dropoff times,
//  schedule as a calendar, and parent notes for this student.
//

import SwiftUI
import FirebaseFirestore

struct StudentPortalView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var student: Student? = nil
    @State private var route: Route? = nil
    @State private var driver: Driver? = nil
    @State private var notes: [FirestorePassengerNote] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

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
            .navigationTitle("Buzzer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let student {
                    // Greeting
                    greetingHeader(student: student)

                    // Driver & Bus card
                    driverCard

                    // Route & times card
                    if let route {
                        routeCard(route: route, student: student)
                    }

                    // Schedule calendar card
                    if let route {
                        scheduleCard(route: route)
                    }

                    // Parent notes card
                    notesCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable {
            await loadData()
        }
    }

    private func greetingHeader(student: Student) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hello, \(student.name.components(separatedBy: " ").first ?? student.name)")
                .font(.title2)
                .fontWeight(.semibold)
            Text(todayDateString)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Driver Card

    private var driverCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Bus Driver")

            if let driver {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(driver.name.prefix(1)))
                                .font(.title3.bold())
                                .foregroundColor(.blue)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(driver.name)
                            .font(.headline)
                        Text("Bus: \(driver.busRegistration)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } else {
                Text("No driver assigned")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Route Card

    private func routeCard(route: Route, student: Student) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Route & Times")

            VStack(spacing: 0) {
                infoRow(
                    icon: "map.fill",
                    iconColor: .blue,
                    label: "Route",
                    value: route.name
                )
                Divider().padding(.leading, 36)
                infoRow(
                    icon: "mappin.circle.fill",
                    iconColor: .red,
                    label: "Stop",
                    value: student.stopAddress
                )
                Divider().padding(.leading, 36)
                infoRow(
                    icon: "arrow.up.circle.fill",
                    iconColor: .green,
                    label: "Pick-up",
                    value: student.scheduledPickupTime
                )
                Divider().padding(.leading, 36)
                infoRow(
                    icon: "arrow.down.circle.fill",
                    iconColor: .orange,
                    label: "Drop-off",
                    value: student.scheduledDropoffTime
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func infoRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value.isEmpty ? "—" : value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Schedule Card

    private func scheduleCard(route: Route) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Schedule")

            // Date range
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Term \(route.term) · \(route.year)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(shortDate(route.startDate)) – \(shortDate(route.endDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Scheduled days chips
            if !route.scheduledDays.isEmpty {
                let ordered = orderedDays(from: route.scheduledDays)
                HStack(spacing: 8) {
                    ForEach(ordered, id: \.self) { day in
                        Text(String(day.prefix(3)).uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.indigo.opacity(0.12))
                            .foregroundColor(.indigo)
                            .clipShape(Capsule())
                    }
                }
            }

            // Mini calendar strip for current/next week
            calendarStrip(route: route)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func calendarStrip(route: Route) -> some View {
        let today = Calendar.current.startOfDay(for: Date())
        // Show 14 days from today
        let days: [Date] = (0..<14).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: today)
        }
        .filter { $0 >= route.startDate && $0 <= route.endDate }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { date in
                    let isScheduled = route.scheduledDays.contains(weekdayName(date))
                    let isToday = Calendar.current.isDateInToday(date)
                    VStack(spacing: 4) {
                        Text(shortWeekday(date))
                            .font(.caption2)
                            .foregroundColor(isScheduled ? .indigo : .secondary)
                        Text(dayNumber(date))
                            .font(.caption.bold())
                            .frame(width: 32, height: 32)
                            .background(
                                isToday ? Color.indigo :
                                isScheduled ? Color.indigo.opacity(0.12) : Color.clear
                            )
                            .foregroundColor(
                                isToday ? .white :
                                isScheduled ? .indigo : .secondary
                            )
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Parent Notes")

            if notes.isEmpty {
                Text("No active notes from your parent.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(notes) { note in
                        NoteRow(note: note)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
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

    // MARK: - Data Loading

    private func loadData() async {
        guard let uid = authManager.currentUserId else { return }
        isLoading = true
        errorMessage = nil

        do {
            let studentDoc = try await service.fetchStudent(id: uid)
            student = studentDoc

            // Fetch route
            if !studentDoc.routeId.isEmpty {
                let routeDoc = try await service.fetchRoute(id: studentDoc.routeId)
                route = routeDoc

                // Fetch driver via route
                if !routeDoc.driverId.isEmpty {
                    driver = try? await service.fetchDriver(id: routeDoc.driverId)
                }
            }

            // Fetch active notes for this student
            if let sid = studentDoc.id {
                notes = try await service.fetchActiveNotes(for: sid)
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(1)
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: Date())
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func weekdayName(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private func orderedDays(from days: [String]) -> [String] {
        let order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return order.filter { days.contains($0) }
    }
}

// MARK: - Note Row

private struct NoteRow: View {
    let note: FirestorePassengerNote

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: note.type == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(note.type == .pickup ? .green : .orange)
                .font(.body)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(note.noteText)
                    .font(.subheadline)
                Text("\(dateFormatter.string(from: note.fromDate)) – \(dateFormatter.string(from: note.toDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("From \(note.createdByParentName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

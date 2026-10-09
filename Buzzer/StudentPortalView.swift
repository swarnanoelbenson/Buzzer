//
//  StudentPortalView.swift
//  Buzzer
//
//  Student portal — read-only view of the same card layout as the parent portal.
//  Shows: Notes (read-only), Live Status, Student Summary, Driver, Bus cards.
//

import SwiftUI
import FirebaseFirestore

struct StudentPortalView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var student: Student? = nil
    @State private var route: Route? = nil
    @State private var driver: Driver? = nil
    @State private var notes: [FirestorePassengerNote] = []
    @State private var todaysTrips: [Trip] = []
    @State private var futureTrips: [Trip] = []
    @State private var completedTrips: [Trip] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    // Real-time listener handle
    @State private var tripsListener: ListenerRegistration? = nil

    // Collapsible card state
    @State private var completedTripsExpanded = false

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
                        tripsListener?.remove()
                        authManager.signOut()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .task {
            await loadData()
        }
        .onDisappear {
            tripsListener?.remove()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let student {
                    // Greeting header
                    greetingHeader(student: student)

                    // Notes card (read-only)
                    notesCard

                    // Live Status card
                    liveStatusCard(student: student)

                    // Student Summary card
                    studentSummaryCard(student: student)

                    // Driver card
                    driverCard

                    // Bus card
                    busCard

                    // Future trips card
                    futureTripsCard

                    // Completed trips card
                    completedTripsCard
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

    // MARK: - Notes Card (read-only)

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Notes")

            if notes.isEmpty {
                Text("No active notes.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(notes) { note in
                        NoteCard(
                            note: note,
                            canEdit: false,
                            canDelete: false,
                            onEdit: {},
                            onDelete: {}
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Live Status Card

    private func liveStatusCard(student: Student) -> some View {
        let pickupTrip = todaysTrips.first(where: { $0.type == .pickup && $0.studentRecords.contains(where: { $0.id == student.id }) })
        let dropoffTrip = todaysTrips.first(where: { $0.type == .dropoff && $0.studentRecords.contains(where: { $0.id == student.id }) })

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Today's Status")

            VStack(spacing: 0) {
                TripStatusRow(
                    label: "Morning Pick-up",
                    scheduledTime: student.scheduledPickupTime,
                    systemIcon: "arrow.up.circle.fill",
                    iconColor: .green,
                    trip: pickupTrip,
                    studentId: student.id ?? ""
                )

                Divider().padding(.leading, 36)

                TripStatusRow(
                    label: "Afternoon Drop-off",
                    scheduledTime: student.scheduledDropoffTime,
                    systemIcon: "arrow.down.circle.fill",
                    iconColor: .orange,
                    trip: dropoffTrip,
                    studentId: student.id ?? ""
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Student Summary Card

    private func studentSummaryCard(student: Student) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Student")

            VStack(alignment: .leading, spacing: 0) {
                portalInfoRow(icon: "person.fill", iconColor: .indigo, label: "Name", value: student.name)
                Divider().padding(.leading, 36)
                portalInfoRow(icon: "graduationcap.fill", iconColor: .indigo, label: "Grade", value: student.grade)
                if let route {
                    Divider().padding(.leading, 36)
                    portalInfoRow(icon: "calendar", iconColor: .blue, label: "Term", value: "Term \(route.term) · \(route.year)")
                    Divider().padding(.leading, 36)
                    portalInfoRow(icon: "calendar.badge.clock", iconColor: .blue, label: "Schedule", value: "\(shortDate(route.startDate)) – \(shortDate(route.endDate))")
                }
                Divider().padding(.leading, 36)
                portalInfoRow(icon: "arrow.up.circle.fill", iconColor: .green, label: "Pick-up", value: "\(student.scheduledPickupTime)  ·  \(student.stopAddressAM)")
                Divider().padding(.leading, 36)
                portalInfoRow(icon: "arrow.down.circle.fill", iconColor: .orange, label: "Drop-off", value: "\(student.scheduledDropoffTime)  ·  \(student.stopAddressPM)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Driver Card

    private var driverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Driver")

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
                        Text(driver.phone)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("No driver assigned")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Bus Card

    private var busCard: some View {
        let busRego = driver?.busRegistration ?? route?.busRegistration ?? "—"

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Bus")

            HStack(spacing: 14) {
                Image(systemName: "bus.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Registration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(busRego)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Future Trips Card

    private var futureTripsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Upcoming Schedule")

            if futureTrips.isEmpty {
                Text("No trips scheduled in the next 2 weeks.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(futureTrips.enumerated()), id: \.element.id) { index, trip in
                        if index > 0 { Divider().padding(.leading, 36) }
                        tripSummaryRow(trip: trip, isPast: false)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Completed Trips Card

    private var completedTripsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible, tappable to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    completedTripsExpanded.toggle()
                }
            } label: {
                HStack {
                    sectionLabel("Recent Completed Trips")
                    Spacer()
                    Image(systemName: completedTripsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding()

            // Collapsible body
            if completedTripsExpanded {
                Divider()
                    .padding(.horizontal)

                if completedTrips.isEmpty {
                    Text("No completed trips in the last 2 weeks.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(completedTrips.enumerated()), id: \.element.id) { index, trip in
                            if index > 0 { Divider().padding(.leading, 52) }
                            tripSummaryRow(trip: trip, isPast: true)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func tripSummaryRow(trip: Trip, isPast: Bool) -> some View {
        let isPickup = trip.type == .pickup
        let icon = isPickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        let iconColor: Color = isPickup ? .green : .orange
        let typeLabel = isPickup ? "Pick-up" : "Drop-off"
        let dateStr: String = {
            let f = DateFormatter()
            f.dateFormat = "EEE, d MMM"
            return f.string(from: trip.date)
        }()

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(typeLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(dateStr)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(isPast ? trip.status.rawValue.capitalized : "Scheduled")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isPast ? .secondary : .blue)
        }
        .padding(.vertical, 10)
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

            if !studentDoc.routeId.isEmpty {
                let routeDoc = try? await service.fetchRoute(id: studentDoc.routeId)
                route = routeDoc
                if let routeDoc, !routeDoc.driverId.isEmpty {
                    driver = try? await service.fetchDriver(id: routeDoc.driverId)
                }
            }

            if let sid = studentDoc.id {
                notes = (try? await service.fetchActiveNotes(for: sid)) ?? []

                // Fetch today's trips for this student
                let schoolId = studentDoc.schoolId
                let allTrips = try await service.fetchTodaysTrips(forStudentIds: [sid], schoolId: schoolId)
                todaysTrips = allTrips
                futureTrips = (try? await service.fetchFutureTrips(forStudentIds: [sid], schoolId: schoolId)) ?? []
                completedTrips = (try? await service.fetchCompletedTrips(forStudentIds: [sid], schoolId: schoolId)) ?? []

                // Start real-time listener
                startTripsListener(studentId: sid, schoolId: schoolId)
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func startTripsListener(studentId: String, schoolId: String) {
        tripsListener?.remove()

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        tripsListener = Firestore.db.collection("trips")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                let trips = snapshot.documents.compactMap { try? $0.data(as: Trip.self) }
                self.todaysTrips = trips.filter { trip in
                    trip.studentRecords.contains { $0.id == studentId }
                }
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

    private func portalInfoRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
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
}

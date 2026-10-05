//
//  TripDetailView.swift
//  Buzzer
//
//  Shows a single trip with its student list.
//  Driver taps Start to begin, then marks each student OnBus / OffBus / Absent.
//  Every change is written to Firestore immediately.
//

import SwiftUI
import FirebaseFirestore

struct TripDetailView: View {
    @Environment(AuthManager.self) private var authManager

    // Local mutable copy of the trip so UI updates instantly
    @State private var trip: Trip
    @State private var isStarting = false
    @State private var errorMessage: String? = nil
    @State private var routeName: String = ""
    @State private var driverName: String = "Your bus driver"

    init(trip: Trip) {
        _trip = State(initialValue: trip)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: Trip header card
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: trip.type == .pickup
                              ? "arrow.up.circle.fill"
                              : "arrow.down.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(trip.type == .pickup ? .green : .orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(routeName.isEmpty ? "Route" : routeName)
                                .font(.system(size: 22, weight: .bold))
                            Text(trip.type == .pickup ? "Pick-up Run" : "Drop-off Run")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        TripStatusBadge(status: trip.status)
                    }

                    Divider()

                    HStack {
                        Label(formattedDate, systemImage: "calendar")
                        Spacer()
                        Label("\(trip.studentRecords.count) students", systemImage: "person.2")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                // MARK: Progress bar
                if trip.status == .inProgress || trip.status == .completed {
                    let done = trip.studentRecords.filter { $0.status != .pending }.count
                    let total = trip.studentRecords.count
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Progress")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(done) / \(total)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        ProgressView(value: Double(done), total: Double(max(total, 1)))
                            .tint(trip.type == .pickup ? .green : .orange)
                    }
                    .padding(.horizontal)
                }

                // MARK: Start button
                if trip.status == .scheduled {
                    Button {
                        Task { await startTrip() }
                    } label: {
                        Group {
                            if isStarting {
                                ProgressView().tint(.white)
                            } else {
                                Label("Start \(trip.type == .pickup ? "Pick-up" : "Drop-off")",
                                      systemImage: "play.fill")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(trip.type == .pickup ? Color.green : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isStarting)
                    .padding(.horizontal)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                // MARK: Student list
                VStack(spacing: 0) {
                    ForEach($trip.studentRecords) { $record in
                        StudentTripRow(
                            record: $record,
                            tripType: trip.type,
                            isActive: trip.status == .inProgress,
                            tripId: trip.id ?? "",
                            driverName: driverName
                        )
                        if record.id != trip.studentRecords.last?.id {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.top, 12)
        }
        .navigationTitle(trip.type == .pickup ? "Pick-up" : "Drop-off")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTripInfo() }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f.string(from: trip.date)
    }

    private func loadTripInfo() async {
        if let route = try? await FirestoreService.shared.fetchRoute(id: trip.routeId) {
            routeName = route.name
        }
        if let uid = authManager.currentUserId,
           let driver = try? await FirestoreService.shared.fetchDriver(id: uid) {
            driverName = driver.name
        }
    }

    private func startTrip() async {
        guard let tripId = trip.id else { return }
        isStarting = true
        do {
            try await FirestoreService.shared.startTrip(id: tripId)
            trip.status = .inProgress
            trip.startedAt = Date()

            // Log activity
            if let uid = authManager.currentUserId {
                FirestoreService.shared.logActivity(
                    actorId: uid,
                    actorName: "Driver",
                    actorRole: "driver",
                    action: "Started \(trip.type.rawValue) trip for route \(trip.routeId)",
                    metadata: ["tripId": tripId, "routeId": trip.routeId]
                )
            }
        } catch {
            errorMessage = "Failed to start trip. Try again."
        }
        isStarting = false
    }
}

// MARK: - Student Trip Row

struct StudentTripRow: View {
    @Binding var record: StudentTripRecord
    let tripType: TripType
    let isActive: Bool
    let tripId: String
    let driverName: String

    @State private var isUpdating = false

    var body: some View {
        HStack(spacing: 14) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 20))
            }

            // Student info
            VStack(alignment: .leading, spacing: 3) {
                Text(record.studentName)
                    .font(.system(size: 16, weight: .semibold))
                Text(record.stopAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let ts = record.timestamp {
                    Text(formattedTime(ts))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Action buttons — only shown when trip is in progress and student is pending
            if isActive && record.status == .pending {
                if isUpdating {
                    ProgressView()
                        .frame(width: 80)
                } else {
                    HStack(spacing: 8) {
                        // OnBus / OffBus button
                        Button {
                            Task { await markStudent(tripType == .pickup ? .onBus : .offBus) }
                        } label: {
                            Text(tripType == .pickup ? "On Bus" : "Off Bus")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(tripType == .pickup ? Color.green : Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        // Absent button
                        Button {
                            Task { await markStudent(.absent) }
                        } label: {
                            Text("Absent")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.15))
                                .foregroundColor(.red)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Computed

    private var statusIcon: String {
        switch record.status {
        case .pending:  return "clock"
        case .onBus:    return "checkmark.circle.fill"
        case .offBus:   return "checkmark.circle.fill"
        case .absent:   return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch record.status {
        case .pending:  return .secondary
        case .onBus:    return .green
        case .offBus:   return .orange
        case .absent:   return .red
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    // MARK: - Actions

    private func markStudent(_ newStatus: StudentTripStatus) async {
        guard !tripId.isEmpty else { return }
        isUpdating = true
        do {
            try await FirestoreService.shared.updateStudentStatus(
                tripId: tripId,
                studentId: record.id,
                status: newStatus
            )
            // Update local state immediately so UI reflects change without re-fetch
            record.status = newStatus
            record.timestamp = Date()

            // Notify authorised parents
            await NotificationService.shared.notifyParents(
                studentId: record.id,
                studentName: record.studentName,
                status: newStatus,
                tripType: tripType,
                driverName: driverName
            )
        } catch {
            // Silent fail — Firestore write errors are non-critical here
        }
        isUpdating = false
    }
}

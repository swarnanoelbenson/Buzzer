//
//  SessionReviewView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct SessionReviewView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var sessionManager: SessionManager

    let list: AttendeeList
    let sessionType: SessionType

    // MARK: - Sheet state
    /// Attendee waiting for a green-tick timestamp entry (unmarked)
    @State private var attendeeForPresent: Attendee?

    /// Attendee whose existing record is being modified
    @State private var attendeeForModify: Attendee?

    var body: some View {
        NavigationView {
            List {
                // Summary section
                Section {
                    let summary = sessionManager.getSummary()
                    let presentLabel = sessionType == .pickup ? "On Bus" : "Off Bus"

                    HStack {
                        Label(presentLabel, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.green)
                        Spacer()
                        Text("\(summary.present)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 2)

                    HStack {
                        Label("Absent", systemImage: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(summary.absent)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 2)

                    HStack {
                        Label("Total", systemImage: "person.2.fill")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(list.attendees.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Summary")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                }

                // Attendee details
                Section {
                    ForEach(list.attendees) { attendee in
                        reviewRow(for: attendee)
                    }
                } header: {
                    Text("Attendance Details")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Session Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            // Timestamp sheet for marking an unmarked student present
            .sheet(item: $attendeeForPresent) { attendee in
                TimestampEntrySheet(
                    attendeeName: attendee.name,
                    sessionType: sessionType,
                    scheduledTime: sessionType == .pickup ? attendee.pickupTime : attendee.dropoffTime,
                    initialTime: (sessionType == .pickup ? attendee.pickupTime : attendee.dropoffTime) ?? Date()
                ) { chosenTime in
                    sessionManager.recordAttendance(for: attendee, status: .present, timestamp: chosenTime)
                }
            }
            // Modify sheet for updating an already-marked student
            .sheet(item: $attendeeForModify) { attendee in
                if let record = sessionManager.getRecord(for: attendee) {
                    ModifyAttendanceSheet(
                        attendeeName: attendee.name,
                        sessionType: sessionType,
                        currentStatus: record.status,
                        currentTimestamp: record.timestamp ?? (sessionType == .pickup ? attendee.pickupTime : attendee.dropoffTime) ?? Date()
                    ) { newStatus, newTimestamp in
                        sessionManager.recordAttendance(for: attendee, status: newStatus, timestamp: newTimestamp)
                    }
                }
            }
        }
    }

    // MARK: - Review Row

    @ViewBuilder
    private func reviewRow(for attendee: Attendee) -> some View {
        let record = sessionManager.getRecord(for: attendee)

        HStack(spacing: 14) {
            // Status icon
            Group {
                if let record {
                    Image(systemName: record.status == .present ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(record.status == .present ? .green : .red)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
            .font(.system(size: 26))

            // Name + timestamp
            VStack(alignment: .leading, spacing: 4) {
                Text(attendee.name)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                if let record {
                    if let timestamp = record.timestamp {
                        Text(TimestampFormatter.formatTime(timestamp))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    } else if record.status == .absent {
                        Text("Absent")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                    }
                }
            }

            Spacer()

            if record == nil {
                // Unmarked — show red cross and green tick
                HStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        sessionManager.recordAttendance(for: attendee, status: .absent, timestamp: nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)

                    Button {
                        attendeeForPresent = attendee
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Already marked — orange Modify button
                Button {
                    attendeeForModify = attendee
                } label: {
                    Text("Modify")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(record == nil ? Color.orange.opacity(0.10) : Color(uiColor: .systemBackground))
    }
}

// MARK: - Modify Attendance Sheet

struct ModifyAttendanceSheet: View {
    @Environment(\.dismiss) var dismiss

    let attendeeName: String
    let sessionType: SessionType
    let currentStatus: AttendanceStatus
    let currentTimestamp: Date
    let onConfirm: (AttendanceStatus, Date?) -> Void

    @State private var selectedStatus: AttendanceStatus
    @State private var selectedTime: Date

    init(
        attendeeName: String,
        sessionType: SessionType,
        currentStatus: AttendanceStatus,
        currentTimestamp: Date,
        onConfirm: @escaping (AttendanceStatus, Date?) -> Void
    ) {
        self.attendeeName = attendeeName
        self.sessionType = sessionType
        self.currentStatus = currentStatus
        self.currentTimestamp = currentTimestamp
        self.onConfirm = onConfirm
        _selectedStatus = State(initialValue: currentStatus)
        _selectedTime = State(initialValue: currentTimestamp)
    }

    private var presentLabel: String {
        sessionType == .pickup ? "On Bus" : "Off Bus"
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(attendeeName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(.vertical, 6)
                } header: {
                    Text("Student")
                }

                Section {
                    HStack(spacing: 12) {
                        // Absent button
                        Button {
                            selectedStatus = .absent
                        } label: {
                            Text("Absent")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(selectedStatus == .absent ? Color.red : Color.red.opacity(0.3))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        // Present button
                        Button {
                            selectedStatus = .present
                        } label: {
                            Text(presentLabel)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(selectedStatus == .present ? Color.green : Color.green.opacity(0.3))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Status")
                }

                if selectedStatus == .present {
                    Section {
                        DatePicker(
                            "Time",
                            selection: $selectedTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                    } header: {
                        Text("Timestamp")
                    }
                }

                Section {
                    Button {
                        let timestamp: Date? = selectedStatus == .present ? selectedTime : nil
                        onConfirm(selectedStatus, timestamp)
                        dismiss()
                    } label: {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.orange)
                }
            }
            .navigationTitle("Modify Attendance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SessionReviewView(
        sessionManager: {
            let manager = SessionManager(dataManager: DataManager())
            manager.recordedStatuses = [
                UUID(): AttendanceRecord(
                    attendeeId: UUID(),
                    status: .present,
                    timestamp: Date()
                )
            ]
            return manager
        }(),
        list: AttendeeList(name: "Morning Route", attendees: [
            Attendee(name: "John Doe", orderIndex: 0),
            Attendee(name: "Jane Smith", orderIndex: 1)
        ]),
        sessionType: .pickup
    )
}

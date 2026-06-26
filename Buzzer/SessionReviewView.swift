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
    @State private var showTimestampSheet = false

    /// Attendee whose existing record is being modified
    @State private var attendeeForModify: Attendee?
    @State private var showModifySheet = false

    var body: some View {
        NavigationView {
            List {
                // Summary section
                Section {
                    let summary = sessionManager.getSummary()

                    HStack {
                        Label("Present", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Text("\(summary.present)")
                            .font(.headline)
                    }

                    HStack {
                        Label("Absent", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(summary.absent)")
                            .font(.headline)
                    }

                    HStack {
                        Label("Total", systemImage: "person.2.fill")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(list.attendees.count)")
                            .font(.headline)
                    }
                } header: {
                    Text("Summary")
                }

                // Attendee details
                Section {
                    ForEach(list.attendees) { attendee in
                        reviewRow(for: attendee)
                    }
                } header: {
                    Text("Attendance Details")
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
            .sheet(isPresented: $showTimestampSheet) {
                if let attendee = attendeeForPresent {
                    TimestampEntrySheet(
                        attendeeName: attendee.name,
                        initialTime: (sessionType == .pickup ? attendee.pickupTime : attendee.dropoffTime) ?? Date()
                    ) { chosenTime in
                        sessionManager.recordAttendance(for: attendee, status: .present, timestamp: chosenTime)
                    }
                }
            }
            // Modify sheet for updating an already-marked student
            .sheet(isPresented: $showModifySheet) {
                if let attendee = attendeeForModify,
                   let record = sessionManager.getRecord(for: attendee) {
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

        HStack(spacing: 12) {
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
            .imageScale(.large)

            // Name + timestamp
            VStack(alignment: .leading, spacing: 3) {
                Text(attendee.name)
                    .font(.body)

                if let record {
                    if let timestamp = record.timestamp {
                        Text(TimestampFormatter.formatTime(timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if record.status == .absent {
                        Text("Absent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if record == nil {
                // Unmarked — show red cross and green tick
                HStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        sessionManager.recordAttendance(for: attendee, status: .absent, timestamp: nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)

                    Button {
                        attendeeForPresent = attendee
                        showTimestampSheet = true
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Already marked — orange Modify button
                Button {
                    attendeeForModify = attendee
                    showModifySheet = true
                } label: {
                    Text("Modify")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
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
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .padding(.vertical, 4)
                } header: {
                    Text("Student")
                }

                Section {
                    Picker("Status", selection: $selectedStatus) {
                        Text(presentLabel).tag(AttendanceStatus.present)
                        Text("Absent").tag(AttendanceStatus.absent)
                    }
                    .pickerStyle(.segmented)
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

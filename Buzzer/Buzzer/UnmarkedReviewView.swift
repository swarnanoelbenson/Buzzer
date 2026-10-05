//
//  UnmarkedReviewView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct UnmarkedReviewView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var sessionManager: SessionManager

    /// The attendees that had no record when this view was presented, in session order.
    let unmarkedAttendees: [Attendee]
    let sessionType: SessionType
    /// Called when the driver chooses to proceed to Final Check.
    let onProceed: () -> Void

    // MARK: - Timestamp entry pop-up state
    @State private var attendeeForTimestamp: Attendee?

    private var sessionDate: Date {
        sessionManager.currentSession?.createdDate ?? Date()
    }

    private var allMissedStudentsMarked: Bool {
        unmarkedAttendees.allSatisfy { sessionManager.getRecord(for: $0) != nil }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                (sessionType == .pickup ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .ignoresSafeArea()

                // Scrollable attendee list — padded at bottom to clear the Final Check button
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(unmarkedAttendees) { attendee in
                            attendeeRow(for: attendee)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 120) // space for the Final Check button
                }

                // Pinned Final Check button
                finalCheckButton
            }
            .navigationTitle("Missed Students")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            // Timestamp entry sheet — shown when green tick is tapped
            .sheet(item: $attendeeForTimestamp) { attendee in
                TimestampEntrySheet(
                    attendeeName: attendee.name,
                    sessionType: sessionType,
                    scheduledTime: sessionType == .pickup ? attendee.pickupTime : attendee.dropoffTime,
                    initialTime: (sessionType == .pickup ? attendee.pickupTime : attendee.dropoffTime) ?? Date()
                ) { chosenTime in
                    sessionManager.recordAttendance(for: attendee, status: .present, timestamp: chosenTime)
                }
            }
        }
    }

    // MARK: - Attendee Row

    private func attendeeRow(for attendee: Attendee) -> some View {
        let notes = PassengerNoteManager.shared.getActiveNotes(for: attendee.id, on: sessionDate)
        let accentColor: Color = sessionType == .pickup ? .green : .orange
        let scheduleTime: Date? = sessionType == .pickup ? attendee.pickupTime : attendee.dropoffTime
        let record = sessionManager.getRecord(for: attendee)
        let isMarked = record != nil

        return HStack(alignment: .center, spacing: 12) {
            // Name + scheduled time stacked on the left
            VStack(alignment: .leading, spacing: 4) {
                Text(attendee.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                if let time = scheduleTime {
                    HStack(spacing: 4) {
                        Image(systemName: sessionType == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundColor(accentColor)
                            .font(.system(size: 15))
                        Text(time, style: .time)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                if !notes.isEmpty {
                    ForEach(notes) { note in
                        HStack(spacing: 0) {
                            Text("NOTE: ")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                            Text(note.noteText)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentColor.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(accentColor.opacity(0.35), lineWidth: 1)
                                )
                        )
                    }
                }
            }

            Spacer()

            if isMarked {
                // Show the recorded status badge
                if let record {
                    Image(systemName: record.status == .present ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(record.status == .present ? .green : .red)
                }
            } else {
                // Red cross → mark absent
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    sessionManager.recordAttendance(for: attendee, status: .absent, timestamp: nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)

                // Green tick → open timestamp entry
                Button {
                    attendeeForTimestamp = attendee
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isMarked ? Color(uiColor: .systemBackground) : Color.orange.opacity(0.10))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Final Check Button

    private var finalCheckButton: some View {
        Button {
            dismiss()
            onProceed()
        } label: {
            Text("Final Check")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(allMissedStudentsMarked ? Color.green : Color.green.opacity(0.35))
                .cornerRadius(16)
        }
        .disabled(!allMissedStudentsMarked)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .padding(.top, 12)
        .background(
            Color(uiColor: .systemBackground)
                .opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Timestamp Entry Sheet

struct TimestampEntrySheet: View {
    @Environment(\.dismiss) var dismiss

    let attendeeName: String
    let sessionType: SessionType
    let scheduledTime: Date?
    let initialTime: Date
    let onConfirm: (Date) -> Void

    @State private var selectedTime: Date

    init(
        attendeeName: String,
        sessionType: SessionType,
        scheduledTime: Date?,
        initialTime: Date,
        onConfirm: @escaping (Date) -> Void
    ) {
        self.attendeeName = attendeeName
        self.sessionType = sessionType
        self.scheduledTime = scheduledTime
        self.initialTime = initialTime
        self.onConfirm = onConfirm
        _selectedTime = State(initialValue: initialTime)
    }

    private var presentLabel: String {
        sessionType == .pickup ? "On Bus" : "Off Bus"
    }

    private var scheduleIcon: String {
        sessionType == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }

    private var accentColor: Color {
        sessionType == .pickup ? .green : .orange
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 6) {
                    Text(attendeeName)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .padding(.horizontal, 16)

                    if let sched = scheduledTime {
                        HStack(spacing: 6) {
                            Image(systemName: scheduleIcon)
                                .foregroundColor(accentColor)
                            Text(sched, style: .time)
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    }

                    Text("Select the time for \(presentLabel)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                }

                DatePicker(
                    "Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .fontWeight(.bold)

                Spacer()

                Button {
                    onConfirm(selectedTime)
                    dismiss()
                } label: {
                    Text(presentLabel)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(accentColor)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Mark \(presentLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

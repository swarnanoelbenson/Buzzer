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

    @State private var showIgnoreConfirmation = false

    private var sessionDate: Date {
        sessionManager.currentSession?.createdDate ?? Date()
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                (sessionType == .pickup ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .ignoresSafeArea()

                // Scrollable attendee list — padded at bottom to clear the action buttons
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(unmarkedAttendees) { attendee in
                            attendeeRow(for: attendee)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 260) // space for the three action buttons
                }

                // Pinned action buttons
                actionButtons
            }
            .navigationTitle("Missed Students")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Skip These Students?", isPresented: $showIgnoreConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Proceed Anyway", role: .destructive) {
                    dismiss()
                    onProceed()
                }
            } message: {
                Text("These \(unmarkedAttendees.count) student\(unmarkedAttendees.count == 1 ? "'s" : "s'") attendance will be unrecorded in the report.")
            }
        }
    }

    // MARK: - Attendee Row

    private func attendeeRow(for attendee: Attendee) -> some View {
        let notes = PassengerNoteManager.shared.getActiveNotes(for: attendee.id, on: sessionDate)
        let accentColor: Color = sessionType == .pickup ? .green : .orange

        let scheduleTime: Date? = sessionType == .pickup ? attendee.pickupTime : attendee.dropoffTime
        let scheduleLabel = sessionType == .pickup ? "AM Pickup" : "PM Dropoff"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(attendee.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                if let time = scheduleTime {
                    HStack(spacing: 4) {
                        Image(systemName: sessionType == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundColor(accentColor)
                        Text("\(scheduleLabel): \(time, style: .time)")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                }
            }

            if !notes.isEmpty {
                VStack(spacing: 6) {
                    ForEach(notes) { note in
                        HStack(spacing: 0) {
                            Text("NOTE: ")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                            Text(note.noteText)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(accentColor.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(accentColor.opacity(0.35), lineWidth: 1.5)
                                )
                        )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                markAll(status: .present)
            } label: {
                Text("Mark these students Present")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.green)
                    .cornerRadius(16)
            }

            Button {
                markAll(status: .absent)
            } label: {
                Text("Mark these students Absent")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.red)
                    .cornerRadius(16)
            }

            Button {
                showIgnoreConfirmation = true
            } label: {
                Text("Ignore these students & Proceed")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1.5)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .padding(.top, 12)
        .background(
            Color(uiColor: .systemBackground)
                .opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Actions

    private func markAll(status: AttendanceStatus) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        for attendee in unmarkedAttendees {
            // When marking present, use the student's scheduled time as the timestamp
            // so the report reflects their expected pickup/dropoff time rather than now.
            let scheduledTime: Date? = status == .present
                ? (sessionType == .pickup ? attendee.pickupTime : attendee.dropoffTime)
                : nil
            sessionManager.recordAttendance(for: attendee, status: status, timestamp: scheduledTime)
        }

        dismiss()
        onProceed()
    }
}

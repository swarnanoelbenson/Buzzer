//
//  AttendanceTrackingView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct AttendanceTrackingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var sessionManager: SessionManager
    
    let list: AttendeeList
    let sessionType: SessionType
    
    @State private var showStopConfirmation = false
    @State private var showSessionReview = false
    @State private var showFinalCheck = false
    @State private var canSwipeBack = false
    @State private var showUnmarkedReview = false
    
    // Returns attendees in dropoff-reversed order so the last pickup stop is first to drop off
    private var orderedAttendees: [Attendee] {
        sessionType == .dropoff ? list.attendees.reversed() : list.attendees
    }

    var body: some View {
        ZStack {
            // Background color based on session type
            (sessionType == .pickup ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                progressBar
                
                if sessionManager.isCompleted(for: list) {
                    // Completed state
                    completedView
                } else {
                    // Active attendance tracking
                    attendanceView
                }
            }
        }
        .navigationTitle(sessionType == .pickup ? "AM PICKUP" : "PM DROPOFF")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showStopConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.circle.fill")
                        Text("Stop")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.red)
                }
            }
            

        }
        .alert("Stop Session?", isPresented: $showStopConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                stopSession()
            }
        } message: {
            Text("This will save all recorded attendance and end the session.")
        }
        .sheet(isPresented: $showUnmarkedReview) {
            UnmarkedReviewView(
                sessionManager: sessionManager,
                unmarkedAttendees: orderedAttendees.filter { sessionManager.getRecord(for: $0) == nil },
                sessionType: sessionType
            ) {
                showFinalCheck = true
            }
        }
        .sheet(isPresented: $showSessionReview) {
            SessionReviewView(
                sessionManager: sessionManager,
                list: list,
                sessionType: sessionType
            )
        }
        .sheet(isPresented: $showFinalCheck) {
            FinalCheckView(
                unmarkedAttendees: orderedAttendees.filter { sessionManager.getRecord(for: $0) == nil },
                sessionType: sessionType
            ) { timestamp in
                sessionManager.setFinalCheckTimestamp(timestamp)
                sessionManager.stopSession()
                dismiss()
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            let progress = sessionManager.getProgress(for: list)
            
            let summary = sessionManager.getSummary()
            HStack {
                HStack(spacing: 12) {
                    Label("\(summary.present)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)

                    Label("\(summary.absent)", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }

                Spacer()

                Text("\(progress.current) of \(progress.total)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            ProgressView(value: Double(progress.current), total: Double(progress.total))
                .tint(sessionType == .pickup ? .green : .orange)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    // MARK: - Attendance View
    
    private var attendanceView: some View {
        GeometryReader { geometry in
            // Each action button width = (totalWidth - 24*2 padding - 20 spacing) / 2
            let actionButtonWidth = (geometry.size.width - 48 - 20) / 2

            VStack(spacing: 0) {
                // Navigation arrows — above the attendee name
                HStack(spacing: 20) {
                    // Left arrow
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            sessionManager.goToPrevious()
                        }
                    } label: {
                        Text("Previous")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: actionButtonWidth, height: 80)
                            .background(Color(red: 0, green: 0.588, blue: 0.714))
                            .cornerRadius(16)
                    }
                    .disabled(sessionManager.currentAttendeeIndex == 0)
                    .opacity(sessionManager.currentAttendeeIndex == 0 ? 0.35 : 1.0)

                    // Right arrow
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            sessionManager.advanceToNext()
                        }
                    } label: {
                        Text("Next")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: actionButtonWidth, height: 80)
                            .background(Color(red: 0, green: 0.588, blue: 0.714))
                            .cornerRadius(16)
                    }
                    .disabled(sessionManager.currentAttendeeIndex >= orderedAttendees.count - 1)
                    .opacity(sessionManager.currentAttendeeIndex >= orderedAttendees.count - 1 ? 0.35 : 1.0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                Spacer()
                
                // Current attendee info
                if sessionManager.currentAttendeeIndex < orderedAttendees.count {
                    let currentAttendee = orderedAttendees[sessionManager.currentAttendeeIndex]

                    VStack(spacing: 24) {
                        // Attendee name
                        Text(currentAttendee.name)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)

                        // Scheduled pickup / dropoff time
                        scheduleTimeRow(for: currentAttendee)

                        // Active notes for today's session date
                        activeNotesView(for: currentAttendee)

                        // Status indicator if already recorded
                        if let record = sessionManager.getRecord(for: currentAttendee) {
                            HStack(spacing: 8) {
                                Image(systemName: record.status == .present ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(record.status == .present ? .green : .red)

                                Text(record.status == .present
                                    ? (sessionType == .pickup ? "On Bus" : "Off Bus")
                                    : "Marked Absent")
                                    .fontWeight(.medium)

                                if let timestamp = record.timestamp {
                                    Text("at \(timestamp, style: .time)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(20)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { gesture in
                                if gesture.translation.width > 100 && sessionManager.currentAttendeeIndex > 0 {
                                    withAnimation {
                                        sessionManager.goToPrevious()
                                    }
                                }
                            }
                    )
                }

                Spacer()

                // Present / Absent buttons at the bottom
                HStack(spacing: 20) {
                    // Absent button
                    Button {
                        markAttendance(status: .absent)
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 50))

                            Text("Absent")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }

                    // Present / On Bus / Off Bus button
                    Button {
                        markAttendance(status: .present)
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))

                            Text(sessionType == .pickup ? "On Bus" : "Off Bus")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Schedule Time Row

    @ViewBuilder
    private func scheduleTimeRow(for attendee: Attendee) -> some View {
        let accentColor: Color = sessionType == .pickup ? .green : .orange
        let time: Date? = sessionType == .pickup ? attendee.pickupTime : attendee.dropoffTime
        let label = sessionType == .pickup ? "AM Pickup" : "PM Dropoff"

        if let time {
            HStack(spacing: 6) {
                Image(systemName: sessionType == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(accentColor)
                Text("\(label): \(time, style: .time)")
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(accentColor.opacity(0.10))
            )
        }
    }

    // MARK: - Note View

    // Each note container is ~90pt tall (14 vertical padding × 2 + ~62pt text).
    // Show 2 notes (180pt) + a little of the third (20pt) so it's obvious there's more to scroll.
    private let noteContainerHeight: CGFloat = 90
    private let visibleNoteCount: CGFloat = 2

    @ViewBuilder
    private func activeNotesView(for attendee: Attendee) -> some View {
        let sessionDate = sessionManager.currentSession?.createdDate ?? Date()
        let activeNotes = PassengerNoteManager.shared.getActiveNotes(for: attendee.id, on: sessionDate)
        let accentColor: Color = sessionType == .pickup ? .green : .orange

        if !activeNotes.isEmpty {
            let scrollHeight = activeNotes.count > Int(visibleNoteCount)
                ? noteContainerHeight * visibleNoteCount + 20   // peek at third note
                : noteContainerHeight * CGFloat(activeNotes.count)

            ScrollView(.vertical, showsIndicators: activeNotes.count > Int(visibleNoteCount)) {
                VStack(spacing: 10) {
                    ForEach(activeNotes) { note in
                        noteContainer(text: note.noteText, accentColor: accentColor)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: scrollHeight)
        }
    }

    private func noteContainer(text: String, accentColor: Color) -> some View {
        HStack(spacing: 0) {
            Text("NOTE: ")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)
            Text(text)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(accentColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.4), lineWidth: 1.5)
                )
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Completed View
    
    private var completedView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            let summary = sessionManager.getSummary()
            VStack(spacing: 12) {
                HStack(spacing: 40) {
                    VStack {
                        Text("\(summary.present)")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.green)
                        Text("Present")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(summary.absent)")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.red)
                        Text("Absent")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 8)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button {
                    showSessionReview = true
                } label: {
                    Text("Review Session")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.accentColor)
                        .cornerRadius(16)
                }
                
                Button {
                    if sessionManager.unmarkedCount(for: list) > 0 {
                        showUnmarkedReview = true
                    } else {
                        showFinalCheck = true
                    }
                } label: {
                    Text("Final Check")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.green)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Actions
    
    private func markAttendance(status: AttendanceStatus) {
        guard sessionManager.currentAttendeeIndex < orderedAttendees.count else { return }
        
        let currentAttendee = orderedAttendees[sessionManager.currentAttendeeIndex]
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Record attendance
        sessionManager.recordAttendance(for: currentAttendee, status: status)
        
        // Auto-advance with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            sessionManager.advanceToNext()
        }
    }
    
    private func stopSession() {
        sessionManager.stopSession()
        dismiss()
    }
}

#Preview {
    NavigationView {
        AttendanceTrackingView(
            sessionManager: SessionManager(dataManager: DataManager()),
            list: AttendeeList(name: "Morning Route", attendees: [
                Attendee(name: "John Doe", orderIndex: 0),
                Attendee(name: "Jane Smith", orderIndex: 1),
                Attendee(name: "Bob Johnson", orderIndex: 2)
            ]),
            sessionType: .pickup
        )
    }
}

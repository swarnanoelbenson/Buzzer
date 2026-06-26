//
//  AttendanceTrackingView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct AttendanceTrackingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                // Snapshot the session to Core Data so it survives an app kill
                sessionManager.saveIncompleteSnapshot()
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
                        .font(.system(size: 15, weight: .medium, design: .rounded))

                    Label("\(summary.absent)", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }

                Spacer()

                Text("\(progress.current) of \(progress.total)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
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
            // Scale action button height relative to screen: ~180pt on large phones, smaller on iPhone 8
            let actionButtonHeight = min(180, geometry.size.height * 0.27)

            VStack(spacing: 0) {
                // Navigation arrows — always rendered in fixed positions
                let isFirstAttendee = sessionManager.currentAttendeeIndex == 0
                let isLastAttendee = sessionManager.currentAttendeeIndex >= orderedAttendees.count - 1
                HStack(spacing: 20) {
                    // Previous — left slot, invisible on first student
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            sessionManager.goToPrevious()
                        }
                    } label: {
                        Text("Previous")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: actionButtonWidth, height: min(80, geometry.size.height * 0.12))
                            .background(Color(red: 0, green: 0.588, blue: 0.714))
                            .cornerRadius(16)
                    }
                    .opacity(isFirstAttendee ? 0 : 1)
                    .disabled(isFirstAttendee)

                    // Next — right slot, invisible on last student
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            sessionManager.advanceToNext()
                        }
                    } label: {
                        Text("Next")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: actionButtonWidth, height: min(80, geometry.size.height * 0.12))
                            .background(Color(red: 0, green: 0.588, blue: 0.714))
                            .cornerRadius(16)
                    }
                    .opacity(isLastAttendee ? 0 : 1)
                    .disabled(isLastAttendee)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                Spacer()

                // Current attendee info — fixed three-slot layout
                if sessionManager.currentAttendeeIndex < orderedAttendees.count {
                    let currentAttendee = orderedAttendees[sessionManager.currentAttendeeIndex]
                    let record = sessionManager.getRecord(for: currentAttendee)
                    let accentColor: Color = sessionType == .pickup ? .green : .blue
                    let schedTime: Date? = sessionType == .pickup ? currentAttendee.pickupTime : currentAttendee.dropoffTime
                    let schedLabel = sessionType == .pickup ? "AM Pickup" : "PM Dropoff"
                    let schedIcon = sessionType == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill"

                    VStack(spacing: 20) {
                        // Slot 1: Attendee name
                        Text(currentAttendee.name)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)

                        // Slot 2: Scheduled time (fixed height, shown when available)
                        Group {
                            if let time = schedTime {
                                HStack(spacing: 6) {
                                    Image(systemName: schedIcon)
                                        .foregroundColor(accentColor)
                                    Text("\(schedLabel): \(time, style: .time)")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(accentColor.opacity(0.10))
                                )
                            } else {
                                Color.clear
                                    .frame(height: 52)
                            }
                        }

                        // Slot 3: Actual timestamp (always present, empty until marked)
                        HStack(spacing: 8) {
                            if let record {
                                Image(systemName: record.status == .present ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(record.status == .present ? (sessionType == .pickup ? .green : .blue) : .red)
                                Text(record.status == .present
                                    ? (sessionType == .pickup ? "On Bus" : "Off Bus")
                                    : "Marked Absent")
                                    .fontWeight(.medium)
                                if let timestamp = record.timestamp {
                                    Text("at \(timestamp, style: .time)")
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                // Empty placeholder to hold the space
                                Color.clear
                            }
                        }
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(height: 52)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(record != nil ? Color(uiColor: .secondarySystemBackground) : Color.clear)
                        )

                        // Active notes for today's session date
                        activeNotesView(for: currentAttendee)
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
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: actionButtonHeight)
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
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: actionButtonHeight)
                        .background(sessionType == .pickup ? Color.green : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
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
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            let summary = sessionManager.getSummary()
            VStack(spacing: 12) {
                HStack(spacing: 32) {
                    VStack {
                        Text("\(summary.present)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        Text(sessionType == .pickup ? "On Bus" : "Off Bus")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text("\(summary.absent)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                        Text("Absent")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text("\(list.attendees.count)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("Total")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                        .font(.system(size: 18, weight: .bold, design: .rounded))
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
                        .font(.system(size: 18, weight: .bold, design: .rounded))
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

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
    
    var body: some View {
        ZStack {
            // Background color based on session type
            (sessionType == .pickup ? Color.green.opacity(0.05) : Color.orange.opacity(0.05))
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
        .navigationTitle(sessionType == .pickup ? "Pick-Up" : "Drop-Off")
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showSessionReview) {
            SessionReviewView(
                sessionManager: sessionManager,
                list: list,
                sessionType: sessionType
            )
        }
        .sheet(isPresented: $showFinalCheck) {
            FinalCheckView { timestamp in
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
            
            HStack {
                Text("\(progress.current) of \(progress.total)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                let summary = sessionManager.getSummary()
                HStack(spacing: 12) {
                    Label("\(summary.present)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    
                    Label("\(summary.absent)", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
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
            VStack(spacing: 0) {
                Spacer()
                
                // Current attendee
                if sessionManager.currentAttendeeIndex < list.attendees.count {
                    let currentAttendee = list.attendees[sessionManager.currentAttendeeIndex]
                    
                    VStack(spacing: 24) {
                        // Attendee name
                        Text(currentAttendee.name)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)

                        // Active notes for today's session date
                        let sessionDate = sessionManager.currentSession?.createdDate ?? Date()
                        let activeNotes = PassengerNoteManager.shared.getActiveNotes(for: currentAttendee.id, on: sessionDate)
                        if !activeNotes.isEmpty {
                            VStack(spacing: 4) {
                                ForEach(activeNotes) { note in
                                    Text(note.noteText)
                                        .font(.subheadline)
                                        .italic()
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .padding(.horizontal, 32)
                                }
                            }
                        }

                        // Status indicator if already recorded
                        if let record = sessionManager.getRecord(for: currentAttendee) {
                            HStack(spacing: 8) {
                                Image(systemName: record.status == .present ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(record.status == .present ? .green : .red)
                                
                                Text(record.status == .present ? "Marked Present" : "Marked Absent")
                                    .fontWeight(.medium)
                                
                                if let timestamp = record.timestamp {
                                    Text("at \(timestamp, style: .time)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(20)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { gesture in
                                // Right swipe to undo
                                if gesture.translation.width > 100 && sessionManager.currentAttendeeIndex > 0 {
                                    withAnimation {
                                        sessionManager.goToPrevious()
                                    }
                                }
                            }
                    )
                }
                
                Spacer()
                
                // Action buttons
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
                    
                    // Present button
                    Button {
                        markAttendance(status: .present)
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                            
                            Text("Present")
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
                    showFinalCheck = true
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
        guard sessionManager.currentAttendeeIndex < list.attendees.count else { return }
        
        let currentAttendee = list.attendees[sessionManager.currentAttendeeIndex]
        
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

//
//  TripAttendanceView.swift
//  Buzzer
//
//  Full-screen card-swiper attendance flow for a Firestore trip.
//  One student per screen with Absent / On Bus (or Off Bus) buttons.
//  Mirrors the v4.0 UI from screenshots.
//

import SwiftUI

struct TripAttendanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: Trip

    let driverName: String

    // Index of the student currently displayed
    @State private var currentIndex: Int = 0

    // Completion / final-check state
    @State private var showSessionComplete = false
    @State private var showFinalCheckSheet = false

    // Stop confirmation
    @State private var showStopAlert = false

    // Error from Firestore writes
    @State private var errorMessage: String? = nil

    // Students ordered by stop order for this trip type
    private var students: [StudentTripRecord] {
        trip.studentRecords
    }

    private var tripType: TripType { trip.type }

    // MARK: - Computed helpers

    private var presentCount: Int {
        students.filter { $0.status == .onBus || $0.status == .offBus }.count
    }

    private var absentCount: Int {
        students.filter { $0.status == .absent }.count
    }

    private var unmarkedStudents: [StudentTripRecord] {
        students.filter { $0.status == .pending }
    }

    // Label for the "present" action
    private var presentLabel: String { tripType == .pickup ? "On Bus" : "Off Bus" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showSessionComplete {
                sessionCompleteView
            } else if currentIndex < students.count {
                attendanceCardView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showStopAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Stop")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(20)
                }
            }

            ToolbarItem(placement: .principal) {
                Text(tripType == .pickup ? "Pick-Up" : "Drop-Off")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Stop Session?", isPresented: $showStopAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) { dismiss() }
        } message: {
            Text("All recorded attendance will be saved. You can resume this trip later.")
        }
        .sheet(isPresented: $showFinalCheckSheet) {
            TripFinalCheckView(
                tripId: trip.id ?? "",
                unmarkedStudents: unmarkedStudents
            ) { timestamp in
                // Write completedAt to Firestore then go back to trip detail
                Task {
                    try? await FirestoreService.shared.finalCheckTrip(id: trip.id ?? "", at: timestamp)
                    trip.status = .completed
                    trip.completedAt = timestamp
                }
                dismiss()
            }
        }
    }

    // MARK: - Progress bar + counter header

    private var progressHeader: some View {
        VStack(spacing: 6) {
            HStack {
                // Present count
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(presentCount)")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }

                // Absent count
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("\(absentCount)")
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
                .padding(.leading, 8)

                Spacer()

                Text("\(currentIndex + 1) of \(students.count)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .padding(.horizontal, 20)

            // Green progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green)
                        .frame(width: geo.size.width * CGFloat(currentIndex) / CGFloat(max(students.count, 1)), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Main attendance card

    private var attendanceCardView: some View {
        let student = students[currentIndex]
        let alreadyMarked = student.status != .pending

        return VStack(spacing: 0) {
            progressHeader

            Spacer()

            // Student name — large, centred, bold, white
            Text(student.studentName)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .lineLimit(2)
                .padding(.horizontal, 24)

            // Already-marked indicator
            if alreadyMarked {
                HStack(spacing: 8) {
                    Image(systemName: student.status == .absent ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(student.status == .absent ? .red : .green)
                    Text(student.status == .absent ? "Absent" : presentLabel)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    if let ts = student.timestamp {
                        Text("at \(ts.formatted(date: .omitted, time: .shortened))")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
                .padding(.top, 20)
            }

            Spacer()

            // Absent / Present action buttons
            HStack(spacing: 16) {
                // Absent
                Button {
                    mark(student: student, status: .absent)
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 52))
                        Text("Absent")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }

                // On Bus / Off Bus
                Button {
                    mark(student: student, status: tripType == .pickup ? .onBus : .offBus)
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 52))
                        Text(presentLabel)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
        }
        .gesture(
            DragGesture(minimumDistance: 60)
                .onEnded { value in
                    // Swipe right = previous student
                    if value.translation.width > 80 && currentIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.2)) { currentIndex -= 1 }
                    }
                }
        )
    }

    // MARK: - Session Complete

    private var sessionCompleteView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Session Complete!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 48) {
                VStack(spacing: 6) {
                    Text("\(presentCount)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text(presentLabel)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }

                VStack(spacing: 6) {
                    Text("\(absentCount)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                    Text("Absent")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            VStack(spacing: 14) {
                // Review Session — scroll back through students
                Button {
                    withAnimation { showSessionComplete = false; currentIndex = 0 }
                } label: {
                    Text("Review Session")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.blue)
                        .cornerRadius(16)
                }

                // Final Check
                Button {
                    showFinalCheckSheet = true
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
            .padding(.bottom, 44)
        }
    }

    // MARK: - Actions

    private func mark(student: StudentTripRecord, status: StudentTripStatus) {
        guard let tripId = trip.id,
              let idx = trip.studentRecords.firstIndex(where: { $0.id == student.id })
        else { return }

        // Haptic
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Optimistic local update
        trip.studentRecords[idx].status = status
        trip.studentRecords[idx].timestamp = Date()

        // Firestore write (fire and forget — failure is non-critical mid-session)
        Task {
            try? await FirestoreService.shared.updateStudentStatus(
                tripId: tripId,
                studentId: student.id,
                status: status
            )

            // Notify parents
            await NotificationService.shared.notifyParents(
                studentId: student.id,
                studentName: student.studentName,
                status: status,
                tripType: tripType,
                driverName: driverName
            )
        }

        // Advance to next student, or show session complete screen
        withAnimation(.easeInOut(duration: 0.25)) {
            if currentIndex < students.count - 1 {
                currentIndex += 1
            } else {
                showSessionComplete = true
            }
        }
    }
}

// MARK: - Trip Final Check Sheet

struct TripFinalCheckView: View {
    @Environment(\.dismiss) private var dismiss

    let tripId: String
    let unmarkedStudents: [StudentTripRecord]
    let onConfirm: (Date) -> Void

    @State private var now = Date()
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Final Check")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    // Balance the layout
                    Color.clear.frame(width: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

                Spacer()

                // Checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 90))
                    .foregroundColor(.green)
                    .padding(.bottom, 28)

                Text("NO CHILDREN LEFT\nON BUS")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)

                // Unmarked students warning
                if !unmarkedStudents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unrecorded students:")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.orange)
                        ForEach(unmarkedStudents, id: \.id) { s in
                            Text("• \(s.studentName)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }

                // Clock
                VStack(spacing: 8) {
                    Text("Final Check Time")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Text(now.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 24)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20)
                .padding(.bottom, 16)

                Spacer()

                // Confirm button
                Button {
                    isSaving = true
                    onConfirm(now)
                } label: {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                            Text("Confirm")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(18)
                }
                .disabled(isSaving)
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
        .task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

//
//  TripAttendanceView.swift
//  Buzzer
//
//  Card-swiper attendance flow. One student per screen.
//  Flow:
//    Screen A: Pre-start (blank, "< Go Back" + "Start" centred)
//    Screen B: Per-student cards (name centred, notes below, nav buttons)
//    Screen C: Post-attendance (blank, "< Go Back" + "Final Check" + "Review Session")
//    Screen D: Final check sheet (dark, green tick, clock, Confirm)
//    Screen E: Review session (student list with status labels)
//

import SwiftUI

// MARK: - Attendance flow stage

private enum AttendanceStage {
    case preStart          // Screen A
    case attending         // Screen B
    case postAttendance    // Screen C
    case reviewSession     // Screen E (sheet or inline)
}

// MARK: - Main view

struct TripAttendanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: Trip

    let driverName: String
    /// Notes keyed by studentId — passed in from TripDetailView
    let studentNotes: [String: [FirestorePassengerNote]]

    @State private var stage: AttendanceStage = .preStart
    @State private var currentIndex: Int = 0
    @State private var showFinalCheckSheet = false
    @State private var showStopAlert = false

    private var students: [StudentTripRecord] { trip.studentRecords }
    private var tripType: TripType { trip.type }
    private var presentLabel: String { tripType == .pickup ? "On Bus" : "Off Bus" }

    private var presentCount: Int {
        students.filter { $0.status == .onBus || $0.status == .offBus }.count
    }
    private var absentCount: Int {
        students.filter { $0.status == .absent }.count
    }
    private var unmarkedStudents: [StudentTripRecord] {
        students.filter { $0.status == .pending }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch stage {
            case .preStart:
                preStartView
            case .attending:
                attendingView
            case .postAttendance:
                postAttendanceView
            case .reviewSession:
                reviewSessionView
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showFinalCheckSheet) {
            TripFinalCheckView(
                tripId: trip.id ?? "",
                unmarkedStudents: unmarkedStudents
            ) { timestamp in
                Task {
                    try? await FirestoreService.shared.finalCheckTrip(id: trip.id ?? "", at: timestamp)
                    trip.status = .completed
                    trip.completedAt = timestamp
                }
                dismiss()
            }
        }
        .alert("Stop Session?", isPresented: $showStopAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) { dismiss() }
        } message: {
            Text("All recorded attendance will be saved. You can resume this trip later.")
        }
    }

    // MARK: - Screen A: Pre-start

    private var preStartView: some View {
        VStack {
            // Top-left "< Go Back"
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Go Back")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            // "Start" button centred
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentIndex = 0
                    stage = .attending
                }
            } label: {
                Text("Start")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 180, height: 56)
                    .background(tripType == .pickup ? Color.green : Color.orange)
                    .cornerRadius(16)
            }

            Spacer()
        }
    }

    // MARK: - Screen B: Attending (per-student card)

    private var attendingView: some View {
        // Guard — should always be valid while attending
        guard currentIndex < students.count else { return AnyView(EmptyView()) }

        let student = students[currentIndex]
        let isFirst = currentIndex == 0
        let isLast = currentIndex == students.count - 1
        let notes = studentNotes[student.id] ?? []

        return AnyView(
            VStack(spacing: 0) {
                // ── Progress header ──────────────────────────────────────────
                progressHeader

                Spacer()

                // ── Student name centred ─────────────────────────────────────
                Text(student.studentName)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .lineLimit(2)
                    .padding(.horizontal, 24)

                // ── Notes directly below the name ────────────────────────────
                if !notes.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(notes) { note in
                            Text(note.noteText)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 28)
                        }
                    }
                    .padding(.top, 12)
                }

                // Already-marked indicator
                if student.status != .pending {
                    HStack(spacing: 8) {
                        Image(systemName: student.status == .absent
                              ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(student.status == .absent ? .red : .green)
                        Text(student.status == .absent ? "Absent" : presentLabel)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.10))
                    .cornerRadius(14)
                    .padding(.top, 18)
                }

                Spacer()

                // ── Previous / Cancel  ·  Next / Finish nav row ──────────────
                HStack(spacing: 16) {
                    // Left button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isFirst {
                                // "Cancel" → back to pre-start
                                stage = .preStart
                            } else {
                                currentIndex -= 1
                            }
                        }
                    } label: {
                        Text(isFirst ? "Cancel" : "Previous")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(14)
                    }

                    // Right button — mark student then advance / finish
                    if isLast {
                        Menu {
                            Button {
                                mark(student: student, status: .absent, thenFinish: true)
                            } label: {
                                Label("Absent", systemImage: "xmark.circle.fill")
                            }
                            Button {
                                mark(student: student,
                                     status: tripType == .pickup ? .onBus : .offBus,
                                     thenFinish: true)
                            } label: {
                                Label(presentLabel, systemImage: "checkmark.circle.fill")
                            }
                        } label: {
                            Text("Finish")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundColor(.white)
                                .background(Color.green)
                                .cornerRadius(14)
                        }
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentIndex += 1
                            }
                        } label: {
                            Text("Next")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // ── Absent / On Bus action buttons ──────────────────────────
                HStack(spacing: 16) {
                    // Absent
                    Button {
                        mark(student: student, status: .absent)
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 46))
                            Text("Absent")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }

                    // On Bus / Off Bus
                    Button {
                        mark(student: student,
                             status: tripType == .pickup ? .onBus : .offBus)
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 46))
                            Text(presentLabel)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
            // Stop button in navigation bar area (custom, since nav bar is hidden)
            .overlay(alignment: .topTrailing) {
                Button {
                    showStopAlert = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Stop")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(18)
                }
                .padding(.trailing, 20)
                .padding(.top, 16)
            }
        )
    }

    // MARK: - Progress header (used in Screen B)

    private var progressHeader: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("\(presentCount)")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
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

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green)
                        .frame(
                            width: geo.size.width * CGFloat(currentIndex) / CGFloat(max(students.count, 1)),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
        }
        .padding(.top, 52)  // space below status bar
        .padding(.bottom, 8)
    }

    // MARK: - Screen C: Post-attendance

    private var postAttendanceView: some View {
        VStack {
            // Top-left "< Go Back"
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentIndex = students.count - 1
                        stage = .attending
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Go Back")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 20) {
                // Review Session
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        stage = .reviewSession
                    }
                } label: {
                    Text("Review Session")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 260, height: 56)
                        .background(Color.blue)
                        .cornerRadius(16)
                }

                // Final Check
                Button {
                    showFinalCheckSheet = true
                } label: {
                    Text("Final Check")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 260, height: 56)
                        .background(Color.green)
                        .cornerRadius(16)
                }
            }

            Spacer()
        }
    }

    // MARK: - Screen E: Review Session

    private var reviewSessionView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        stage = .postAttendance
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Go Back")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                Spacer()
                Text("Review Session")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Color.clear.frame(width: 80) // balance
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(students) { student in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(student.studentName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            reviewStatusBadge(for: student)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                        if student.id != students.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func reviewStatusBadge(for student: StudentTripRecord) -> some View {
        switch student.status {
        case .onBus:
            statusPill(label: "On Bus", color: .green)
        case .offBus:
            statusPill(label: "Off Bus", color: .orange)
        case .absent:
            statusPill(label: "Absent", color: .red)
        case .pending:
            statusPill(label: "Pending", color: .gray)
        }
    }

    private func statusPill(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
    }

    // MARK: - Mark student status

    private func mark(student: StudentTripRecord, status: StudentTripStatus, thenFinish: Bool = false) {
        guard let tripId = trip.id,
              let idx = trip.studentRecords.firstIndex(where: { $0.id == student.id })
        else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Optimistic local update
        trip.studentRecords[idx].status = status
        trip.studentRecords[idx].timestamp = Date()

        // Firestore write
        Task {
            try? await FirestoreService.shared.updateStudentStatus(
                tripId: tripId,
                studentId: student.id,
                status: status
            )
            await NotificationService.shared.notifyParents(
                studentId: student.id,
                studentName: student.studentName,
                status: status,
                tripType: tripType,
                driverName: driverName
            )
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            if thenFinish {
                stage = .postAttendance
            } else if currentIndex < students.count - 1 {
                currentIndex += 1
            } else {
                stage = .postAttendance
            }
        }
    }
}

// MARK: - Trip Final Check Sheet (Screen D)

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
                    Button { dismiss() } label: {
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
                    Color.clear.frame(width: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 90))
                    .foregroundColor(.green)
                    .padding(.bottom, 28)

                Text("NO CHILDREN LEFT\nON BUS")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)

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

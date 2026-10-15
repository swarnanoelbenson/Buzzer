//
//  TripAttendanceView.swift
//  Buzzer
//
//  Card-swiper attendance flow. One student per screen.
//  Flow:
//    Screen A: Pre-start  — nav bar + "Start Pick Up / Drop Off" centred
//    Screen B: Per-student — nav buttons at TOP, name+notes centred, action buttons at bottom
//    Screen C: Post-attendance — nav bar + "Review Session" + "Final Check" centred
//    Screen D: Final Check sheet — dark, green tick, clock, Confirm
//    Screen E: Review Session — student list, per-student status change + add note, Final Check at bottom
//

import SwiftUI

// MARK: - Attendance flow stage

private enum AttendanceStage {
    case preStart       // Screen A
    case attending      // Screen B
    case postAttendance // Screen C
    case reviewSession  // Screen E
}

// MARK: - Main view

struct TripAttendanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: Trip

    let driverName: String
    let studentNotes: [String: [FirestorePassengerNote]]

    @State private var stage: AttendanceStage = .preStart
    @State private var currentIndex: Int = 0
    @State private var showFinalCheckSheet = false
    @State private var showStopAlert = false

    // Review session: per-student note adding
    @State private var addNoteForStudent: StudentTripRecord? = nil
    @State private var driverId: String = ""

    private var students: [StudentTripRecord] { trip.studentRecords }
    private var tripType: TripType { trip.type }
    private var presentLabel: String { tripType == .pickup ? "On Bus" : "Off Bus" }
    private var tripLabel: String { tripType == .pickup ? "Pick Up" : "Drop Off" }

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
                unmarkedStudents: unmarkedStudents,
                tripType: tripType,
                onReviewSession: {
                    showFinalCheckSheet = false
                    withAnimation(.easeInOut(duration: 0.25)) {
                        stage = .reviewSession
                    }
                }
            ) { timestamp in
                // Mark all still-pending students as absent
                let tripId = trip.id ?? ""
                for idx in trip.studentRecords.indices where trip.studentRecords[idx].status == .pending {
                    trip.studentRecords[idx].status = .absent
                    trip.studentRecords[idx].timestamp = timestamp
                    let studentId = trip.studentRecords[idx].id
                    Task {
                        try? await FirestoreService.shared.updateStudentStatus(
                            tripId: tripId, studentId: studentId, status: .absent)
                    }
                }
                Task {
                    try? await FirestoreService.shared.finalCheckTrip(id: tripId, at: timestamp)
                    trip.status = .completed
                    trip.completedAt = timestamp
                }
                dismiss()
            }
        }
        .sheet(item: $addNoteForStudent) { record in
            DriverAddNoteSheet(
                record: record,
                trip: trip,
                driverId: driverId,
                driverName: driverName
            ) { _ in
                // Note added — no local state update needed for review view
            }
        }
        .alert("Stop Session?", isPresented: $showStopAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) { dismiss() }
        } message: {
            Text("All recorded attendance will be saved. You can resume this trip later.")
        }
        .task {
            if let uid = try? await FirestoreService.shared.fetchDriver(id: "").id {
                driverId = uid
            }
        }
    }

    // MARK: - Screen A: Pre-start

    private var preStartView: some View {
        VStack(spacing: 0) {
            // Nav bar
            navBar(
                leading: {
                    AnyView(Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Go Back")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                    })
                },
                title: tripType == .pickup ? "Pick Up" : "Drop Off",
                trailing: { AnyView(Color.clear.frame(width: 80)) }
            )

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentIndex = 0
                    stage = .attending
                }
            } label: {
                Text("Start \(tripLabel)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 220, height: 56)
                    .background(tripType == .pickup ? Color.green : Color.orange)
                    .cornerRadius(16)
            }

            Spacer()
        }
    }

    // MARK: - Screen B: Attending (per-student card)

    private var attendingView: some View {
        guard currentIndex < students.count else { return AnyView(EmptyView()) }

        let student = students[currentIndex]
        let isFirst = currentIndex == 0
        let isLast  = currentIndex == students.count - 1
        let notes   = studentNotes[student.id] ?? []

        return AnyView(
            VStack(spacing: 0) {

                // ── Top: progress counts + bar ────────────────────────────────
                progressHeader

                // ── Nav buttons row (Cancel/Previous  ·  Next/Finish) ─────────
                HStack(spacing: 12) {
                    // Left
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isFirst {
                                stage = .preStart
                            } else {
                                currentIndex -= 1
                            }
                        }
                    } label: {
                        Text(isFirst ? "Cancel" : "Previous")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(12)
                    }

                    // Right
                    if isLast {
                        // Finish: pick status via menu then advance
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
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.white)
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentIndex += 1
                            }
                        } label: {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Spacer()

                // ── Student name centred ──────────────────────────────────────
                Text(student.studentName)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .lineLimit(2)
                    .padding(.horizontal, 24)

                // ── Notes directly below the name ─────────────────────────────
                if notes.isEmpty {
                    Text("Notes: None")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.40))
                        .padding(.top, 10)
                } else {
                    VStack(spacing: 5) {
                        ForEach(notes) { note in
                            Text(note.noteText)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 28)
                        }
                    }
                    .padding(.top, 10)
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

                // ── Absent / On Bus action buttons ────────────────────────────
                HStack(spacing: 16) {
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
            // Stop button top-right overlay
            .overlay(alignment: .topTrailing) {
                Button {
                    showStopAlert = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Stop")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(16)
                }
                .padding(.trailing, 20)
                .padding(.top, 14)
            }
        )
    }

    // MARK: - Progress header (Screen B)

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
        .padding(.top, 52)
        .padding(.bottom, 4)
    }

    // MARK: - Screen C: Post-attendance

    private var postAttendanceView: some View {
        VStack(spacing: 0) {
            navBar(
                leading: {
                    AnyView(Button {
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
                    })
                },
                title: tripType == .pickup ? "Pick Up" : "Drop Off",
                trailing: { AnyView(Color.clear.frame(width: 80)) }
            )

            Spacer()

            VStack(spacing: 20) {
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
            // Nav bar
            navBar(
                leading: {
                    AnyView(Button {
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
                    })
                },
                title: "Review Session",
                trailing: { AnyView(Color.clear.frame(width: 80)) }
            )

            // Student list scrollable
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(students) { student in
                        reviewRow(for: student)

                        if student.id != students.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 16)
            }

            Divider().background(Color.white.opacity(0.15))

            // Final Check button pinned at bottom
            Button {
                showFinalCheckSheet = true
            } label: {
                Text("Final Check")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.green)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func reviewRow(for student: StudentTripRecord) -> some View {
        HStack(spacing: 12) {
            Text(student.studentName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            // Status change menu
            Menu {
                Button {
                    changeStatus(student: student, to: tripType == .pickup ? .onBus : .offBus)
                } label: {
                    Label(presentLabel, systemImage: "checkmark.circle.fill")
                }
                Button {
                    changeStatus(student: student, to: .absent)
                } label: {
                    Label("Absent", systemImage: "xmark.circle.fill")
                }
                Divider()
                Button {
                    addNoteForStudent = student
                } label: {
                    Label("Add Note", systemImage: "note.text.badge.plus")
                }
            } label: {
                HStack(spacing: 6) {
                    reviewStatusContent(for: student)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func reviewStatusContent(for student: StudentTripRecord) -> some View {
        switch student.status {
        case .onBus:    statusPill(label: "On Bus",  color: .green)
        case .offBus:   statusPill(label: "Off Bus", color: .orange)
        case .absent:   statusPill(label: "Absent",  color: .red)
        case .pending:  statusPill(label: "Pending", color: .gray)
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

    // MARK: - Shared nav bar helper

    private func navBar<L: View, T: View>(
        leading: () -> L,
        title: String,
        trailing: () -> T
    ) -> some View {
        ZStack {
            HStack {
                leading()
                Spacer()
                trailing()
            }
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)  // below status bar
        .padding(.bottom, 14)
        .background(Color.black)
    }

    // MARK: - Mark student status (during attendance)

    private func mark(student: StudentTripRecord, status: StudentTripStatus, thenFinish: Bool = false) {
        guard let tripId = trip.id,
              let idx = trip.studentRecords.firstIndex(where: { $0.id == student.id })
        else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        trip.studentRecords[idx].status = status
        trip.studentRecords[idx].timestamp = Date()

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
            if thenFinish || currentIndex >= students.count - 1 {
                stage = .postAttendance
            } else {
                currentIndex += 1
            }
        }
    }

    // MARK: - Change status (from review session)

    private func changeStatus(student: StudentTripRecord, to status: StudentTripStatus) {
        guard let tripId = trip.id,
              let idx = trip.studentRecords.firstIndex(where: { $0.id == student.id })
        else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        trip.studentRecords[idx].status = status
        trip.studentRecords[idx].timestamp = Date()

        Task {
            try? await FirestoreService.shared.updateStudentStatus(
                tripId: tripId,
                studentId: student.id,
                status: status
            )
        }
    }
}

// MARK: - Trip Final Check Sheet (Screen D)

struct TripFinalCheckView: View {
    @Environment(\.dismiss) private var dismiss

    let tripId: String
    let unmarkedStudents: [StudentTripRecord]
    let tripType: TripType
    let onReviewSession: () -> Void
    let onConfirm: (Date) -> Void

    @State private var now = Date()
    @State private var isSaving = false

    private var completeLabel: String {
        tripType == .pickup ? "Complete Pick Up" : "Complete Drop Off"
    }

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
                .padding(.top, 56)
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

                // Unrecorded students banner
                if !unmarkedStudents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Unrecorded: Do you want to mark these students absent for this trip?")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(unmarkedStudents, id: \.id) { s in
                            Text("• \(s.studentName)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
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

                VStack(spacing: 14) {
                    // "Review Session" button — only when unrecorded students exist
                    if !unmarkedStudents.isEmpty {
                        Button {
                            onReviewSession()
                        } label: {
                            Text("Review Session")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.blue)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Complete button — marks unrecorded as absent, then completes trip
                    Button {
                        isSaving = true
                        onConfirm(now)
                    } label: {
                        HStack(spacing: 10) {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text(completeLabel)
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
                }
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

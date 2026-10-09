//
//  AdminAddNoteView.swift
//  Buzzer
//
//  Admin flow for adding a passenger note:
//  Screen 1 — search and select a student
//  Screen 2 — choose trip type, date range, note text, then submit
//

import SwiftUI
import FirebaseFirestore

struct AdminAddNoteView: View {
    let schoolId: String
    let onAdded: (FirestorePassengerNote) -> Void

    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var students: [Student] = []
    @State private var isLoadingStudents = true
    @State private var selectedStudent: Student? = nil

    private let service = FirestoreService.shared

    // MARK: - Filtered list

    private var filtered: [Student] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return students }
        return students.filter { $0.name.lowercased().contains(q) || $0.grade.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let student = selectedStudent {
                    AdminNoteFormView(
                        schoolId: schoolId,
                        student: student,
                        adminId: authManager.currentUserId ?? "",
                        onAdded: { note in
                            onAdded(note)
                            dismiss()
                        },
                        onBack: { selectedStudent = nil }
                    )
                } else {
                    studentPickerView
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await loadStudents() }
    }

    // MARK: - Student picker

    private var studentPickerView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search students…", text: $searchText)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if isLoadingStudents {
                Spacer()
                ProgressView("Loading students…")
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                ContentUnavailableView(
                    searchText.isEmpty ? "No Students" : "No Results",
                    systemImage: "person.slash",
                    description: Text(searchText.isEmpty ? "No active students found." : "No students match \"\(searchText)\".")
                )
                Spacer()
            } else {
                List(filtered) { student in
                    Button {
                        selectedStudent = student
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.12))
                                    .frame(width: 38, height: 38)
                                Text(String(student.name.prefix(1)))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.purple)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(student.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("Grade \(student.grade)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Load students

    private func loadStudents() async {
        isLoadingStudents = true
        let snap = try? await Firestore.db.collection("students")
            .whereField("schoolId", isEqualTo: schoolId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "name")
            .getDocuments()
        let loaded = (try? snap?.documents.map { try $0.data(as: Student.self) }) ?? []
        await MainActor.run {
            students = loaded
            isLoadingStudents = false
        }
    }
}

// MARK: - Note Form

private struct AdminNoteFormView: View {
    let schoolId: String
    let student: Student
    let adminId: String
    let onAdded: (FirestorePassengerNote) -> Void
    let onBack: () -> Void

    @State private var noteText: String = ""
    @State private var tripType: TripType = .pickup
    @State private var fromDate: Date = Date()
    @State private var toDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private let maxChars = 280
    private let service = FirestoreService.shared

    private var charsRemaining: Int { maxChars - noteText.count }
    private var canSubmit: Bool { !noteText.trimmingCharacters(in: .whitespaces).isEmpty && noteText.count <= maxChars && !isSaving }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Student info chip
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Text(String(student.name.prefix(1)))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.purple)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(student.name)
                            .font(.headline)
                        Text("Grade \(student.grade)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        onBack()
                    } label: {
                        Text("Change")
                            .font(.caption.bold())
                            .foregroundStyle(.purple)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Trip type picker
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Applies To")
                    Picker("Trip", selection: $tripType) {
                        Text("Morning Pick-up").tag(TripType.pickup)
                        Text("Afternoon Drop-off").tag(TripType.dropoff)
                    }
                    .pickerStyle(.segmented)
                }

                // Date range
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Date Range")
                    VStack(spacing: 0) {
                        DatePicker("From", selection: $fromDate, in: Date()..., displayedComponents: .date)
                            .padding(.vertical, 4)
                        Divider()
                        DatePicker("To", selection: $toDate, in: fromDate..., displayedComponents: .date)
                            .padding(.vertical, 4)
                    }
                    .padding(.horizontal, 14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Note text
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        sectionLabel("Note")
                        Spacer()
                        Text("\(charsRemaining)")
                            .font(.caption2)
                            .foregroundStyle(charsRemaining < 20 ? .red : .secondary)
                    }
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                        TextEditor(text: $noteText)
                            .font(.body)
                            .padding(10)
                            .frame(minHeight: 100)
                            .onChange(of: noteText) { _, new in
                                if new.count > maxChars {
                                    noteText = String(new.prefix(maxChars))
                                }
                            }
                        if noteText.isEmpty {
                            Text("e.g. Student will be collected by grandmother on this day")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(14)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(minHeight: 110)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }

                // Submit button
                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Submit Note")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSubmit ? Color.purple : Color.secondary.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canSubmit)
            }
            .padding()
        }
        .navigationTitle("Note for \(student.name.components(separatedBy: " ").first ?? student.name)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Students")
                    }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func submit() async {
        isSaving = true
        errorMessage = nil

        let routeName = await service.routeName(for: student.routeId)
        let note = FirestorePassengerNote(
            schoolId: schoolId,
            studentId: student.id ?? "",
            studentName: student.name,
            routeId: student.routeId,
            routeName: routeName,
            type: tripType,
            noteText: noteText.trimmingCharacters(in: .whitespaces),
            fromDate: Calendar.current.startOfDay(for: fromDate),
            toDate: Calendar.current.startOfDay(for: toDate),
            createdAt: Date(),
            createdById: adminId,
            createdByName: "Admin",
            createdByRole: "admin",
            isDeleted: false
        )

        do {
            let ref = try await service.addPassengerNote(note)
            let saved = FirestorePassengerNote(
                id: ref.documentID,
                schoolId: note.schoolId,
                studentId: note.studentId,
                studentName: note.studentName,
                routeId: note.routeId,
                routeName: note.routeName,
                type: note.type,
                noteText: note.noteText,
                fromDate: note.fromDate,
                toDate: note.toDate,
                createdAt: note.createdAt,
                createdById: note.createdById,
                createdByName: note.createdByName,
                createdByRole: note.createdByRole,
                isDeleted: false
            )
            onAdded(saved)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

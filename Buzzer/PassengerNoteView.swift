//
//  PassengerNoteView.swift
//  Buzzer
//

import SwiftUI

struct PassengerNoteView: View {
    let attendee: Attendee

    /// If set, this view edits an existing note instead of creating a new one.
    var existingNote: PassengerNote? = nil

    @State private var fromDate: Date
    @State private var toDate: Date
    @State private var noteText: String
    @State private var showDateError = false
    @State private var showSuccess = false

    @Environment(\.dismiss) var dismiss

    init(attendee: Attendee, existingNote: PassengerNote? = nil) {
        self.attendee = attendee
        self.existingNote = existingNote
        _fromDate = State(initialValue: existingNote?.fromDate ?? Date())
        _toDate = State(initialValue: existingNote?.toDate ?? Date())
        _noteText = State(initialValue: existingNote?.noteText ?? "")
    }

    private var isEditing: Bool { existingNote != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Passenger") {
                    Text(attendee.name)
                        .font(.headline)
                }

                Section {
                    DatePicker("From", selection: $fromDate, displayedComponents: .date)
                    DatePicker("To", selection: $toDate, displayedComponents: .date)
                } header: {
                    Text("Note Date Range")
                } footer: {
                    Text("The note will appear during attendance sessions within this date range.")
                }

                Section("Note") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if noteText.isEmpty {
                                Text("E.g. Parent picking up today, Early dismissal...")
                                    .foregroundColor(Color(uiColor: .placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section {
                    Button(isEditing ? "Update Note" : "Save Note") {
                        saveNote()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(isEditing ? "Edit Note" : "Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Invalid Date Range", isPresented: $showDateError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The \"From\" date must be on or before the \"To\" date.")
            }
            .alert(isEditing ? "Note Updated" : "Note Saved", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text(isEditing ? "The note has been updated." : "The note has been saved successfully.")
            }
        }
    }

    // MARK: - Actions

    private func saveNote() {
        // Validate: fromDate must not be after toDate
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: fromDate)
        let to = calendar.startOfDay(for: toDate)
        guard from <= to else {
            showDateError = true
            return
        }

        let trimmedText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = existingNote {
            PassengerNoteManager.shared.updateNote(
                id: existing.id,
                fromDate: from,
                toDate: to,
                noteText: trimmedText
            )
        } else {
            PassengerNoteManager.shared.addNote(
                attendeeID: attendee.id,
                attendeeName: attendee.name,
                fromDate: from,
                toDate: to,
                noteText: trimmedText
            )
        }
        showSuccess = true
    }
}

#Preview {
    PassengerNoteView(attendee: Attendee(name: "John Smith", orderIndex: 0))
}

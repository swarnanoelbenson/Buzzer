//
//  PassengerNotesListView.swift
//  Buzzer
//

import SwiftUI

struct PassengerNotesListView: View {
    let attendee: Attendee

    @State private var notes: [PassengerNote] = []
    @State private var showAddNote = false
    @State private var noteToEdit: PassengerNote?
    @State private var noteToDelete: PassengerNote?
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            if notes.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("No Notes Yet")
                            .font(.headline)
                        Text("Add a note to display it during attendance sessions.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section {
                    ForEach(notes) { note in
                        noteRow(note)
                    }
                }
            }

            Section {
                Button {
                    showAddNote = true
                } label: {
                    Label("Add Note", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(attendee.name)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadNotes() }
        .sheet(isPresented: $showAddNote, onDismiss: loadNotes) {
            PassengerNoteView(attendee: attendee)
        }
        .sheet(item: $noteToEdit, onDismiss: loadNotes) { note in
            PassengerNoteView(attendee: attendee, existingNote: note)
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirmation, presenting: noteToDelete) { note in
            Button("Cancel", role: .cancel) { noteToDelete = nil }
            Button("Delete", role: .destructive) {
                PassengerNoteManager.shared.deleteNote(id: note.id)
                loadNotes()
                noteToDelete = nil
            }
        } message: { note in
            Text("Are you sure you want to delete this note for \(note.attendeeName)?")
        }
    }

    // MARK: - Note Row

    private func noteRow(_ note: PassengerNote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.noteText)
                .font(.body)

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text("\(formatDate(note.fromDate)) – \(formatDate(note.toDate))")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                noteToDelete = note
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                noteToEdit = note
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }

    // MARK: - Helpers

    private func loadNotes() {
        notes = PassengerNoteManager.shared.getNotes(for: attendee.id)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        PassengerNotesListView(attendee: Attendee(name: "John Smith", orderIndex: 0))
    }
}

//
//  EditAttendeeView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct EditAttendeeView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    let list: AttendeeList
    let attendee: Attendee
    
    @State private var attendeeName: String
    @FocusState private var isTextFieldFocused: Bool
    
    init(list: AttendeeList, attendee: Attendee) {
        self.list = list
        self.attendee = attendee
        _attendeeName = State(initialValue: attendee.name)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Attendee Name", text: $attendeeName)
                        .focused($isTextFieldFocused)
                } header: {
                    Text("Edit Attendee Name")
                }
            }
            .navigationTitle("Edit Attendee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAttendee()
                    }
                    .disabled(attendeeName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
    
    private func saveAttendee() {
        let trimmedName = attendeeName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        var updatedAttendee = attendee
        updatedAttendee.name = trimmedName
        
        dataManager.updateAttendee(updatedAttendee, in: list)
        dismiss()
    }
}

#Preview {
    EditAttendeeView(
        list: AttendeeList(name: "Sample List"),
        attendee: Attendee(name: "John Doe")
    )
    .environmentObject(DataManager(persistenceController: PersistenceController()))
}

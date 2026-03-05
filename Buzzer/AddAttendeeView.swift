//
//  AddAttendeeView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct AddAttendeeView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    let list: AttendeeList
    
    @State private var attendeeName = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Attendee Name", text: $attendeeName)
                        .focused($isTextFieldFocused)
                } header: {
                    Text("Enter Attendee Name")
                } footer: {
                    Text("Enter the full name of the person to add to this list")
                }
            }
            .navigationTitle("Add Attendee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addAttendee()
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
    
    private func addAttendee() {
        let trimmedName = attendeeName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        dataManager.addAttendee(to: list, name: trimmedName)
        dismiss()
    }
}

#Preview {
    AddAttendeeView(list: AttendeeList(name: "Sample List"))
        .environmentObject(DataManager(persistenceController: PersistenceController()))
}

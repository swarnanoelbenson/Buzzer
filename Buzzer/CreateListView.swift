//
//  CreateListView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct CreateListView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var listName = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Route Name", text: $listName)
                        .focused($isTextFieldFocused)
                } header: {
                    Text("Enter Route Name")
                } footer: {
                    Text("Choose a descriptive name like \"Morning Route A\" or \"Bus 42\"")
                }
            }
            .navigationTitle("New Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
    
    private func createList() {
        let trimmedName = listName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        dataManager.createList(name: trimmedName)
        dismiss()
    }
}

#Preview {
    CreateListView()
        .environmentObject(DataManager(persistenceController: PersistenceController()))
}

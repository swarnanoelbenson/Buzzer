//
//  ListDetailView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct ListDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    
    let list: AttendeeList
    
    @State private var showingAddAttendee = false
    @State private var attendeeToDelete: Attendee?
    @State private var showDeleteConfirmation = false
    @State private var isEditMode: EditMode = .inactive
    @State private var attendeeToEdit: Attendee?
    @State private var showEditAttendee = false
    @State private var attendeeForNotes: Attendee?
    
    // Get the current list from dataManager
    private var currentList: AttendeeList? {
        dataManager.lists.first { $0.id == list.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let currentList = currentList {
                // Top action buttons (START SESSION and HISTORY)
                VStack(spacing: 12) {
                    // START SESSION button
                    if !currentList.attendees.isEmpty {
                        NavigationLink(destination: SessionSelectionView(list: currentList, dataManager: dataManager)) {
                            AccessibleNavigationButton(
                                "START SESSION",
                                systemImage: "play.fill",
                                color: .green
                            )
                        }
                        .accessibilityLabel("Start session")
                        .accessibilityHint("Start a new pick-up or drop-off session")
                    }
                    
                    // HISTORY button
                    NavigationLink(destination: SessionHistoryView(list: currentList)) {
                        AccessibleNavigationButton(
                            "View History",
                            subtitle: "Reports from previous days",
                            systemImage: "clock.fill",
                            color: .orange
                        )
                    }
                    .accessibilityLabel("Session history")
                    .accessibilityHint("View past attendance sessions")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                Divider()
                
                if currentList.attendees.isEmpty {
                    emptyStateView
                } else {
                    attendeeList(currentList: currentList)
                }
                
                // Bottom action bar
                actionBar
            } else {
                Text("List not found")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(currentList?.name ?? "List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Edit button
                EditButton()
                    .font(.system(size: 18)) // Larger font
            }
        }
        .environment(\.editMode, $isEditMode)
        .sheet(isPresented: $showingAddAttendee) {
            AddAttendeeView(list: list)
        }
        .sheet(item: $attendeeToEdit) { attendee in
            EditAttendeeView(list: list, attendee: attendee)
        }
        .sheet(item: $attendeeForNotes) { attendee in
            NavigationView {
                PassengerNotesListView(attendee: attendee)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { attendeeForNotes = nil }
                        }
                    }
            }
        }
        .alert("Remove Attendee", isPresented: $showDeleteConfirmation, presenting: attendeeToDelete) { attendee in
            Button("Cancel", role: .cancel) {
                attendeeToDelete = nil
            }
            Button("Remove", role: .destructive) {
                if let attendee = attendeeToDelete {
                    dataManager.deleteAttendee(attendee, from: list)
                }
                attendeeToDelete = nil
            }
        } message: { attendee in
            Text("Are you sure you want to remove \(attendee.name)?")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Attendees")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Add attendees to this list to start tracking attendance")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private func attendeeList(currentList: AttendeeList) -> some View {
        List {
            ForEach(currentList.attendees) { attendee in
                HStack {
                    Text(attendee.name)
                        .font(.body)
                    
                    Spacer()
                    
                    if isEditMode == .inactive {
                        HStack(spacing: 12) {
                            Button {
                                attendeeForNotes = attendee
                            } label: {
                                Image(systemName: "note.text")
                                    .foregroundColor(.orange)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)

                            Button {
                                attendeeToEdit = attendee
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .foregroundColor(.accentColor)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onMove { source, destination in
                moveAttendee(from: source, to: destination, in: currentList)
            }
            .onDelete { indexSet in
                // Use delete confirmation
                if let index = indexSet.first, index < currentList.attendees.count {
                    attendeeToDelete = currentList.attendees[index]
                    showDeleteConfirmation = true
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                // Add button
                Button {
                    showingAddAttendee = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                // Remove button (only show when not empty)
                if let currentList = currentList, !currentList.attendees.isEmpty {
                    Button {
                        if let lastAttendee = currentList.attendees.last {
                            attendeeToDelete = lastAttendee
                            showDeleteConfirmation = true
                        }
                    } label: {
                        Label("Remove", systemImage: "minus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
        }
    }
    
    private func moveAttendee(from source: IndexSet, to destination: Int, in currentList: AttendeeList) {
        var reorderedAttendees = currentList.attendees
        reorderedAttendees.move(fromOffsets: source, toOffset: destination)
        
        // Update order indexes
        let updatedAttendees = reorderedAttendees.enumerated().map { index, attendee in
            var updated = attendee
            updated.orderIndex = index
            return updated
        }
        
        dataManager.reorderAttendees(in: currentList, attendees: updatedAttendees)
    }
}

#Preview {
    NavigationView {
        ListDetailView(list: AttendeeList(name: "Sample List"))
    }
    .environmentObject(DataManager(persistenceController: PersistenceController()))
}

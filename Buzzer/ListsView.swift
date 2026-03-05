//
//  ListsView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct ListsView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var showingCreateList = false
    @State private var listToDelete: AttendeeList?
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if dataManager.lists.isEmpty {
                    emptyStateView
                } else {
                    listContent
                }
            }
            .navigationTitle("Buzzer")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSignOutConfirmation = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .imageScale(.large)
                            .accessibilityLabel("Sign out")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateList = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateList) {
                CreateListView()
            }
            .alert("Delete List", isPresented: $showDeleteConfirmation, presenting: listToDelete) { list in
                Button("Cancel", role: .cancel) {
                    listToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    dataManager.deleteList(list)
                    listToDelete = nil
                }
            } message: { list in
                Text("Are you sure you want to delete \"\(list.name)\"? This will remove all attendees and attendance records.")
            }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 70))
                .foregroundColor(.secondary)
            
            Text("No Lists Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first attendance list to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingCreateList = true
            } label: {
                Label("Create List", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            .padding(.top, 10)
        }
    }
    
    private var listContent: some View {
        List {
            ForEach(dataManager.lists) { list in
                NavigationLink(destination: ListDetailView(list: list)) {
                    ListRowView(list: list)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        listToDelete = list
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct ListRowView: View {
    let list: AttendeeList
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(list.name)
                .font(.headline)
            
            HStack {
                Label("\(list.attendees.count) attendees", systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(list.createdDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ListsView()
        .environmentObject(DataManager(persistenceController: PersistenceController()))
}

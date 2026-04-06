//
//  ListsView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct ListsView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var driverManager: DriverManager
    @ObservedObject private var demoModeManager = DemoModeManager.shared
    @State private var showingCreateList = false
    @State private var showingProfile = false
    @State private var listToDelete: AttendeeList?
    @State private var showDeleteConfirmation = false
    @State private var showExitDemoConfirmation = false

    var body: some View {
        NavigationView {
            ZStack {
                if dataManager.lists.isEmpty {
                    emptyStateView
                } else {
                    listContent
                }
            }
            .navigationTitle("BusMate")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .imageScale(.large)
                            .accessibilityLabel("Profile")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateList = true
                    } label: {
                        Image(systemName: "plus")
                            .imageScale(.large)
                            .accessibilityLabel("Create new route")
                    }
                }
            }
            .sheet(isPresented: $showingCreateList) {
                CreateListView()
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
            }
            .alert("Exit Demo Mode?", isPresented: $showExitDemoConfirmation) {
                Button("Exit & Clear Data", role: .destructive) {
                    demoModeManager.disableDemoMode(dataManager: dataManager)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all demo data and driver details, returning the app to its initial state.")
            }
            .alert("Delete Route", isPresented: $showDeleteConfirmation, presenting: listToDelete) { list in
                Button("Cancel", role: .cancel) {
                    listToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    dataManager.deleteList(list)
                    listToDelete = nil
                }
            } message: { list in
                Text("Are you sure you want to delete \"\(list.name)\"? This will remove all students and attendance records.")
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 70))
                .foregroundColor(.secondary)
            
            Text("No Routes Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first route to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingCreateList = true
            } label: {
                Label("Create Route", systemImage: "plus.circle.fill")
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
    
    private var demoBanner: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demo Mode Active")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text("Sample data is pre-loaded for review")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Exit") {
                    showExitDemoConfirmation = true
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            }
            .padding(.vertical, 4)
        }
        .listSectionSeparator(.hidden)
    }

    private var listContent: some View {
        List {
            if demoModeManager.isDemoMode {
                demoBanner
            }
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
                Label("\(list.attendees.count) student\(list.attendees.count == 1 ? "" : "s")", systemImage: "person.2")
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

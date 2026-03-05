//
//  SessionSelectionView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct SessionSelectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject var sessionManager: SessionManager
    
    let list: AttendeeList
    
    @State private var navigateToPickup = false
    @State private var navigateToDropoff = false
    @State private var showEmptyListAlert = false
    
    init(list: AttendeeList, dataManager: DataManager) {
        self.list = list
        _sessionManager = StateObject(wrappedValue: SessionManager(dataManager: dataManager))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text(currentList?.name ?? list.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("\(currentList?.attendees.count ?? 0) attendees")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Session type buttons
            VStack(spacing: 20) {
                // Pick-up button
                Button {
                    startSession(type: .pickup)
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                        Text("Start Pick-Up")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(isEmpty)
                
                // Last pick-up info
                if let lastPickup = dataManager.fetchRecentSession(for: list, type: .pickup) {
                    Text("Last pick-up: \(lastPickup.createdDate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Drop-off button
                Button {
                    startSession(type: .dropoff)
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                        Text("Start Drop-Off")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(isEmpty)
                
                // Last drop-off info
                if let lastDropoff = dataManager.fetchRecentSession(for: list, type: .dropoff) {
                    Text("Last drop-off: \(lastDropoff.createdDate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Empty list warning
            if isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Add attendees to this list before starting a session")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Start Session")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            Group {
                NavigationLink(
                    destination: AttendanceTrackingView(
                        list: currentList ?? list,
                        sessionType: .pickup,
                        sessionManager: sessionManager
                    ),
                    isActive: $navigateToPickup
                ) {
                    EmptyView()
                }
                
                NavigationLink(
                    destination: AttendanceTrackingView(
                        list: currentList ?? list,
                        sessionType: .dropoff,
                        sessionManager: sessionManager
                    ),
                    isActive: $navigateToDropoff
                ) {
                    EmptyView()
                }
            }
        )
    }
    
    private var currentList: AttendeeList? {
        dataManager.lists.first { $0.id == list.id }
    }
    
    private var isEmpty: Bool {
        (currentList?.attendees.isEmpty ?? true)
    }
    
    private func startSession(type: SessionType) {
        guard let currentList = currentList, !currentList.attendees.isEmpty else {
            showEmptyListAlert = true
            return
        }
        
        sessionManager.startSession(for: currentList, type: type)
        
        if type == .pickup {
            navigateToPickup = true
        } else {
            navigateToDropoff = true
        }
    }
}

#Preview {
    NavigationView {
        SessionSelectionView(
            list: AttendeeList(name: "Morning Route A", attendees: [
                Attendee(name: "John Doe"),
                Attendee(name: "Jane Smith")
            ]),
            dataManager: DataManager()
        )
    }
}

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
            
            // Session buttons
            VStack(spacing: 20) {
                
                Button {
                    startSession(type: .pickup)
                } label: {
                    sessionButton(
                        title: "Start Pick-Up",
                        systemImage: "arrow.up.circle.fill",
                        color: .green
                    )
                }
                .disabled(isEmpty)
                
                if let lastPickup = dataManager.fetchRecentSession(for: list, type: .pickup) {
                    Text("Last pick-up: \(lastPickup.createdDate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Button {
                    startSession(type: .dropoff)
                } label: {
                    sessionButton(
                        title: "Start Drop-Off",
                        systemImage: "arrow.down.circle.fill",
                        color: .orange
                    )
                }
                .disabled(isEmpty)
                
                if let lastDropoff = dataManager.fetchRecentSession(for: list, type: .dropoff) {
                    Text("Last drop-off: \(lastDropoff.createdDate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
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
        .background {
            // Hidden navigation links for programmatic navigation
            NavigationLink(
                destination: AttendanceTrackingView(
                    sessionManager: sessionManager,
                    list: currentList ?? list,
                    sessionType: .pickup
                    
                )
                .environmentObject(dataManager),
                isActive: $navigateToPickup
            ) {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(
                destination: AttendanceTrackingView(
                    sessionManager: sessionManager,
                    list: currentList ?? list,
                    sessionType: .dropoff
                    
                )
                .environmentObject(dataManager),
                isActive: $navigateToDropoff
            ) {
                EmptyView()
            }
            .hidden()
        }
    }
    
    // MARK: - Helpers
    
    private func sessionButton(title: String, systemImage: String, color: Color) -> some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(color)
        .foregroundColor(.white)
        .cornerRadius(16)
    }
    
    private var currentList: AttendeeList? {
        dataManager.lists.first { $0.id == list.id }
    }
    
    private var isEmpty: Bool {
        currentList?.attendees.isEmpty ?? true
    }
    
    private func startSession(type: SessionType) {
        guard let currentList = currentList,
              !currentList.attendees.isEmpty else {
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

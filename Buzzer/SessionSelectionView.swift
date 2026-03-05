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
                        .font(.system(size: 28, weight: .bold)) // Accessible size
                        .multilineTextAlignment(.center)
                        .accessibleHeader()
                    
                    Text("\(currentList?.attendees.count ?? 0) attendees")
                        .font(.system(size: 18)) // Accessible size
                        .foregroundColor(.secondary)
                        .accessibilityLabel("\(currentList?.attendees.count ?? 0) attendees in this list")
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Session buttons - Accessibility enhanced for 60+
                VStack(spacing: 20) {
                    
                    Button {
                        startSession(type: .pickup)
                    } label: {
                        sessionButton(
                            title: "Start Pick-Up",
                            systemImage: "arrow.up.circle.fill",
                            color: .accessibleGreen
                        )
                    }
                    .disabled(isEmpty)
                    .accessibilityLabel("Start pick-up session")
                    .accessibilityHint("Begin recording pick-up attendance")
                    
                    if let lastPickup = dataManager.fetchRecentSession(for: list, type: .pickup) {
                        Text("Last pick-up: \(lastPickup.createdDate, style: .relative)")
                            .font(.system(size: 16)) // Accessible font size
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Last pick-up session was \(lastPickup.createdDate, style: .relative)")
                    }
                    
                    AccessibleDivider()
                        .padding(.vertical, 8)
                    
                    Button {
                        startSession(type: .dropoff)
                    } label: {
                        sessionButton(
                            title: "Start Drop-Off",
                            systemImage: "arrow.down.circle.fill",
                            color: .accessibleOrange
                        )
                    }
                    .disabled(isEmpty)
                    .accessibilityLabel("Start drop-off session")
                    .accessibilityHint("Begin recording drop-off attendance")
                    
                    if let lastDropoff = dataManager.fetchRecentSession(for: list, type: .dropoff) {
                        Text("Last drop-off: \(lastDropoff.createdDate, style: .relative)")
                            .font(.system(size: 16)) // Accessible font size
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Last drop-off session was \(lastDropoff.createdDate, style: .relative)")
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
            .background(
                Group {
                    NavigationLink(
                        destination: AttendanceTrackingView(
                            sessionManager: sessionManager,
                            list: currentList ?? list,
                            sessionType: .pickup
                        ),
                        isActive: $navigateToPickup
                    ) {
                        EmptyView()
                    }
                    
                    NavigationLink(
                        destination: AttendanceTrackingView(
                            sessionManager: sessionManager,
                            list: currentList ?? list,
                            sessionType: .dropoff
                        ),
                        isActive: $navigateToDropoff
                    ) {
                        EmptyView()
                    }
                }
            )
        }
        
        // MARK: - Helpers
        
        private func sessionButton(title: String, systemImage: String, color: Color) -> some View {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 32)) // Large icon
                Text(title)
                    .font(.system(size: 24, weight: .bold)) // 20pt+ font for accessibility
            }
            .frame(maxWidth: .infinity)
            .frame(minWidth: 60, minHeight: 70) // Accessibility: 60x70pt minimum
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

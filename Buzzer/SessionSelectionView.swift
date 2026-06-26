    import SwiftUI

    private struct IncompleteSessionContext: Identifiable {
        let id = UUID()
        let session: AttendanceSession
        let list: AttendeeList
    }

    struct SessionSelectionView: View {
        @EnvironmentObject var dataManager: DataManager
        @StateObject var sessionManager: SessionManager
        
        let list: AttendeeList
        
        @State private var navigateToPickup = false
        @State private var navigateToDropoff = false
        @State private var showEmptyListAlert = false
        @State private var showConfirmationAlert = false
        @State private var pendingSessionType: SessionType?
        @State private var incompleteSessionContext: IncompleteSessionContext?
        
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
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .accessibleHeader()
                    
                    Text("\(currentList?.attendees.count ?? 0) student\(currentList?.attendees.count == 1 ? "" : "s")")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
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
                            title: "Start AM Pickup",
                            systemImage: "arrow.up.circle.fill",
                            color: .accessibleGreen
                        )
                    }
                    .disabled(isEmpty)
                    .accessibilityLabel("Start AM Pickup session")
                    .accessibilityHint("Begin recording AM Pickup attendance")
                    
                    if let lastPickup = dataManager.fetchRecentSession(for: list, type: .pickup) {
                        Text("Last AM Pickup: \(lastPickup.createdDate, style: .relative)")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Last AM Pickup session was \(lastPickup.createdDate, style: .relative)")
                    }
                    
                    AccessibleDivider()
                        .padding(.vertical, 8)
                    
                    Button {
                        startSession(type: .dropoff)
                    } label: {
                        sessionButton(
                            title: "Start PM Dropoff",
                            systemImage: "arrow.down.circle.fill",
                            color: .accessibleOrange
                        )
                    }
                    .disabled(isEmpty)
                    .accessibilityLabel("Start PM Dropoff session")
                    .accessibilityHint("Begin recording PM Dropoff attendance")
                    
                    if let lastDropoff = dataManager.fetchRecentSession(for: list, type: .dropoff) {
                        Text("Last PM Dropoff: \(lastDropoff.createdDate, style: .relative)")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Last PM Dropoff session was \(lastDropoff.createdDate, style: .relative)")
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
            .sheet(item: $incompleteSessionContext) { ctx in
                IncompleteSessionSheet(
                    session: ctx.session,
                    list: ctx.list,
                    onContinue: {
                        continueSession(ctx.session, list: ctx.list)
                    },
                    onStartNew: {
                        beginSession(type: ctx.session.sessionType)
                    }
                )
            }
            .alert("Session Already Completed", isPresented: $showConfirmationAlert) {
                Button("Cancel", role: .cancel) {
                    pendingSessionType = nil
                }
                Button("Start New", role: .destructive) {
                    if let type = pendingSessionType {
                        beginSession(type: type)
                    }
                }
            } message: {
                if let type = pendingSessionType {
                    let label = type == .pickup ? "AM Pickup" : "PM Dropoff"
                    Text("You have already completed a \(label) session today. Starting a new one will create a separate session record.")
                }
            }
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
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
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

            // Check for an incomplete session from today first
            if let incomplete = dataManager.fetchTodayIncompleteSession(for: currentList, type: type, attendeeCount: currentList.attendees.count) {
                incompleteSessionContext = IncompleteSessionContext(session: incomplete, list: currentList)
                return
            }

            // If a completed session already exists today, confirm before starting another
            if dataManager.fetchTodaySession(for: currentList, type: type) != nil {
                pendingSessionType = type
                showConfirmationAlert = true
            } else {
                beginSession(type: type)
            }
        }

        private func continueSession(_ session: AttendanceSession, list: AttendeeList) {
            let orderedAttendees = session.sessionType == .dropoff ? list.attendees.reversed() : list.attendees
            sessionManager.resumeSession(session, records: session.records, orderedAttendees: Array(orderedAttendees))
            if session.sessionType == .pickup {
                navigateToPickup = true
            } else {
                navigateToDropoff = true
            }
        }

        private func beginSession(type: SessionType) {
            guard let currentList = currentList else { return }
            sessionManager.startSession(for: currentList, type: type)
            pendingSessionType = nil
            if type == .pickup {
                navigateToPickup = true
            } else {
                navigateToDropoff = true
            }
        }
    }

//
//  SessionHistoryView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct SessionHistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    
    let list: AttendeeList
    
    @State private var sessions: [AttendanceSession] = []
    @State private var filterType: SessionFilterType = .all
    @State private var searchDate: Date = Date()
    @State private var showDatePicker = false
    @State private var showReportGenerator = false
    @State private var showWeeklyManifest = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter controls
            filterBar
            
            // Session list
            if filteredSessions.isEmpty {
                emptyStateView
            } else {
                sessionList
            }
        }
        .navigationTitle("Session History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSessions()
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $searchDate, onDone: {
                showDatePicker = false
            })
        }
        .sheet(isPresented: $showReportGenerator) {
            ReportGenerationView(list: list)
        }

    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        VStack(spacing: 12) {
            
            // Session type filter
            Picker("Filter", selection: $filterType) {
                ForEach(SessionFilterType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            
            // Date filter button
            Button {
                showDatePicker = true
            } label: {
                HStack {
                    Image(systemName: "calendar")
                    Text("Filter by Date: \(TimestampFormatter.formatDate(searchDate))")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Clear date filter
            if !Calendar.current.isDateInToday(searchDate) {
                Button {
                    searchDate = Date()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Clear Date Filter")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                .padding(.bottom, 8)
            }
            
            Divider()
            
            // DOWNLOAD REPORT Button (Blue)
            Button {
                showReportGenerator = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 24, weight: .semibold))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DOWNLOAD REPORT")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("Export and save attendance data")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .accessibilityLabel("Download Report")
            .accessibilityHint("Navigate to generate and download attendance reports")
            
            // Weekly Manifest Button (Purple)
//            Button {
//                showWeeklyManifest = true
//            } label: {
//                HStack(spacing: 12) {
//                    Image(systemName: "calendar.badge.checkmark")
//                        .font(.system(size: 24, weight: .semibold))
//                    
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("WEEKLY MANIFEST")
//                            .font(.system(size: 18, weight: .bold))
//                        
//                        Text("Generate weekly bus manifest")
//                            .font(.system(size: 14, weight: .regular))
//                            .foregroundColor(.white.opacity(0.9))
//                    }
//                    
//                    Spacer()
//                    
//                    Image(systemName: "chevron.right")
//                        .font(.system(size: 16, weight: .semibold))
//                        .foregroundColor(.white.opacity(0.8))
//                }
//                .frame(maxWidth: .infinity)
//                .frame(height: 70)
//                .padding(.horizontal, 16)
//                .padding(.vertical, 12)
//                .background(Color.purple)
//                .foregroundColor(.white)
//                .cornerRadius(12)
//            }
//            .padding(.horizontal)
//            .padding(.bottom, 12)
//            .accessibilityLabel("Weekly Manifest")
//            .accessibilityHint("Generate weekly bus manifest report")
//            
            Divider()
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    // MARK: - Session List
    
    private var sessionList: some View {
        List {
            ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { date in
                Section {
                    ForEach(groupedSessions[date] ?? []) { session in
                        NavigationLink(destination: SessionDetailView(session: session, list: list)) {
                            SessionHistoryRow(session: session)
                        }
                    }
                } header: {
                    Text(formatSectionDate(date))
                        .font(.headline)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Sessions Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(emptyStateMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if !sessions.isEmpty {
                Button {
                    filterType = .all
                    searchDate = Date()
                } label: {
                    Text("Clear Filters")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredSessions: [AttendanceSession] {
        sessions.filter { session in
            
            // Filter by type
            let typeMatches = filterType == .all || 
                             (filterType == .pickup && session.sessionType == .pickup) ||
                             (filterType == .dropoff && session.sessionType == .dropoff)
            
            // Filter by date
            let dateMatches = Calendar.current.isDateInToday(searchDate) || 
                             Calendar.current.isDate(session.createdDate, inSameDayAs: searchDate)
            
            return typeMatches && dateMatches
        }
    }
    
    private var groupedSessions: [Date: [AttendanceSession]] {
        Dictionary(grouping: filteredSessions) { session in
            Calendar.current.startOfDay(for: session.createdDate)
        }
    }
    
    private var emptyStateMessage: String {
        if sessions.isEmpty {
            return "No attendance sessions have been recorded yet. Start a pick-up or drop-off session to track attendance."
        } else if filterType != .all {
            return "No \(filterType.displayName.lowercased()) sessions found. Try changing your filter."
        } else if !Calendar.current.isDateInToday(searchDate) {
            return "No sessions found on \(TimestampFormatter.formatDateLong(searchDate)). Try a different date."
        } else {
            return "No sessions match your current filters."
        }
    }
    
    // MARK: - Helpers
    
    private func loadSessions() {
        sessions = dataManager.fetchSessions(for: list)
    }
    
    private func formatSectionDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return TimestampFormatter.formatDateLong(date)
        }
    }
}

// MARK: - Session History Row

struct SessionHistoryRow: View {
    let session: AttendanceSession
    
    var body: some View {
        HStack(spacing: 12) {
            // Session type icon
            Image(systemName: session.sessionType == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(session.sessionType == .pickup ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 4) {
                // Session type and time
                HStack {
                    Text(session.sessionType == .pickup ? "Pick-Up" : "Drop-Off")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(session.createdDate, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Summary
                HStack(spacing: 16) {
                    Label("\(presentCount) present", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Label("\(absentCount) absent", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var presentCount: Int {
        session.records.filter { $0.status == .present }.count
    }
    
    private var absentCount: Int {
        session.records.filter { $0.status == .absent }.count
    }
}

// MARK: - Session Filter Type

enum SessionFilterType: String, CaseIterable {
    case all = "all"
    case pickup = "pickup"
    case dropoff = "dropoff"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .pickup: return "Pick-Up"
        case .dropoff: return "Drop-Off"
        }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onDone: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SessionHistoryView(
            list: AttendeeList(name: "Morning Route", attendees: [
                Attendee(name: "John Doe", orderIndex: 0)
            ])
        )
        .environmentObject(DataManager())
    }
}

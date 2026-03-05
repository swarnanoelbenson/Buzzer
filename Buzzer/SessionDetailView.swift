//
//  SessionDetailView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct SessionDetailView: View {
    let session: AttendanceSession
    let list: AttendeeList
    
    @State private var showExportSheet = false
    
    var body: some View {
        List {
            // Session info section
            Section {
                sessionInfoRow(label: "Session Type", value: sessionTypeName, icon: sessionTypeIcon, color: sessionTypeColor)
                sessionInfoRow(label: "Date", value: TimestampFormatter.formatDateLong(session.createdDate), icon: "calendar", color: .blue)
                sessionInfoRow(label: "Time", value: TimestampFormatter.formatTime(session.createdDate), icon: "clock", color: .purple)
                sessionInfoRow(label: "List", value: list.name, icon: "list.bullet.clipboard", color: .orange)
            } header: {
                Text("Session Information")
            }
            
            // Summary section
            Section {
                summaryRow(label: "Present", count: presentCount, icon: "checkmark.circle.fill", color: .green)
                summaryRow(label: "Absent", count: absentCount, icon: "xmark.circle.fill", color: .red)
                summaryRow(label: "Total", count: session.records.count, icon: "person.2.fill", color: .secondary)
                
                if session.records.count > 0 {
                    HStack {
                        Label("Attendance Rate", systemImage: "chart.pie.fill")
                            .foregroundColor(.accentColor)
                        Spacer()
                        Text("\(attendanceRate)%")
                            .font(.headline)
                            .foregroundColor(attendanceRateColor)
                    }
                }
            } header: {
                Text("Summary")
            }
            
            // Attendee details section
            Section {
                ForEach(sortedRecords, id: \.id) { record in
                    AttendeeDetailRow(record: record, attendeeName: getAttendeeName(for: record.attendeeId))
                }
            } header: {
                Text("Attendance Details")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportOptionsSheet(session: session, list: list)
        }
    }
    
    // MARK: - Subviews
    
    private func sessionInfoRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(color)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
    
    private func summaryRow(label: String, count: Int, icon: String, color: Color) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(color)
            Spacer()
            Text("\(count)")
                .font(.headline)
        }
    }
    
    // MARK: - Computed Properties
    
    private var sessionTypeName: String {
        session.sessionType == .pickup ? "Pick-Up" : "Drop-Off"
    }
    
    private var sessionTypeIcon: String {
        session.sessionType == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }
    
    private var sessionTypeColor: Color {
        session.sessionType == .pickup ? .green : .orange
    }
    
    private var presentCount: Int {
        session.records.filter { $0.status == .present }.count
    }
    
    private var absentCount: Int {
        session.records.filter { $0.status == .absent }.count
    }
    
    private var attendanceRate: Int {
        guard session.records.count > 0 else { return 0 }
        return Int((Double(presentCount) / Double(session.records.count)) * 100)
    }
    
    private var attendanceRateColor: Color {
        if attendanceRate >= 90 {
            return .green
        } else if attendanceRate >= 70 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var sortedRecords: [AttendanceRecord] {
        // Sort by attendee order in the list
        session.records.sorted { record1, record2 in
            let index1 = list.attendees.firstIndex { $0.id == record1.attendeeId } ?? 999
            let index2 = list.attendees.firstIndex { $0.id == record2.attendeeId } ?? 999
            return index1 < index2
        }
    }
    
    // MARK: - Helpers
    
    private func getAttendeeName(for attendeeId: UUID) -> String {
        list.attendees.first { $0.id == attendeeId }?.name ?? "Unknown"
    }
}

// MARK: - Attendee Detail Row

struct AttendeeDetailRow: View {
    let record: AttendanceRecord
    let attendeeName: String
    
    var body: some View {
        HStack {
            // Status icon
            Image(systemName: record.status == .present ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(record.status == .present ? .green : .red)
                .imageScale(.large)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(attendeeName)
                    .font(.body)
                
                if let timestamp = record.timestamp {
                    Text(TimestampFormatter.formatTime(timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Absent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Export Options Sheet

struct ExportOptionsSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let session: AttendanceSession
    let list: AttendeeList
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Export functionality will be available in Phase 4")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } header: {
                    Text("Export Options")
                } footer: {
                    Text("Phase 4 will add CSV export, email sharing, and file save capabilities.")
                }
                
                Section {
                    HStack {
                        Label("Session Type", systemImage: session.sessionType == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        Spacer()
                        Text(session.sessionType == .pickup ? "Pick-Up" : "Drop-Off")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Date", systemImage: "calendar")
                        Spacer()
                        Text(TimestampFormatter.formatDate(session.createdDate))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Attendees", systemImage: "person.2")
                        Spacer()
                        Text("\(session.records.count)")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Session Summary")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Export Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SessionDetailView(
            session: AttendanceSession(
                listId: UUID(),
                sessionType: .pickup,
                createdDate: Date(),
                records: [
                    AttendanceRecord(
                        attendeeId: UUID(),
                        status: .present,
                        timestamp: Date()
                    ),
                    AttendanceRecord(
                        attendeeId: UUID(),
                        status: .absent,
                        timestamp: nil
                    )
                ]
            ),
            list: AttendeeList(name: "Morning Route", attendees: [
                Attendee(name: "John Doe", orderIndex: 0),
                Attendee(name: "Jane Smith", orderIndex: 1)
            ])
        )
    }
}

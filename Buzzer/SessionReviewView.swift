//
//  SessionReviewView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI

struct SessionReviewView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var sessionManager: SessionManager
    
    let list: AttendeeList
    let sessionType: SessionType
    
    @State private var attendeeToEdit: Attendee?
    @State private var showEditAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Summary section
                Section {
                    let summary = sessionManager.getSummary()
                    
                    HStack {
                        Label("Present", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Text("\(summary.present)")
                            .font(.headline)
                    }
                    
                    HStack {
                        Label("Absent", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(summary.absent)")
                            .font(.headline)
                    }
                    
                    HStack {
                        Label("Total", systemImage: "person.2.fill")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(list.attendees.count)")
                            .font(.headline)
                    }
                } header: {
                    Text("Summary")
                }
                
                // Attendee details
                Section {
                    ForEach(list.attendees) { attendee in
                        AttendeeReviewRow(
                            attendee: attendee,
                            record: sessionManager.getRecord(for: attendee)
                        )
                    }
                } header: {
                    Text("Attendance Details")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Session Review")
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

struct AttendeeReviewRow: View {
    let attendee: Attendee
    let record: AttendanceRecord?
    
    var body: some View {
        HStack {
            // Status icon
            if let record = record {
                Image(systemName: record.status == .present ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(record.status == .present ? .green : .red)
                    .imageScale(.large)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
                    .imageScale(.large)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(attendee.name)
                    .font(.body)
                
                if let record = record, let timestamp = record.timestamp {
                    Text(formatTime(timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let record = record, record.status == .absent {
                    Text("Absent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        return TimestampFormatter.formatTime(date)
    }
}

#Preview {
    SessionReviewView(
        sessionManager: {
            let manager = SessionManager(dataManager: DataManager())
            manager.recordedStatuses = [
                UUID(): AttendanceRecord(
                    attendeeId: UUID(),
                    status: .present,
                    timestamp: Date()
                )
            ]
            return manager
        }(),
        list: AttendeeList(name: "Morning Route", attendees: [
            Attendee(name: "John Doe", orderIndex: 0),
            Attendee(name: "Jane Smith", orderIndex: 1)
        ]),
        sessionType: .pickup
    )
}

//
//  SessionDetailView.swift
//  Buzzer
//
//  Created by Noel Benson on 4/3/2026.
//

import SwiftUI
import UniformTypeIdentifiers

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

    @State private var showFileExporter = false
    @State private var csvDocument: CSVDocument?
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var isGenerating = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        generateManifest()
                    } label: {
                        HStack {
                            Label("Export as CSV", systemImage: "doc.text")
                            Spacer()
                            if isGenerating {
                                ProgressView().progressViewStyle(.circular)
                            }
                        }
                    }
                    .disabled(isGenerating)
                } header: {
                    Text("Export Options")
                } footer: {
                    Text("Export this session as a CSV manifest. You can save it to Files, share via email, or send to other apps.")
                }

                Section {
                    HStack {
                        Label("Session Type", systemImage: session.sessionType == .pickup ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundColor(session.sessionType == .pickup ? .green : .orange)
                        Spacer()
                        Text(session.sessionType == .pickup ? "Pick-Up" : "Drop-Off")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Date", systemImage: "calendar")
                            .foregroundColor(.blue)
                        Spacer()
                        Text(TimestampFormatter.formatDate(session.createdDate))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Time", systemImage: "clock")
                            .foregroundColor(.purple)
                        Spacer()
                        Text(TimestampFormatter.formatTime(session.createdDate))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Attendees", systemImage: "person.2")
                            .foregroundColor(.orange)
                        Spacer()
                        Text("\(session.records.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Present", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Text("\(presentCount)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Absent", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(absentCount)")
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
            .fileExporter(
                isPresented: $showFileExporter,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: csvDocument?.filename ?? "session.csv",
                onCompletion: handleExport
            )
            .alert("Export Successful", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Session manifest has been saved successfully.")
            }
            .alert("Export Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Failed to generate CSV file. Please try again.")
            }
        }
    }

    // MARK: - Computed Properties

    private var presentCount: Int {
        session.records.filter { $0.status == .present }.count
    }

    private var absentCount: Int {
        session.records.filter { $0.status == .absent }.count
    }

    // MARK: - Generate Manifest

    private func generateManifest() {
        isGenerating = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let attendeeIDs = list.attendees.map { $0.id }
            let notes = PassengerNoteManager.shared.getNotes(for: attendeeIDs)
            let driverDetails = DriverManager.shared.driverDetails

            let csvContent = CSVGenerator.generateSingleSessionManifest(
                for: session,
                list: list,
                driverDetails: driverDetails,
                passengerNotes: notes
            )
            let filename = CSVGenerator.generateFilename(for: session, list: list)

            csvDocument = CSVDocument(content: csvContent, filename: filename)
            isGenerating = false
            showFileExporter = true
        }
    }

    // MARK: - Export Handler

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            showSuccessAlert = true
        case .failure(let error):
            print("Export failed: \(error.localizedDescription)")
            showErrorAlert = true
        }
    }
}

// MARK: - CSV Document (for fileExporter)

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let content: String
    let filename: String

    init(content: String, filename: String) {
        self.content = content
        self.filename = filename
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let str = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = str
        self.filename = "session.csv"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
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

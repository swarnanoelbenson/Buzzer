//
//  ReportGenerationView.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct ReportGenerationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    let list: AttendeeList
    
    @State private var reportType: ReportType = .today
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var showFileExporter = false
    @State private var csvDocument: CSVDocument?
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isGenerating = false
    
    var body: some View {
        NavigationView {
            List {
                reportTypeSection
                dateRangeSection
                previewSection
                generateButtonSection
                emptyStateSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Generate Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: csvDocument?.filename ?? "report.csv",
                onCompletion: handleFileExport
            )
            .alert("Export Successful", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("CSV report has been successfully created and saved.")
            }
            .alert("Export Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - View Sections
    
    private var reportTypeSection: some View {
        Section {
            Picker("Report Type", selection: $reportType) {
                ForEach(ReportType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Report Type")
        } footer: {
            Text(reportType.description)
        }
    }
    
    private var dateRangeSection: some View {
        Group {
            if reportType == .dateRange {
                Section {
                    DatePicker("Start Date", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                } header: {
                    Text("Date Range")
                } footer: {
                    Text("Select the start and end dates for your report.")
                }
            }
        }
    }
    
    private var previewSection: some View {
        Section {
            listPreviewRow
            sessionsPreviewRow
            filenamePreviewRow
        } header: {
            Text("Preview")
        }
    }
    
    private var listPreviewRow: some View {
        HStack {
            Label("List", systemImage: "list.bullet.clipboard")
                .foregroundColor(.orange)
            Spacer()
            Text(list.name)
                .foregroundColor(.secondary)
        }
    }
    
    private var sessionsPreviewRow: some View {
        HStack {
            Label("Sessions", systemImage: "clock.fill")
                .foregroundColor(.blue)
            Spacer()
            Text("\(sessionsToExport.count)")
                .foregroundColor(.secondary)
        }
    }
    
    private var filenamePreviewRow: some View {
        HStack {
            Label("File Name", systemImage: "doc.text")
                .foregroundColor(.purple)
            Spacer()
            Text(filename)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    private var generateButtonSection: some View {
        Section {
            Button(action: generateReport) {
                HStack {
                    Spacer()
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding(.trailing, 8)
                    }
                    Text(isGenerating ? "Generating..." : "Generate & Export CSV")
                        .font(.headline)
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
            }
            .listRowBackground(Color.accentColor)
            .disabled(isGenerating || sessionsToExport.isEmpty)
        }
    }
    
    private var emptyStateSection: some View {
        Group {
            if sessionsToExport.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("No sessions available for the selected criteria")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var sessionsToExport: [AttendanceSession] {
        let allSessions = dataManager.fetchSessions(for: list)
        
        switch reportType {
        case .today:
            return allSessions.filter { Calendar.current.isDateInToday($0.createdDate) }
        case .yesterday:
            return allSessions.filter { Calendar.current.isDateInYesterday($0.createdDate) }
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return allSessions.filter { $0.createdDate >= weekAgo }
        case .thisMonth:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return allSessions.filter { $0.createdDate >= monthAgo }
        case .dateRange:
            let start = Calendar.current.startOfDay(for: startDate)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
            return allSessions.filter { $0.createdDate >= start && $0.createdDate < end }
        case .all:
            return allSessions
        }
    }
    
    private var filename: String {
        switch reportType {
        case .today:
            return CSVGenerator.generateTodayFilename(for: list)
        case .dateRange:
            return CSVGenerator.generateFilename(for: list, dateRange: (startDate, endDate))
        default:
            return CSVGenerator.generateFilename(for: list, dateRange: nil)
        }
    }
    
    // MARK: - Generate Report
    
    private func generateReport() {
        isGenerating = true
        
        // Small delay to show loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let csvContent: String
            
            switch reportType {
            case .today:
                csvContent = CSVGenerator.generateTodayReport(for: sessionsToExport, list: list)
            default:
                let dateRange: (start: Date, end: Date)? = reportType == .dateRange ? (startDate, endDate) : nil
                csvContent = CSVGenerator.generateCSV(for: sessionsToExport, list: list, dateRange: dateRange)
            }
            
            // Validate CSV content
            guard !csvContent.isEmpty else {
                errorMessage = "Failed to generate CSV content. No data available."
                showErrorAlert = true
                isGenerating = false
                return
            }
            
            // Create document and show file exporter
            csvDocument = CSVDocument(content: csvContent, filename: filename)
            isGenerating = false
            showFileExporter = true
            
            print("✅ CSV generated successfully")
            print("✅ File size: \(csvContent.count) characters")
        }
    }
    
    // MARK: - File Export Handler
    
    private func handleFileExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("✅ Report successfully saved to: \(url)")
            showSuccessAlert = true
        case .failure(let error):
            errorMessage = "Failed to save report: \(error.localizedDescription)"
            showErrorAlert = true
            print("❌ Report export failed: \(error)")
        }
    }
}

// MARK: - Report Type

enum ReportType: String, CaseIterable {
    case today = "today"
    case yesterday = "yesterday"
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case dateRange = "date_range"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .dateRange: return "Date Range"
        case .all: return "All Sessions"
        }
    }
    
    var description: String {
        switch self {
        case .today: return "Export all sessions from today with combined pick-up and drop-off times."
        case .yesterday: return "Export all sessions from yesterday."
        case .thisWeek: return "Export sessions from the last 7 days."
        case .thisMonth: return "Export sessions from the last 30 days."
        case .dateRange: return "Export sessions within a custom date range."
        case .all: return "Export all available sessions for this list."
        }
    }
}

// MARK: - CSV Document (For fileExporter)

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
              let content = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = content
        self.filename = "report.csv"
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    ReportGenerationView(list: AttendeeList(name: "Morning Route", attendees: [
        Attendee(name: "John Doe", orderIndex: 0),
        Attendee(name: "Jane Smith", orderIndex: 1)
    ]))
    .environmentObject(DataManager())
}

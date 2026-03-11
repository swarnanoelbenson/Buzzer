//
//  ReportGenerationView.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import MessageUI

struct ReportGenerationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var driverManager: DriverManager
    
    let list: AttendeeList
    
    @State private var weekStartDate = Date()
    @State private var showFileExporter = false
    @State private var csvDocument: CSVDocument?
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isGenerating = false
    @State private var showMailComposer = false
    @State private var mailAttachmentData: Data?
    
    var body: some View {
        NavigationView {
            List {
                weekSelectionSection
                previewSection
                generateButtonSection
                emptyStateSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Weekly Manifest")
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
                defaultFilename: csvDocument?.filename ?? "manifest.csv",
                onCompletion: handleFileExport
            )
            .alert("Export Successful", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Weekly manifest has been successfully created and saved.")
            }
            .alert("Export Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposeView(
                    recipientEmail: driverManager.driverDetails?.email ?? "",
                    subject: "Bus Manifest Report - \(list.name) - Week of \(TimestampFormatter.formatDateShort(mondayDate))",
                    body: "Please find the weekly attendance report attached.",
                    attachmentData: mailAttachmentData,
                    attachmentFilename: filename
                )
            }
        }
    }
    
    // MARK: - View Sections
    
    private var weekSelectionSection: some View {
        Section {
            DatePicker("Week Start (Monday)", selection: $weekStartDate, displayedComponents: .date)
                .onChange(of: weekStartDate) { newValue in
                    // Adjust to Monday if needed
                    weekStartDate = getMondayOfWeek(for: newValue)
                }
        } header: {
            Text("Week Selection")
        } footer: {
            Text("Select any day of the week. The manifest will automatically generate for that week's Monday through Friday.")
        }
    }
    
    private var previewSection: some View {
        Section {
            listPreviewRow
            weekRangePreviewRow
            sessionsPreviewRow
            filenamePreviewRow
        } header: {
            Text("Preview")
        }
    }
    
    private var listPreviewRow: some View {
        HStack {
            Label("Route", systemImage: "list.bullet.clipboard")
                .foregroundColor(.orange)
            Spacer()
            Text(list.name)
                .foregroundColor(.secondary)
        }
    }
    
    private var weekRangePreviewRow: some View {
        HStack {
            Label("Week", systemImage: "calendar")
                .foregroundColor(.blue)
            Spacer()
            VStack(alignment: .trailing) {
                Text(TimestampFormatter.formatDateLong(mondayDate))
                    .font(.subheadline)
                Text("to \(TimestampFormatter.formatDateShort(fridayDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var sessionsPreviewRow: some View {
        HStack {
            Label("Sessions", systemImage: "clock.fill")
                .foregroundColor(.green)
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
            // DOWNLOAD REPORT Button
            Button(action: generateReport) {
                HStack {
                    Spacer()
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding(.trailing, 8)
                    }
                    Text(isGenerating ? "Generating..." : "SAVE REPORT")
                        .font(.headline)
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
            }
            .listRowBackground(Color.accentColor)
            .disabled(isGenerating)
            
            // EMAIL REPORT Button
            Button(action: emailReport) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .font(.title2)
                        Text("EMAIL REPORT")
                            .font(.headline)
                    }
                    Text("Send report to email")
                        .font(.caption)
                        .opacity(0.9)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 70)
            }
            .listRowBackground(Color(red: 76/255, green: 0/255, blue: 176/255))
            .disabled(isGenerating)
        }
    }
    
    private var emptyStateSection: some View {
        Group {
            if sessionsToExport.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("No sessions recorded yet for this week")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("The manifest will show blank cells for days without attendance records.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var mondayDate: Date {
        getMondayOfWeek(for: weekStartDate)
    }
    
    private var fridayDate: Date {
        Calendar.current.date(byAdding: .day, value: 4, to: mondayDate) ?? mondayDate
    }
    
    private var sessionsToExport: [AttendanceSession] {
        let allSessions = dataManager.fetchSessions(for: list)
        let start = Calendar.current.startOfDay(for: mondayDate)
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        return allSessions.filter { $0.createdDate >= start && $0.createdDate < end }
    }
    
    private var filename: String {
        CSVGenerator.generateManifestFilename(for: list, weekStartDate: mondayDate)
    }
    
    // MARK: - Helper Functions
    
    private func getMondayOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    // MARK: - Generate Report
    
    private func generateReport() {
        isGenerating = true
        
        // Small delay to show loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let csvContent = CSVGenerator.generateWeeklyManifest(
                for: sessionsToExport,
                list: list,
                weekStartDate: mondayDate,
                driverDetails: driverManager.driverDetails
            )
            
            // Validate CSV content
            guard !csvContent.isEmpty else {
                errorMessage = "Failed to generate manifest content."
                showErrorAlert = true
                isGenerating = false
                return
            }
            
            // Create document and show file exporter
            csvDocument = CSVDocument(content: csvContent, filename: filename)
            isGenerating = false
            showFileExporter = true
            
            print("✅ Weekly Manifest generated successfully")
            print("✅ File size: \(csvContent.count) characters")
            print("✅ Week: \(TimestampFormatter.formatDateLong(mondayDate)) - \(TimestampFormatter.formatDateShort(fridayDate))")
        }
    }
    
    // MARK: - File Export Handler
    
    private func handleFileExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("✅ Manifest successfully saved to: \(url)")
            showSuccessAlert = true
        case .failure(let error):
            errorMessage = "Failed to save manifest: \(error.localizedDescription)"
            showErrorAlert = true
            print("❌ Manifest export failed: \(error)")
        }
    }
    
    // MARK: - Email Report
    
    private func emailReport() {
        guard let driverEmail = driverManager.driverDetails?.email, !driverEmail.isEmpty else {
            errorMessage = "Driver email not found. Please complete driver setup first."
            showErrorAlert = true
            return
        }
        
        guard MFMailComposeViewController.canSendMail() else {
            errorMessage = "Mail services are not available on this device. Please configure the Mail app first."
            showErrorAlert = true
            return
        }
        
        isGenerating = true
        
        // Generate the CSV content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let csvContent = CSVGenerator.generateWeeklyManifest(
                for: sessionsToExport,
                list: list,
                weekStartDate: mondayDate,
                driverDetails: driverManager.driverDetails
            )
            
            // Validate CSV content
            guard !csvContent.isEmpty else {
                errorMessage = "Failed to generate manifest content."
                showErrorAlert = true
                isGenerating = false
                return
            }
            
            // Convert to Data
            guard let csvData = csvContent.data(using: .utf8) else {
                errorMessage = "Failed to prepare email attachment."
                showErrorAlert = true
                isGenerating = false
                return
            }
            
            // Set attachment data and show mail composer
            mailAttachmentData = csvData
            isGenerating = false
            showMailComposer = true
            
            print("✅ Email report prepared successfully")
            print("✅ Recipient: \(driverEmail)")
            print("✅ File size: \(csvData.count) bytes")
        }
    }
}

// MARK: - Mail Compose View (UIKit Wrapper)

struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    
    let recipientEmail: String
    let subject: String
    let body: String
    let attachmentData: Data?
    let attachmentFilename: String
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipientEmail])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        
        // Attach CSV file
        if let data = attachmentData {
            composer.addAttachmentData(data, mimeType: "text/csv", fileName: attachmentFilename)
        }
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            switch result {
            case .sent:
                print("✅ Email sent successfully")
            case .saved:
                print("📝 Email saved as draft")
            case .cancelled:
                print("❌ Email cancelled")
            case .failed:
                print("❌ Email failed: \(error?.localizedDescription ?? "Unknown error")")
            @unknown default:
                break
            }
            parent.dismiss()
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
    .environmentObject(DriverManager.shared)
}

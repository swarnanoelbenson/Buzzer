//
//  ReportGenerationView.swift
//  Buzzer
//

import SwiftUI
import UniformTypeIdentifiers

struct ReportGenerationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var driverManager: DriverManager

    let list: AttendeeList

    @State private var weekStartDate = Date()
    @State private var showFileExporter = false
    @State private var xlsxDocument: XLSXDocument?
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isGenerating = false

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
                    Button("Cancel") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: xlsxDocument,
                contentType: .xlsx,
                defaultFilename: xlsxDocument?.filename ?? "manifest.xlsx",
                onCompletion: handleFileExport
            )
            .alert("Export Successful", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Weekly manifest has been successfully created and saved.")
            }
            .alert("Export Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - View Sections

    private var weekSelectionSection: some View {
        Section {
            DatePicker("Week Start (Monday)", selection: $weekStartDate, displayedComponents: .date)
                .onChange(of: weekStartDate) { newValue in
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
            Label("Route", systemImage: "list.bullet.clipboard").foregroundColor(.orange)
            Spacer()
            Text(list.name).foregroundColor(.secondary)
        }
    }

    private var weekRangePreviewRow: some View {
        HStack {
            Label("Week", systemImage: "calendar").foregroundColor(.blue)
            Spacer()
            VStack(alignment: .trailing) {
                Text(TimestampFormatter.formatDateLong(mondayDate)).font(.subheadline)
                Text("to \(TimestampFormatter.formatDateShort(fridayDate))").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private var sessionsPreviewRow: some View {
        HStack {
            Label("Sessions", systemImage: "clock.fill").foregroundColor(.green)
            Spacer()
            Text("\(sessionsToExport.count)").foregroundColor(.secondary)
        }
    }

    private var filenamePreviewRow: some View {
        HStack {
            Label("File Name", systemImage: "doc.text").foregroundColor(.purple)
            Spacer()
            Text(filename).font(.caption).foregroundColor(.secondary).lineLimit(1)
        }
    }

    private var generateButtonSection: some View {
        Section {
            Button(action: generateReport) {
                HStack {
                    Spacer()
                    if isGenerating {
                        ProgressView().progressViewStyle(.circular).padding(.trailing, 8)
                    }
                    Text(isGenerating ? "Generating..." : "SAVE REPORT").font(.headline)
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
            }
            .listRowBackground(Color.accentColor)
            .disabled(isGenerating)
        }
    }

    private var emptyStateSection: some View {
        Group {
            if sessionsToExport.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark").font(.largeTitle).foregroundColor(.orange)
                        Text("No sessions recorded yet for this week").font(.subheadline).foregroundColor(.secondary)
                        Text("The manifest will show blank cells for days without attendance records.")
                            .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var mondayDate: Date { getMondayOfWeek(for: weekStartDate) }

    private var fridayDate: Date {
        Calendar.current.date(byAdding: .day, value: 4, to: mondayDate) ?? mondayDate
    }

    private var sessionsToExport: [AttendanceSession] {
        let completedSessions = dataManager.fetchCompletedSessions(for: list)
        let start = Calendar.current.startOfDay(for: mondayDate)
        let end   = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        return completedSessions.filter { $0.createdDate >= start && $0.createdDate < end }
    }

    private var filename: String {
        XLSXGenerator.generateManifestFilename(for: list, weekStartDate: mondayDate)
    }

    // MARK: - Helpers

    private func getMondayOfWeek(for date: Date) -> Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? date
    }

    // MARK: - Generate Report

    private func generateReport() {
        isGenerating = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let attendeeIDs = list.attendees.map { $0.id }
            let allNotes = PassengerNoteManager.shared.getNotes(for: attendeeIDs)
            let notes = allNotes.filter { $0.fromDate <= fridayDate && $0.toDate >= mondayDate }

            guard let fileURL = XLSXGenerator.generateWeeklyManifest(
                for: sessionsToExport,
                list: list,
                weekStartDate: mondayDate,
                driverDetails: driverManager.driverDetails,
                passengerNotes: notes
            ) else {
                errorMessage = "Failed to generate manifest."
                showErrorAlert = true
                isGenerating = false
                return
            }

            do {
                let data = try Data(contentsOf: fileURL)
                xlsxDocument = XLSXDocument(data: data, filename: filename)
                isGenerating = false
                showFileExporter = true
            } catch {
                errorMessage = "Failed to read generated file: \(error.localizedDescription)"
                showErrorAlert = true
                isGenerating = false
            }
        }
    }

    // MARK: - Export Handler

    private func handleFileExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("✅ Manifest saved to: \(url)")
            showSuccessAlert = true
        case .failure(let error):
            errorMessage = "Failed to save manifest: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}


#Preview {
    ReportGenerationView(list: AttendeeList(name: "Morning Route", attendees: [
        Attendee(name: "John Doe",   orderIndex: 0),
        Attendee(name: "Jane Smith", orderIndex: 1)
    ]))
    .environmentObject(DataManager())
    .environmentObject(DriverManager.shared)
}

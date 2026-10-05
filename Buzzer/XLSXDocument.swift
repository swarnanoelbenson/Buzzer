//
//  XLSXDocument.swift
//  Buzzer
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - XLSX Document (for fileExporter)

struct XLSXDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.xlsx] }

    let data: Data
    let filename: String

    init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
        self.filename = "report.xlsx"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - UTType extension for .xlsx

extension UTType {
    static let xlsx = UTType(filenameExtension: "xlsx") ?? .data
}

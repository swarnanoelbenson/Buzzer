//
//  AdminStudentsView.swift
//  Buzzer
//
//  Admin read-only view of students grouped by route.
//

import SwiftUI
import FirebaseFirestore

struct AdminStudentsView: View {
    @State private var routes: [Route] = []
    @State private var studentsByRoute: [String: [Student]] = [:]
    @State private var isLoading = true
    @State private var searchText = ""

    private let db = Firestore.db

    var filteredRoutes: [Route] {
        if searchText.isEmpty { return routes }
        return routes.filter { route in
            route.name.localizedCaseInsensitiveContains(searchText) ||
            (studentsByRoute[route.id ?? ""] ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if routes.isEmpty {
                    ContentUnavailableView("No Students", systemImage: "graduationcap", description: Text("Create a route with students first."))
                } else {
                    List {
                        ForEach(filteredRoutes) { route in
                            Section(route.name) {
                                let students = studentsByRoute[route.id ?? ""] ?? []
                                if students.isEmpty {
                                    Text("No students").font(.caption).foregroundStyle(.secondary)
                                } else {
                                    ForEach(students) { student in
                                        StudentRow(student: student)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Students")
            .searchable(text: $searchText, prompt: "Search by name or route")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        do {
            let routeSnap = try await db.collection("routes")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            let loadedRoutes = try routeSnap.documents.compactMap { try $0.data(as: Route.self) }

            var map: [String: [Student]] = [:]
            for route in loadedRoutes {
                guard let routeId = route.id, !route.studentIds.isEmpty else {
                    map[route.id ?? ""] = []
                    continue
                }
                // Firestore whereField:in supports max 30 items — chunk if needed
                var students: [Student] = []
                let chunks = stride(from: 0, to: route.studentIds.count, by: 30).map {
                    Array(route.studentIds[$0..<min($0+30, route.studentIds.count)])
                }
                for chunk in chunks {
                    let snap = try await db.collection("students")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                    students += snap.documents.compactMap { try? $0.data(as: Student.self) }
                }
                map[routeId] = students.sorted { $0.name < $1.name }
            }

            await MainActor.run {
                routes = loadedRoutes.sorted { $0.name < $1.name }
                studentsByRoute = map
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Student Row

private struct StudentRow: View {
    let student: Student

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(student.name).font(.subheadline).fontWeight(.semibold)
            HStack(spacing: 12) {
                Label("Grade \(student.grade)", systemImage: "graduationcap")
                Label(student.stopAddress, systemImage: "mappin")
            }
            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            HStack(spacing: 12) {
                Label(student.scheduledPickupTime, systemImage: "arrow.up.circle")
                Label(student.scheduledDropoffTime, systemImage: "arrow.down.circle")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

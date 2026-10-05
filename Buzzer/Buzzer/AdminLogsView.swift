//
//  AdminLogsView.swift
//  Buzzer
//
//  Admin view of the activity log.
//

import SwiftUI
import FirebaseFirestore

struct AdminLogsView: View {
    @State private var logs: [ActivityLog] = []
    @State private var isLoading = true
    @State private var filterRole: String = "All"

    private let db = Firestore.db
    private let roles = ["All", "driver", "parent", "student", "admin"]

    var filteredLogs: [ActivityLog] {
        if filterRole == "All" { return logs }
        return logs.filter { $0.actorRole == filterRole }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredLogs.isEmpty {
                    ContentUnavailableView("No Activity", systemImage: "list.bullet.clipboard", description: Text("No log entries found."))
                } else {
                    List(filteredLogs) { log in
                        LogRow(log: log)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Activity Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(roles, id: \.self) { role in
                            Button(role.capitalized) { filterRole = role }
                        }
                    } label: {
                        Label(filterRole == "All" ? "Filter" : filterRole.capitalized, systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        do {
            let snap = try await db.collection("activityLog")
                .order(by: "timestamp", descending: true)
                .limit(to: 200)
                .getDocuments()
            let loaded = try snap.documents.compactMap { try $0.data(as: ActivityLog.self) }
            await MainActor.run { logs = loaded; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Log Row

private struct LogRow: View {
    let log: ActivityLog

    var roleColor: Color {
        switch log.actorRole {
        case "driver":  return .blue
        case "parent":  return .orange
        case "student": return .indigo
        case "admin":   return .purple
        default:        return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.action)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(log.actorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(log.actorRole.capitalized)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(roleColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(roleColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            if let meta = log.metadata, !meta.isEmpty {
                Text(meta.map { "\($0.key): \($0.value)" }.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

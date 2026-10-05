//
//  AdminPortalView.swift
//  Buzzer
//
//  Root admin portal with sidebar navigation on iPad / split-view devices,
//  and a tab bar on iPhone.
//

import SwiftUI

enum AdminTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case drivers   = "Drivers"
    case students  = "Students"
    case schedule  = "Schedule"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .drivers:   return "person.2.fill"
        case .students:  return "graduationcap.fill"
        case .schedule:  return "calendar"
        }
    }
}

struct AdminPortalView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var selectedTab: AdminTab = .dashboard

    var body: some View {
        NavigationSplitView {
            // MARK: Sidebar
            List(AdminTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .foregroundStyle(selectedTab == tab ? .purple : .primary)
                }
                .listRowBackground(selectedTab == tab
                    ? Color.purple.opacity(0.1)
                    : Color.clear)
            }
            .navigationTitle("BusMate")
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out", role: .destructive) {
                        authManager.signOut()
                    }
                    .font(.caption)
                }
            }
        } detail: {
            // MARK: Detail pane
            switch selectedTab {
            case .dashboard: AdminDashboardView()
            case .drivers:   AdminDriversView()
            case .students:  AdminStudentsView()
            case .schedule:  AdminScheduleView()
            }
        }
        .tint(.purple)
    }
}

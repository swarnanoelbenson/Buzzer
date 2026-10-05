//
//  AdminPortalView.swift
//  Buzzer
//
//  Root admin portal with tab navigation.
//

import SwiftUI

struct AdminPortalView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        TabView {
            AdminDriversView()
                .tabItem { Label("Drivers", systemImage: "person.2.fill") }

            AdminScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }

            AdminStudentsView()
                .tabItem { Label("Students", systemImage: "graduationcap.fill") }

            AdminLogsView()
                .tabItem { Label("Logs", systemImage: "list.bullet.clipboard") }
        }
        .tint(.purple)
    }
}

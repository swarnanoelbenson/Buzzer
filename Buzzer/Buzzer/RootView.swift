//
//  RootView.swift
//  Buzzer
//
//  Routes the user to the correct portal based on their authenticated role.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                switch authManager.currentRole {
                case .none:
                    LoginSelectionView()
                case .driver:
                    DriverPortalView()
                case .parent:
                    ParentPortalView()
                case .student:
                    StudentPortalView()
                case .admin:
                    AdminPortalView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.currentRole)
    }
}

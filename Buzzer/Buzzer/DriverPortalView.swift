//
//  DriverPortalView.swift
//  Buzzer
//
//  Root view for the Driver portal. Contains Schedule and View All tabs.
//

import SwiftUI

struct DriverPortalView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab header
                HStack(spacing: 0) {
                    TabHeaderButton(title: "Schedule", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabHeaderButton(title: "View All", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                }
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

                // Content
                if selectedTab == 0 {
                    DriverScheduleView()
                } else {
                    DriverAllRoutesView()
                }
            }
            .navigationTitle("Buzzer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Tab Header Button

struct TabHeaderButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)

                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2)
            }
        }
    }
}



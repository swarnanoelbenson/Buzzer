//
//  LoginSelectionView.swift
//  Buzzer
//
//  First screen after splash. User selects whether they are a Bus Driver or a Parent.
//

import SwiftUI

struct LoginSelectionView: View {
    @State private var navigateToDriver = false
    @State private var navigateToParent = false
    @State private var showDevMenu = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Logo / App name
                VStack(spacing: 12) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)

                    Text("Buzzer")
                        .font(.system(size: 40, weight: .bold, design: .rounded))

                    Text("School Bus Management")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Role selection buttons
                VStack(spacing: 16) {
                    Text("Sign in as")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    NavigationLink(destination: DriverLoginView()) {
                        RoleButton(
                            icon: "steeringwheel",
                            title: "Bus Driver",
                            subtitle: "Access your routes and schedules",
                            color: .blue
                        )
                    }

                    NavigationLink(destination: ParentLoginView()) {
                        RoleButton(
                            icon: "person.2.fill",
                            title: "Parent",
                            subtitle: "Track your child's bus status",
                            color: .orange
                        )
                    }

                    NavigationLink(destination: StudentLoginView()) {
                        RoleButton(
                            icon: "graduationcap.fill",
                            title: "Student",
                            subtitle: "View your route and schedule",
                            color: .indigo
                        )
                    }

                    NavigationLink(destination: AdminLoginView()) {
                        RoleButton(
                            icon: "shield.lefthalf.filled",
                            title: "Admin",
                            subtitle: "Manage drivers, routes and students",
                            color: .purple
                        )
                    }
                }
                .padding(.horizontal, 24)

                // Developer menu — remove before App Store submission
                Button {
                    showDevMenu = true
                } label: {
                    Text("Developer Menu")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.bottom, 24)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showDevMenu) {
                DeveloperMenuView()
            }
        }
    }
}

// MARK: - Role Button

struct RoleButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

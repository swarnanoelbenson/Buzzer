//
//  AdminPortalView.swift
//  Buzzer
//
//  Custom collapsible sidebar layout for iPhone.
//  Sidebar slides in over the content; dashboard is shown by default with sidebar hidden.
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
    @State private var sidebarOpen = false
    @State private var showSignOutAlert = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {

                // MARK: - Main content
                VStack(spacing: 0) {
                    // Top navigation bar
                    ZStack {
                        // Centered tab title — must fill ZStack width to center correctly
                        Text("BusMate")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Leading / trailing buttons
                        HStack {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    sidebarOpen.toggle()
                                }
                            } label: {
                                Image(systemName: sidebarOpen ? "xmark" : "sidebar.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Spacer()

                            Button {
                                showSignOutAlert = true
                            } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .overlay(alignment: .bottom) {
                        Divider()
                    }

                    // Detail content
                    Group {
                        switch selectedTab {
                        case .dashboard: AdminDashboardView {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTab = .students
                            }
                        }
                        case .drivers:   AdminDriversView()
                        case .students:  AdminStudentsView()
                        case .schedule:  AdminScheduleView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // MARK: - Dim overlay
                if sidebarOpen {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sidebarOpen = false
                            }
                        }
                        .transition(.opacity)
                }

                // MARK: - Sidebar drawer
                if sidebarOpen {
                    SidebarDrawer(
                        selectedTab: $selectedTab,
                        sidebarOpen: $sidebarOpen,
                        screenWidth: geo.size.width
                    )
                    .transition(.move(edge: .leading))
                }
            }
        }
        .tint(.purple)
        .confirmationDialog("Sign Out", isPresented: $showSignOutAlert, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to verify your identity to sign back in.")
        }
    }
}

// MARK: - Sidebar Drawer

private struct SidebarDrawer: View {
    @Environment(AuthManager.self) private var authManager
    @Binding var selectedTab: AdminTab
    @Binding var sidebarOpen: Bool
    let screenWidth: CGFloat
    @State private var showSignOutAlert = false

    // Sidebar takes 72% of screen width, capped at 280pt
    private var drawerWidth: CGFloat { min(screenWidth * 0.72, 280) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Text("Admin Console")
                    .font(.title3)
                    .fontWeight(.black)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        sidebarOpen = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 16)

            // Nav items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(AdminTab.allCases) { tab in
                        SidebarNavItem(tab: tab, isSelected: selectedTab == tab) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTab = tab
                                sidebarOpen = false
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }

            Spacer()
            Divider()
                .padding(.horizontal, 16)

            // Sign out button
            Button {
                showSignOutAlert = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 22)
                    Text("Sign Out")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .confirmationDialog("Sign Out", isPresented: $showSignOutAlert, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will need to verify your identity to sign back in.")
            }
        }
        .frame(width: drawerWidth)
        .frame(maxHeight: .infinity)
        .background(Color(.systemBackground))
        .clipShape(
            .rect(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 20, topTrailingRadius: 20)
        )
        .shadow(color: .black.opacity(0.18), radius: 20, x: 4, y: 0)
    }
}

// MARK: - Sidebar Nav Item

private struct SidebarNavItem: View {
    let tab: AdminTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .purple : .secondary)
                    .frame(width: 22)
                Text(tab.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? .purple : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.purple.opacity(0.6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.purple.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

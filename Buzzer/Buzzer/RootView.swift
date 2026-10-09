//
//  RootView.swift
//  Buzzer
//
//  Routes the user to the correct portal based on their authenticated role.
//  Also manages the biometric lock gate — whenever the app returns to the
//  foreground with an active session, the user must re-verify via Face ID /
//  Touch ID / passcode before portal content is shown.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppLockManager.self) private var lockManager
    @Environment(\.scenePhase) private var scenePhase

    private var hasActiveSession: Bool {
        authManager.currentRole != .none
    }

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
        // Show the lock screen overlay whenever there's an active session
        // but the app hasn't been biometrically unlocked yet.
        .overlay {
            if hasActiveSession && !lockManager.isUnlocked {
                AppLockView()
                    .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // App came to foreground — prompt if a session exists and is locked.
                if hasActiveSession && !lockManager.isUnlocked {
                    Task { await lockManager.authenticate() }
                }
            case .background:
                // Lock immediately when the app goes to the background.
                if hasActiveSession {
                    lockManager.lock()
                }
            default:
                break
            }
        }
        // On first appearance: lock so the foreground transition triggers a prompt.
        .task {
            if hasActiveSession {
                lockManager.lock()
                await lockManager.authenticate()
            }
        }
        // Track role changes: unlock on fresh sign-in, lock on sign-out.
        .onChange(of: authManager.currentRole) { oldRole, newRole in
            if newRole == .none {
                // Sign-out — lock so the next session requires re-auth.
                lockManager.isUnlocked = false
            } else if oldRole == .none {
                // Fresh sign-in — user just authenticated; no lock needed.
                lockManager.isUnlocked = true
            }
        }
    }
}

// MARK: - Lock Screen

private struct AppLockView: View {
    @Environment(AppLockManager.self) private var lockManager

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("BusMate")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Verify your identity to continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await lockManager.authenticate() }
                } label: {
                    Label("Unlock", systemImage: "faceid")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(40)
        }
    }
}

//
//  AppLockManager.swift
//  Buzzer
//
//  Manages the biometric lock that gates portal access whenever the app
//  returns to the foreground with an active session.
//
//  Behaviour:
//  - On cold launch with a cached Firebase session → prompt immediately.
//  - On foreground return (from background) → prompt immediately.
//  - If biometrics are unavailable (no Face ID / Touch ID enrolled) → always unlocked.
//  - The Firebase session is never affected — the user stays logged in;
//    they only need to re-verify their identity.
//

import SwiftUI
import LocalAuthentication
import Observation

@Observable
@MainActor
final class AppLockManager {

    /// Whether the portal content is currently visible to the user.
    var isUnlocked: Bool = false

    /// Set to true while a biometric prompt is in-flight (prevents duplicate prompts).
    private var isPrompting: Bool = false

    // MARK: - Public API

    /// Triggers a biometric prompt. Unlocks on success; keeps locked on failure.
    /// Safe to call multiple times — concurrent calls are ignored.
    func authenticate() async {
        // Simulator has no biometrics or passcode — unlock automatically for development.
        #if targetEnvironment(simulator)
        isUnlocked = true
        return
        #endif

        guard !isPrompting else { return }

        let context = LAContext()
        var error: NSError?

        // Check if biometrics (or device passcode) are available.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics AND no passcode set — unlock automatically.
            isUnlocked = true
            return
        }

        isPrompting = true
        defer { isPrompting = false }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Verify your identity to access BusMate"
            )
            isUnlocked = success
        } catch {
            // User cancelled or failed — remain locked.
            isUnlocked = false
        }
    }

    /// Called when the app moves to the background or when the user signs out.
    /// Locks the screen so the next foreground restore requires re-auth.
    func lock() {
        isUnlocked = false
    }
}

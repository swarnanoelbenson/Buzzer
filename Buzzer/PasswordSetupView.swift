//
//  PasswordSetupView.swift
//  Buzzer
//
//  First-time password setup and forgot-password flow for Driver, Parent, and Student portals.
//  Steps:
//    1. Email pre-filled, tap "Send Code" → WAC sends 6-char alphanumeric code via email
//    2. Enter the code to verify identity
//    3. Enter and confirm new password
//    4. signUp (or signIn + updatePassword) → FirestoreService.setPasswordSet → AuthManager resolves role
//

import SwiftUI
import FirebaseAuth

private let setupCodeEndpoint = "https://busmate-admin.vercel.app/api/auth/send-setup-code"
private let verifyCodeEndpoint = "https://busmate-admin.vercel.app/api/auth/verify-setup-code"

struct PasswordSetupView: View {
    let email: String
    let schoolId: String
    let role: UserRole
    let accentColor: Color

    @Environment(AuthManager.self) private var authManager
    private let service = FirestoreService.shared

    // Step tracking
    @State private var step: SetupStep = .sendCode

    // Step 2 — code entry
    @State private var code = ""
    @State private var verifiedDocId = ""
    @State private var verifyCustomToken: String? = nil   // returned by verify-setup-code for existing accounts
    @State private var needsSignUp = false                // true when no Firebase Auth account yet

    // Step 3 — password entry
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false

    // UI
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    enum SetupStep {
        case sendCode
        case enterCode
        case setPassword
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(accentColor)
                    Text("Set Up Your Password")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Step indicator
                StepIndicator(currentStep: step, accentColor: accentColor)
                    .padding(.horizontal, 24)

                switch step {
                case .sendCode:
                    sendCodeSection
                case .enterCode:
                    enterCodeSection
                case .setPassword:
                    setPasswordSection
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Step 1: Send Code

    private var sendCodeSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("We'll send a 6-character verification code to your email address to confirm your identity.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await handleSendCode() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send Verification Code")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(accentColor)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isLoading)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 2: Enter Code

    private var enterCodeSection: some View {
        VStack(spacing: 20) {
            Text("Enter the 6-character code sent to **\(email)**")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField("e.g. A3K9MZ", text: $code)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .onChange(of: code) { _, newValue in
                    code = String(newValue.uppercased().prefix(6))
                }

            if let success = successMessage {
                Text(success)
                    .foregroundColor(.green)
                    .font(.caption)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await handleVerifyCode() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Verify Code")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(code.count == 6 ? accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(code.count < 6 || isLoading)

            Button("Resend code") {
                Task { await handleSendCode() }
            }
            .font(.subheadline)
            .foregroundColor(accentColor)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 3: Set Password

    private var setPasswordSection: some View {
        VStack(spacing: 20) {
            Text("Choose a password for your BusMate account.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // New password
            VStack(alignment: .leading, spacing: 8) {
                Label("New Password", systemImage: "lock.fill")
                    .font(.headline)

                HStack {
                    Group {
                        if showNewPassword {
                            TextField("At least 8 characters", text: $newPassword)
                        } else {
                            SecureField("At least 8 characters", text: $newPassword)
                        }
                    }
                    .textContentType(.newPassword)
                    .padding(.leading)

                    Button {
                        showNewPassword.toggle()
                    } label: {
                        Image(systemName: showNewPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                            .padding(.trailing)
                    }
                }
                .frame(height: 50)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }

            // Confirm password
            VStack(alignment: .leading, spacing: 8) {
                Label("Confirm Password", systemImage: "lock.fill")
                    .font(.headline)

                HStack {
                    Group {
                        if showConfirmPassword {
                            TextField("Re-enter your password", text: $confirmPassword)
                        } else {
                            SecureField("Re-enter your password", text: $confirmPassword)
                        }
                    }
                    .textContentType(.newPassword)
                    .padding(.leading)

                    Button {
                        showConfirmPassword.toggle()
                    } label: {
                        Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                            .padding(.trailing)
                    }
                }
                .frame(height: 50)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                if !confirmPassword.isEmpty && newPassword != confirmPassword {
                    Text("Passwords do not match.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await handleSetPassword() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Set Password & Sign In")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSetPassword ? accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(!canSetPassword || isLoading)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Computed

    private var canSetPassword: Bool {
        newPassword.count >= 8 && newPassword == confirmPassword
    }

    // MARK: - Actions

    private func handleSendCode() async {
        errorMessage = nil
        isLoading = true

        do {
            guard let url = URL(string: setupCodeEndpoint) else { throw URLError(.badURL) }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: [
                "email": email,
                "schoolId": schoolId
            ])
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                throw NSError(domain: "Setup", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: json?["error"] as? String ?? "Failed to send code."
                ])
            }
            successMessage = "Code sent to \(email)"
            step = .enterCode
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleVerifyCode() async {
        errorMessage = nil
        isLoading = true

        do {
            guard let url = URL(string: verifyCodeEndpoint) else { throw URLError(.badURL) }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: [
                "email": email,
                "schoolId": schoolId,
                "code": code
            ])
            let (data, response) = try await URLSession.shared.data(for: req)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard statusCode == 200, let result = json else {
                throw NSError(domain: "Setup", code: statusCode, userInfo: [
                    NSLocalizedDescriptionKey: json?["error"] as? String ?? "Verification failed."
                ])
            }

            verifiedDocId = result["firestoreDocId"] as? String ?? ""
            needsSignUp = result["needsSignUp"] as? Bool ?? true
            verifyCustomToken = result["customToken"] as? String
            step = .setPassword
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleSetPassword() async {
        errorMessage = nil
        isLoading = true

        do {
            if needsSignUp {
                // No Firebase Auth account yet — create one with the chosen password
                try await authManager.signUpWithEmailPassword(email: email, password: newPassword)
            } else if let token = verifyCustomToken {
                // Existing Firebase Auth account — sign in via custom token, then update password
                try await authManager.signInWithCustomToken(token)
                try await authManager.updatePassword(newPassword)
            } else {
                throw NSError(domain: "Setup", code: 500, userInfo: [NSLocalizedDescriptionKey: "Verification data missing. Please start over."])
            }

            // Mark passwordSet = true in Firestore
            if !verifiedDocId.isEmpty {
                try await service.setPasswordSet(verifiedDocId, role: role)
            }
            // AuthManager auth state listener will fire and resolve the role → navigate to dashboard
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Step Indicator

private struct StepIndicator: View {
    let currentStep: PasswordSetupView.SetupStep
    let accentColor: Color

    var body: some View {
        HStack(spacing: 0) {
            stepDot(label: "Send Code", isActive: currentStep == .sendCode, isDone: currentStep != .sendCode)
            stepLine(isDone: currentStep != .sendCode)
            stepDot(label: "Verify", isActive: currentStep == .enterCode, isDone: currentStep == .setPassword)
            stepLine(isDone: currentStep == .setPassword)
            stepDot(label: "Password", isActive: currentStep == .setPassword, isDone: false)
        }
    }

    private func stepDot(label: String, isActive: Bool, isDone: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isDone ? accentColor : (isActive ? accentColor.opacity(0.2) : Color(.systemFill)))
                    .frame(width: 28, height: 28)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(isActive ? accentColor : Color.secondary.opacity(0.4))
                        .frame(width: 10, height: 10)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isActive || isDone ? accentColor : .secondary)
        }
    }

    private func stepLine(isDone: Bool) -> some View {
        Rectangle()
            .fill(isDone ? accentColor : Color(.systemFill))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
    }
}

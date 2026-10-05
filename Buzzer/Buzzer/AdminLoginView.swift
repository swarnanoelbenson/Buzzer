//
//  AdminLoginView.swift
//  Buzzer
//
//  Admin login flow:
//  Real device  — enter email → WAC sends magic link via Resend → admin taps link
//                 in Mail → Universal Link opens app → BuzzerApp handles the URL →
//                 calls /api/admin-signin-link/verify → signs in with custom token.
//  Simulator    — enter email → WAC sends 6-digit OTP via Resend → enter code →
//                 calls /api/admin-otp/verify → signs in with custom token.
//

import SwiftUI

private let sendLinkURL  = "https://busmate-admin.vercel.app/api/admin-signin-link/send"
private let sendOtpURL   = "https://busmate-admin.vercel.app/api/admin-otp/send"
private let verifyOtpURL = "https://busmate-admin.vercel.app/api/admin-otp/verify"

struct AdminLoginView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    // Magic link state (real device)
    @State private var linkSent = false

    // OTP fallback state (simulator)
    @State private var otpStep = false
    @State private var otp = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 44))
                            .foregroundStyle(.purple)

                        #if targetEnvironment(simulator)
                        Text(otpStep ? "Enter Code" : "Admin Sign In")
                            .font(.title2).fontWeight(.black)
                        Text(otpStep
                             ? "A 6-digit code was sent to\n\(email)"
                             : "Enter your admin email address")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        #else
                        Text(linkSent ? "Check Your Email" : "Admin Sign In")
                            .font(.title2).fontWeight(.black)
                        Text(linkSent
                             ? "A sign-in link was sent to\n\(email)\n\nTap the link to open the app and sign in."
                             : "Enter your admin email address")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        #endif
                    }
                    .padding(.top, 48)
                    .padding(.bottom, 36)

                    // Fields
                    VStack(spacing: 16) {
                        #if targetEnvironment(simulator)
                        if !otpStep {
                            emailField
                        } else {
                            otpField
                        }
                        #else
                        if !linkSent {
                            emailField
                        }
                        #endif

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        #if targetEnvironment(simulator)
                        actionButton
                        #else
                        if !linkSent {
                            sendLinkButton
                        } else {
                            resendButton
                        }
                        #endif
                    }
                    .padding(.horizontal, 24)

                    // Back button
                    #if targetEnvironment(simulator)
                    if otpStep {
                        backButton(label: "Use a different email") {
                            otpStep = false; otp = ""; errorMessage = ""
                        }
                    }
                    #else
                    if linkSent {
                        backButton(label: "Use a different email") {
                            linkSent = false; errorMessage = ""
                        }
                    }
                    #endif

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sub-views

    private var emailField: some View {
        TextField("admin@school.edu.au", text: $email)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .textContentType(.emailAddress)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
    }

    private var otpField: some View {
        TextField("6-digit code", text: $otp)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .onChange(of: otp) { _, new in if new.count > 6 { otp = String(new.prefix(6)) } }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .multilineTextAlignment(.center)
            .font(.title2.monospacedDigit())
            .tracking(8)
    }

    // Simulator: send OTP → verify OTP button
    private var actionButton: some View {
        Button(action: otpStep ? verifyOtp : sendOtp) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.purple)
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(otpStep ? "Sign In" : "Send Code")
                        .font(.headline).foregroundStyle(.white)
                }
            }
            .frame(height: 52)
        }
        .disabled(isLoading || (otpStep ? otp.count < 6 : email.trimmingCharacters(in: .whitespaces).isEmpty))
    }

    // Real device: send magic link button
    private var sendLinkButton: some View {
        Button(action: sendMagicLink) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.purple)
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Send Sign-In Link")
                        .font(.headline).foregroundStyle(.white)
                }
            }
            .frame(height: 52)
        }
        .disabled(isLoading || email.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // Real device: resend button shown after link is sent
    private var resendButton: some View {
        Button(action: sendMagicLink) {
            Text(isLoading ? "Sending..." : "Resend link")
                .font(.subheadline)
                .foregroundStyle(.purple)
        }
        .disabled(isLoading)
    }

    private func backButton(label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 20)
    }

    // MARK: - Actions (real device)

    private func sendMagicLink() {
        isLoading = true
        errorMessage = ""
        let normalised = email.trimmingCharacters(in: .whitespaces).lowercased()

        Task {
            do {
                guard let url = URL(string: sendLinkURL) else { throw URLError(.badURL) }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: [
                    "email": normalised,
                    "source": "ios"
                ])

                let (data, response) = try await URLSession.shared.data(for: req)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0

                if status == 200 {
                    await MainActor.run { isLoading = false; linkSent = true }
                } else {
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let msg = json?["error"] as? String ?? "Failed to send sign-in link."
                    await MainActor.run { isLoading = false; errorMessage = msg }
                }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = "Network error. Please try again." }
            }
        }
    }

    // MARK: - Actions (simulator OTP fallback)

    private func sendOtp() {
        isLoading = true
        errorMessage = ""
        let normalised = email.trimmingCharacters(in: .whitespaces).lowercased()

        Task {
            do {
                guard let url = URL(string: sendOtpURL) else { throw URLError(.badURL) }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["email": normalised])

                let (data, response) = try await URLSession.shared.data(for: req)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0

                if status == 200 {
                    await MainActor.run { isLoading = false; otpStep = true }
                } else {
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let msg = json?["error"] as? String ?? "Failed to send code."
                    await MainActor.run { isLoading = false; errorMessage = msg }
                }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = "Network error. Please try again." }
            }
        }
    }

    private func verifyOtp() {
        isLoading = true
        errorMessage = ""
        let normalised = email.trimmingCharacters(in: .whitespaces).lowercased()

        Task {
            do {
                guard let url = URL(string: verifyOtpURL) else { throw URLError(.badURL) }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["email": normalised, "otp": otp])

                let (data, response) = try await URLSession.shared.data(for: req)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0

                if status == 200 {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    guard let customToken = json?["customToken"] as? String else {
                        await MainActor.run { isLoading = false; errorMessage = "Invalid response from server." }
                        return
                    }
                    try await authManager.signInWithCustomToken(customToken)
                    await MainActor.run { isLoading = false }
                } else {
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let msg = json?["error"] as? String ?? "Verification failed."
                    await MainActor.run { isLoading = false; errorMessage = msg }
                }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = "Network error. Please try again." }
            }
        }
    }
}

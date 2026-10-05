//
//  AdminLoginView.swift
//  Buzzer
//
//  Email OTP login for admin role.
//  Step 1: enter email → API sends 6-digit code via Resend
//  Step 2: enter code → API verifies and returns Firebase custom token → sign in
//

import SwiftUI

private let otpSendURL    = "https://busmate-admin.vercel.app/api/admin-otp/send"
private let otpVerifyURL  = "https://busmate-admin.vercel.app/api/admin-otp/verify"

struct AdminLoginView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    // Step 1
    @State private var email = ""
    @State private var step = 1
    @State private var schoolName = ""

    // Step 2
    @State private var otp = ""

    @State private var isLoading = false
    @State private var errorMessage = ""

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
                        Text(step == 1 ? "Admin Sign In" : "Enter Code")
                            .font(.title2).fontWeight(.black)
                        Text(step == 1
                             ? "Enter your admin email address"
                             : "A 6-digit code was sent to\n\(email)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 48)
                    .padding(.bottom, 36)

                    // Fields
                    VStack(spacing: 16) {
                        if step == 1 {
                            emailField
                        } else {
                            otpField
                        }

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        actionButton
                    }
                    .padding(.horizontal, 24)

                    if step == 2 {
                        Button("Use a different email") {
                            otp = ""
                            errorMessage = ""
                            step = 1
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                    }

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

    private var actionButton: some View {
        Button(action: step == 1 ? sendOtp : verifyOtp) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.purple)
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(step == 1 ? "Send Code" : "Sign In")
                        .font(.headline).foregroundStyle(.white)
                }
            }
            .frame(height: 52)
        }
        .disabled(isLoading || (step == 1 ? email.trimmingCharacters(in: .whitespaces).isEmpty : otp.count < 6))
    }

    // MARK: - Actions

    private func sendOtp() {
        isLoading = true
        errorMessage = ""
        let normalised = email.trimmingCharacters(in: .whitespaces).lowercased()

        Task {
            do {
                guard let url = URL(string: otpSendURL) else { throw URLError(.badURL) }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["email": normalised])

                let (data, response) = try await URLSession.shared.data(for: req)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0

                if status == 200 {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    schoolName = json?["schoolName"] as? String ?? ""
                    await MainActor.run {
                        isLoading = false
                        step = 2
                    }
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
                guard let url = URL(string: otpVerifyURL) else { throw URLError(.badURL) }
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

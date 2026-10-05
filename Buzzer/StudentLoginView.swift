//
//  StudentLoginView.swift
//  Buzzer
//
//  Student login via phone number + SMS OTP.
//  The admin registers the student's phone when creating their profile.
//  Firebase Phone Auth sends the OTP; we verify the phone exists in Firestore
//  before sending so students can't log in with unregistered numbers.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct StudentLoginView: View {
    @Environment(AuthManager.self) private var authManager

    // Step 1
    @State private var phoneNumber: String = ""

    // Step 2 (OTP)
    @State private var verificationID: String? = nil
    @State private var otpCode: String = ""
    @State private var isOTPSent = false

    // UI
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private let service = FirestoreService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.indigo)
                    Text("Student Login")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Enter the phone number registered with your school")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                if !isOTPSent {
                    // MARK: Step 1 — Phone number
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Phone Number", systemImage: "phone.fill")
                                .font(.headline)

                            TextField("e.g. 0412 345 678", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)

                            Text("Enter the number registered by your school.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await handleSendOTP() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Send OTP")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSendOTP ? Color.indigo : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(!canSendOTP || isLoading)
                    }
                    .padding(.horizontal, 24)

                } else {
                    // MARK: Step 2 — OTP entry
                    VStack(spacing: 20) {
                        Text("Enter the OTP sent to your phone")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        TextField("6-digit OTP", text: $otpCode)
                            .keyboardType(.numberPad)
                            .font(.system(size: 24, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .onChange(of: otpCode) { _, newValue in
                                if newValue.count > 6 { otpCode = String(newValue.prefix(6)) }
                            }

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }

                        Button {
                            Task { await handleVerifyOTP() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Verify & Login")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(otpCode.count == 6 ? Color.indigo : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(otpCode.count < 6 || isLoading)

                        Button("Use a different number") {
                            isOTPSent = false
                            otpCode = ""
                            verificationID = nil
                            errorMessage = nil
                        }
                        .font(.subheadline)
                        .foregroundColor(.indigo)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed

    private var canSendOTP: Bool {
        phoneNumber.filter(\.isNumber).count >= 8
    }

    // MARK: - Actions

    private func handleSendOTP() async {
        errorMessage = nil
        isLoading = true

        do {
            // Verify this phone exists in the students collection first
            let student = try await service.fetchStudentByPhone(phoneNumber)
            guard let storedPhone = student.phone, !storedPhone.isEmpty else {
                errorMessage = "No phone number on record. Contact the school office."
                isLoading = false
                return
            }

            // Normalise to international format for Firebase
            let normalised = normalisePhone(storedPhone)

            #if targetEnvironment(simulator)
            verificationID = "SIMULATOR_BYPASS"
            isOTPSent = true
            #else
            let vid = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask { try await self.authManager.sendOTP(to: normalised) }
                group.addTask {
                    try await Task.sleep(for: .seconds(15))
                    throw NSError(domain: "OTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "OTP request timed out. Check your network."])
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            verificationID = vid
            isOTPSent = true
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleVerifyOTP() async {
        guard let vid = verificationID else { return }
        errorMessage = nil
        isLoading = true

        #if targetEnvironment(simulator)
        if vid == "SIMULATOR_BYPASS" {
            do {
                let student = try await service.fetchStudentByPhone(phoneNumber)
                let sid = student.id ?? "unknown"
                let email = "\(sid)@buzzer-student.app"
                do {
                    try await authManager.signInStudent(email: email, password: "student-sim-bypass")
                } catch {
                    _ = try? await Auth.auth().createUser(withEmail: email, password: "student-sim-bypass")
                    // Write a students doc so AuthManager resolves the role correctly
                    try? await Firestore.db.collection("students").document(
                        Auth.auth().currentUser?.uid ?? ""
                    ).setData(["simulatorBypass": true, "linkedStudentId": sid], merge: true)
                    try? await authManager.signInStudent(email: email, password: "student-sim-bypass")
                }
            } catch {
                errorMessage = "Simulator login failed: \(error.localizedDescription)"
            }
            isLoading = false
            return
        }
        #endif

        do {
            try await authManager.verifyOTP(verificationID: vid, code: otpCode)
        } catch {
            errorMessage = "Invalid OTP. Please try again."
        }
        isLoading = false
    }

    // MARK: - Helpers

    /// Normalises an Australian phone number to E.164 format (+61...).
    private func normalisePhone(_ phone: String) -> String {
        let digits = phone.filter(\.isNumber)
        if digits.hasPrefix("61") { return "+\(digits)" }
        if digits.hasPrefix("0") { return "+61\(digits.dropFirst())" }
        return "+61\(digits)"
    }
}

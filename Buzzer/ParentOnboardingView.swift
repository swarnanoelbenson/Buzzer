//
//  ParentOnboardingView.swift
//  Buzzer
//
//  First-login onboarding flow for parents.
//  Step 1: Preview child/children info (read-only).
//  Step 2: Change password from the school-issued one.
//  On completion: sets profileCompleted = true in Firestore, then calls onComplete.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ParentOnboardingView: View {
    let onComplete: () -> Void

    @Environment(AuthManager.self) private var authManager

    @State private var step: OnboardingStep = .loading
    @State private var parent: Parent? = nil
    @State private var children: [Student] = []
    @State private var errorMessage: String? = nil

    private let service = FirestoreService.shared

    enum OnboardingStep {
        case loading
        case childPreview
        case passwordChange
    }

    var body: some View {
        Group {
            switch step {
            case .loading:
                ProgressView("Setting up your account...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .childPreview:
                ChildPreviewStep(
                    parent: parent,
                    children: children,
                    onContinue: { step = .passwordChange }
                )

            case .passwordChange:
                PasswordChangeStep(
                    onComplete: { await finishOnboarding() }
                )
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let uid = authManager.currentUserId else { return }

        do {
            let parentDoc = try await service.fetchParent(id: uid)
            parent = parentDoc
            children = try await service.fetchStudents(for: uid, childIds: parentDoc.childIds)
            step = .childPreview
        } catch {
            // If fetch fails, skip to password change
            step = .passwordChange
        }
    }

    // MARK: - Complete Onboarding

    private func finishOnboarding() async {
        guard let uid = authManager.currentUserId else { return }
        // Mark profile as completed in Firestore
        try? await Firestore.db.collection("parents").document(uid).updateData([
            "profileCompleted": true
        ])
        onComplete()
    }
}

// MARK: - Step 1: Child Preview

private struct ChildPreviewStep: View {
    let parent: Parent?
    let children: [Student]
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome header
                    VStack(spacing: 10) {
                        Image(systemName: "hand.wave.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.orange)

                        Text("Welcome\(parent.map { ", \($0.name.components(separatedBy: " ").first ?? $0.name)" } ?? "")!")
                            .font(.system(size: 26, weight: .bold, design: .rounded))

                        Text("Here's a preview of your linked children. Check the details are correct before continuing.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 32)

                    // Children cards
                    if children.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No children linked yet.")
                                .font(.headline)
                            Text("Contact your school admin to link your children.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(children) { child in
                                OnboardingChildCard(child: child)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Info note
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("If any details look incorrect, contact your school after completing setup.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 24)

                    // Continue button
                    Button(action: onContinue) {
                        Text("Looks Good — Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Your Account")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Onboarding Child Card

private struct OnboardingChildCard: View {
    let child: Student

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(child.name.prefix(1)))
                            .font(.headline.bold())
                            .foregroundColor(.orange)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(child.name)
                        .font(.headline)
                    Text("Grade \(child.grade)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 6) {
                infoRow(icon: "arrow.up.circle.fill", color: .green, label: "Pick-up", value: child.scheduledPickupTime)
                infoRow(icon: "arrow.down.circle.fill", color: .orange, label: "Drop-off", value: child.scheduledDropoffTime)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func infoRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Step 2: Password Change

private struct PasswordChangeStep: View {
    let onComplete: () async -> Void

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showNew = false
    @State private var showConfirm = false
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private var passwordsMatch: Bool { newPassword == confirmPassword }
    private var isValid: Bool { newPassword.count >= 8 && passwordsMatch }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 52))
                            .foregroundColor(.orange)

                        Text("Set Your Password")
                            .font(.system(size: 26, weight: .bold, design: .rounded))

                        Text("Create a new password for your account. Your school-issued password will no longer work after this step.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 32)

                    VStack(spacing: 16) {
                        // New password
                        VStack(alignment: .leading, spacing: 8) {
                            Label("New Password", systemImage: "lock.fill")
                                .font(.headline)

                            HStack {
                                if showNew {
                                    TextField("At least 8 characters", text: $newPassword)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("At least 8 characters", text: $newPassword)
                                }
                                Button { showNew.toggle() } label: {
                                    Image(systemName: showNew ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }

                        // Confirm password
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Confirm Password", systemImage: "lock.fill")
                                .font(.headline)

                            HStack {
                                if showConfirm {
                                    TextField("Re-enter your password", text: $confirmPassword)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Re-enter your password", text: $confirmPassword)
                                }
                                Button { showConfirm.toggle() } label: {
                                    Image(systemName: showConfirm ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)

                            // Match indicator
                            if !confirmPassword.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    Text(passwordsMatch ? "Passwords match" : "Passwords do not match")
                                        .font(.caption)
                                }
                                .foregroundColor(passwordsMatch ? .green : .red)
                            }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Save button
                        Button {
                            Task { await handleSave() }
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Set Password & Continue")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isValid ? Color.orange : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(!isValid || isSaving)

                        // Requirements note
                        Text("Password must be at least 8 characters long.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Set Password")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func handleSave() async {
        isSaving = true
        errorMessage = nil

        do {
            guard let user = Auth.auth().currentUser else {
                throw NSError(domain: "Onboarding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
            }
            try await user.updatePassword(to: newPassword)
            await onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

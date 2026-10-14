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
                    onContinue: { await finishOnboarding() }
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
            step = .childPreview
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
    let onContinue: () async -> Void

    @State private var isFinishing = false

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
                    Button {
                        Task {
                            isFinishing = true
                            await onContinue()
                            isFinishing = false
                        }
                    } label: {
                        Group {
                            if isFinishing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Go to Dashboard")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isFinishing)
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



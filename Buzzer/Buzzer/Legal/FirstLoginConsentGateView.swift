// FirstLoginConsentGateView.swift
// BusMate
//
// Full-screen consent gate shown on every portal's first login.
// The user cannot access the portal until they accept the Terms of Service
// and Privacy Policy. Acceptance is written to Firestore (consent_records/{userId})
// so it is recorded once and never shown again to the same user.

import SwiftUI

// MARK: - FirstLoginConsentGateView

struct FirstLoginConsentGateView: View {

    @Environment(AuthManager.self) private var authManager

    @State private var isAccepted = false
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var presenter = LegalDocumentPresenter()

    private let service = FirestoreService.shared

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.blue)

                    Text("Before you continue")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Please review and accept our Terms of Service and Privacy Policy to use BusMate.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
                .padding(.top, 60)
                .padding(.bottom, 32)

                Divider()

                // Document links
                VStack(spacing: 0) {
                    documentRow(document: .termsOfService)
                    Divider().padding(.leading, 52)
                    documentRow(document: .privacyPolicy)
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // Acceptance toggle
                HStack(alignment: .top, spacing: 12) {
                    Toggle("", isOn: $isAccepted)
                        .labelsHidden()
                        .toggleStyle(.checkmark)
                        .accessibilityLabel("Accept terms and privacy policy")
                        .accessibilityHint(
                            isAccepted
                            ? "Checked. Tap to uncheck."
                            : "Unchecked. Tap to accept the Terms of Service and Privacy Policy."
                        )
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Group {
                            Text("I agree to the ")
                                .foregroundStyle(.primary)
                            + Text("Terms of Service")
                                .foregroundStyle(Color.accentColor)
                                .underline()
                            + Text(" and acknowledge that I have read the ")
                                .foregroundStyle(.primary)
                            + Text("Privacy Policy")
                                .foregroundStyle(Color.accentColor)
                                .underline()
                            + Text(".")
                                .foregroundStyle(.primary)
                        }
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay(
                            HStack {
                                legalLinkButton(for: .termsOfService)
                                legalLinkButton(for: .privacyPolicy)
                            }
                            .opacity(0),
                            alignment: .leading
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "I agree to the Terms of Service and acknowledge that I have read the Privacy Policy. " +
                            "Use the Terms of Service and Privacy Policy buttons to read each document."
                        )
                        .accessibilityAction(named: "Open Terms of Service") {
                            presenter.open(.termsOfService)
                        }
                        .accessibilityAction(named: "Open Privacy Policy") {
                            presenter.open(.privacyPolicy)
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                // Continue button
                Button {
                    guard isAccepted else { return }
                    Task { await acceptAndContinue() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("Continue to BusMate")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isAccepted || isSaving)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .accessibilityLabel(
                    isAccepted
                    ? "Continue to BusMate"
                    : "Continue to BusMate — disabled until you accept the Terms of Service and Privacy Policy"
                )
            }
        }
        .legalSheet(item: $presenter.activeDocument)
    }

    // MARK: Private Helpers

    private func documentRow(document: LegalDocument) -> some View {
        Button {
            presenter.open(document)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: document == .termsOfService ? "doc.text" : "hand.raised")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("Version \(document.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func legalLinkButton(for document: LegalDocument) -> some View {
        Button {
            presenter.open(document)
        } label: {
            Text(document.title)
        }
        .accessibilityLabel(document.accessibilityLabel)
    }

    private func acceptAndContinue() async {
        guard isAccepted, let userId = authManager.currentUserId else { return }
        isSaving = true
        errorMessage = nil
        do {
            let record = ConsentRecord.makeAccepted()
            try await service.recordConsent(record, userId: userId)
            authManager.markConsentRecorded()
        } catch {
            errorMessage = "Failed to save your acceptance. Please check your connection and try again."
            isSaving = false
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    FirstLoginConsentGateView()
        .environment(AuthManager())
}
#endif

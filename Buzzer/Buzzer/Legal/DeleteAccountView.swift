// DeleteAccountView.swift
// BusMate
//
// Account deletion confirmation screen.
//
// ── LEGAL WORDING — Australian Privacy Act / APP 11.2 ────────────────────
// APP 11.2 requires an entity to take reasonable steps to destroy or
// de-identify personal information it holds that is no longer needed for any
// purpose for which it may be used or disclosed under the Australian Privacy
// Act, subject to applicable exceptions.
//
// This is NOT an unconditional right to immediate deletion. BusMate may be
// required to retain certain information under:
//   • contractual obligations with schools
//   • applicable State/Territory laws
//   • legitimate operational purposes (e.g. audit trails)
//   • any other retention requirement that applies
//
// ⚠️ LEGAL REVIEW REQUIRED: Review applicable retention obligations with
// legal counsel before finalising the copy below. The wording marked
// [RETENTION PLACEHOLDER] must be verified and updated.
// ────────────────────────────────────────────────────────────────────────────
//
// APP STORE NOTE: App Store Review Guideline 5.1.1(v) requires in-app
// account deletion. This screen satisfies that requirement when linked
// from an accessible settings path. The deletion request must reach
// your backend — a support email alone is insufficient.

import SwiftUI

// MARK: - DeleteAccountView

struct DeleteAccountView: View {

    // MARK: Environment

    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    // MARK: Dependencies

    // ⚠️ INTEGRATION REQUIRED: In production, inject LiveAccountDeletionService.
    // For previews and tests, inject MockAccountDeletionService.
    var deletionService: any AccountDeletionService = LiveAccountDeletionService()

    // MARK: View State

    private enum ViewState: Equatable {
        case idle
        case confirmationDialog
        case submitting
        case success
        case error(String)
    }

    @State private var viewState: ViewState = .idle
    @State private var showMailCompose = false
    @State private var showCopyAlert = false

    // MARK: Support email
    // ⚠️ INTEGRATION REQUIRED: Replace with your actual support email.
    private let supportEmail = "support@busmate.com.au"

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch viewState {
                case .idle, .confirmationDialog:
                    idleContent
                case .submitting:
                    submittingContent
                case .success:
                    successContent
                case .error(let message):
                    errorContent(message: message)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewState == .submitting || viewState == .success)
        .confirmationDialog(
            "Permanently delete your account?",
            isPresented: Binding(
                get: { viewState == .confirmationDialog },
                set: { if !$0 && viewState == .confirmationDialog { viewState = .idle } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete My Account", role: .destructive) {
                Task { await performDeletion() }
            }
            Button("Cancel", role: .cancel) {
                viewState = .idle
            }
        } message: {
            Text(
                "This action cannot be undone. Your account and associated data will be " +
                "permanently deleted or de-identified in accordance with BusMate's data " +
                "retention policy."
            )
        }
        .alert("Address Copied", isPresented: $showCopyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Support email address copied to clipboard.")
        }
        .sheet(isPresented: $showMailCompose) {
            MailComposeView(
                recipient: supportEmail,
                subject: "Account Deletion Request",
                body: mailBody
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Idle content

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Warning header ───────────────────────────────────────────────
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text("This action is permanent")
                    .font(.headline)
                    .foregroundStyle(.red)
            }

            // ── What deletion means ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                Text("What happens when you delete your account:")
                    .font(.subheadline.weight(.semibold))

                bulletPoint("Your account will be deactivated immediately.")
                bulletPoint(
                    "Your personal information will be deleted or appropriately " +
                    "de-identified in accordance with BusMate's data retention schedule."
                )
                bulletPoint(
                    "You will be signed out of all devices."
                )
            }

            // ── Retention notice ────────────────────────────────────────────
            // ⚠️ [RETENTION PLACEHOLDER] — verify applicable obligations with
            // legal counsel before publishing.
            VStack(alignment: .leading, spacing: 8) {
                Text("Data BusMate may retain:")
                    .font(.subheadline.weight(.semibold))

                bulletPoint(
                    "BusMate may be required to retain limited records where " +
                    "school contractual obligations, applicable State or Territory " +
                    "laws, or other lawful requirements apply. This retention is " +
                    "subject to legal review. [RETENTION PLACEHOLDER]"
                )
                bulletPoint(
                    "Account deletion does not automatically delete historical trip " +
                    "records that may be retained under a school's contractual " +
                    "requirements. [RETENTION PLACEHOLDER]"
                )
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // ── Action buttons ───────────────────────────────────────────────
            VStack(spacing: 12) {
                Button(role: .destructive) {
                    viewState = .confirmationDialog
                } label: {
                    Text("Delete My Account")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityLabel("Delete My Account")
                .accessibilityHint(
                    "Opens a final confirmation dialog. Your account will be " +
                    "permanently deleted after you confirm."
                )

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }

            // ── Support fallback ─────────────────────────────────────────────
            supportFallbackSection
        }
    }

    // MARK: Submitting content

    private var submittingContent: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .accessibilityLabel("Deleting account, please wait.")
            Text("Deleting your account…")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Please do not close the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Success content

    private var successContent: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("Account Deleted")
                .font(.title2.weight(.bold))
            Text(
                "Your account has been deleted. Your data will be removed " +
                "or de-identified in accordance with BusMate's retention policy."
            )
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Account deleted. Your data will be removed or de-identified " +
            "in accordance with BusMate's retention policy."
        )
    }

    // MARK: Error content

    private func errorContent(message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text("Deletion failed")
                    .font(.headline)
                    .foregroundStyle(.red)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                viewState = .idle
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)

            supportFallbackSection
        }
    }

    // MARK: Support fallback

    /// Fallback section — clearly states that email does NOT submit deletion.
    private var supportFallbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Need help?")
                .font(.subheadline.weight(.semibold))

            // ⚠️ This fallback is informational only. Opening or sending
            // this email does NOT constitute an authenticated deletion request.
            Text(
                "If you cannot complete deletion via this screen, contact support. " +
                "Note: sending a support email does not delete your account — " +
                "our team will guide you through the process."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button {
                presentMail()
            } label: {
                Label(
                    "Contact Support About Account Deletion",
                    systemImage: "envelope"
                )
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .accessibilityHint(
                "Opens a pre-filled email to support. Sending this email does not delete your account."
            )
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Helpers

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    private func performDeletion() async {
        guard viewState != .submitting else { return }  // prevent duplicate submissions
        viewState = .submitting

        do {
            try await deletionService.requestDeletion()

            // ── Sign out only after server confirms deletion ──────────────
            // Do not clear local data or sign out before the server response.
            authManager.signOut()
            // ⚠️ INTEGRATION REQUIRED: Clear any other local caches,
            // keychain items, or Core Data stores specific to the deleted user.

            viewState = .success
        } catch let error as AccountDeletionError {
            viewState = .error(error.localizedDescription)
        } catch {
            viewState = .error(AccountDeletionError.unknown.localizedDescription)
        }
    }

    private func presentMail() {
        if MailComposeView.canSendMail {
            showMailCompose = true
        } else {
            UIPasteboard.general.string = supportEmail
            showCopyAlert = true
        }
    }

    /// Pre-filled email body. Does NOT include sensitive data, tokens, or PII.
    private var mailBody: String {
        // Include only non-sensitive information needed to triage the request.
        """
        Hello BusMate Support,

        I would like to request deletion of my BusMate account.

        Please do not include your password, government ID, or payment details in this email.

        Regards
        """
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Idle") {
    NavigationStack {
        DeleteAccountView(
            deletionService: MockAccountDeletionService(behaviour: .success)
        )
        .environment(AuthManager())
    }
}

#Preview("Deletion error") {
    NavigationStack {
        DeleteAccountView(
            deletionService: MockAccountDeletionService(
                behaviour: .failWithError(.serverError(statusCode: 500, message: "Server error"))
            )
        )
        .environment(AuthManager())
    }
}
#endif

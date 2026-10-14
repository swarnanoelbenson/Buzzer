// LegalAndPrivacyView.swift
// BusMate
//
// Settings screen: Legal & Privacy.
// Reachable from each portal's settings or profile section.
//
// APP STORE NOTE: App Store Review Guideline 5.1.1 requires a link to
// your privacy policy. This screen satisfies that requirement when linked
// from your in-app settings. The privacy policy URL is also required in
// your App Store Connect metadata.

import SwiftUI

// MARK: - LegalAndPrivacyView

struct LegalAndPrivacyView: View {

    // MARK: Environment

    @Environment(AuthManager.self) private var authManager

    // MARK: Private State

    @State private var presenter = LegalDocumentPresenter()
    @State private var showDeleteAccount = false
    @State private var showMailCompose = false
    @State private var showCopyAlert = false
    @State private var mailRecipient = ""
    @State private var mailSubject = ""

    // MARK: Body

    var body: some View {
        List {
            legalDocumentsSection
            contactSection
            accountSection
        }
        .navigationTitle("Legal & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .legalSheet(item: $presenter.activeDocument)
        .navigationDestination(isPresented: $showDeleteAccount) {
            DeleteAccountView()
                .environment(authManager)
        }
        .sheet(isPresented: $showMailCompose) {
            MailComposeView(
                recipient: mailRecipient,
                subject: mailSubject,
                body: ""
            )
            .ignoresSafeArea()
        }
        .alert("Address Copied", isPresented: $showCopyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Email address copied to clipboard.")
        }
    }

    // MARK: Sections

    private var legalDocumentsSection: some View {
        Section {
            documentRow(for: .termsOfService)
            documentRow(for: .privacyPolicy)
        } header: {
            Text("Documents")
        } footer: {
            // Show document versions so users can verify which revision they accepted.
            Text(
                "Terms v\(LegalDocument.termsOfService.version) · " +
                "Privacy Policy v\(LegalDocument.privacyPolicy.version)"
            )
            .font(.caption)
        }
    }

    private var contactSection: some View {
        Section {
            contactRow(
                label: "Support",
                email: BusMateConstants.supportEmail,
                subject: "BusMate Support Enquiry"
            )
            contactRow(
                label: "Legal Notices",
                email: BusMateConstants.noticesEmail,
                subject: "Legal Notice"
            )
        } header: {
            Text("Contact")
        } footer: {
            Text("For formal legal correspondence, use the Legal Notices address.")
                .font(.caption)
        }
    }

    private var accountSection: some View {
        Section {
            deleteAccountRow
        } header: {
            Text("Account")
        }
    }

    // MARK: Rows

    private func contactRow(label: String, email: String, subject: String) -> some View {
        Button {
            presentMail(recipient: email, subject: subject)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .foregroundStyle(.primary)
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "envelope")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityLabel("\(label): \(email)")
        .accessibilityHint("Opens a pre-filled email to \(email).")
    }

    private func documentRow(for document: LegalDocument) -> some View {
        Button {
            presenter.open(document)
        } label: {
            HStack {
                Text(document.title)
                    .foregroundStyle(.primary)   // not colour-only; chevron reinforces interactivity
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityLabel(document.accessibilityLabel)
        .accessibilityHint("Opens \(document.title) in Safari.")
    }

    private var deleteAccountRow: some View {
        Button(role: .destructive) {
            showDeleteAccount = true
        } label: {
            HStack {
                Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityLabel("Delete Account")
        .accessibilityHint("Opens the account deletion confirmation screen. This action is permanent.")
    }

    // MARK: Actions

    private func presentMail(recipient: String, subject: String) {
        if MailComposeView.canSendMail {
            mailRecipient = recipient
            mailSubject = subject
            showMailCompose = true
        } else {
            UIPasteboard.general.string = recipient
            showCopyAlert = true
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        LegalAndPrivacyView()
            .environment(AuthManager())
    }
}
#endif

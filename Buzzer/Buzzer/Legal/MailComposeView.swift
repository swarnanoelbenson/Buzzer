// MailComposeView.swift
// BusMate
//
// UIViewControllerRepresentable wrapper for MFMailComposeViewController.
//
// IMPORTANT: Drafting or sending an email via this view does NOT constitute
// an authenticated account deletion request. This is a support fallback only.
// The primary deletion path must go through DeleteAccountView → AccountDeletionService.
//
// SECURITY NOTES:
// - Do NOT pre-fill authentication tokens in the body or subject.
// - Do NOT pre-fill student names, locations, trip data, or other PII.
// - Do NOT describe the email as an authenticated action.
// - The pre-filled body must contain only non-sensitive triage information.
//
// If MFMailComposeViewController.canSendMail() returns false (e.g. no Mail
// account configured), present the `unavailableView` fallback instead.

import SwiftUI
import MessageUI

// MARK: - MailComposeView

struct MailComposeView: UIViewControllerRepresentable {

    // MARK: Configuration

    let recipient: String
    let subject: String
    let body: String

    // MARK: Availability check

    /// Call this before presenting `MailComposeView` to avoid a crash.
    ///
    /// If this returns `false`, show a fallback (e.g. copy the address).
    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    // MARK: UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // MFMailComposeViewController does not support updates after creation.
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            // Dismiss the compose sheet regardless of outcome (sent/cancelled/error).
            controller.dismiss(animated: true)

            // Optional: log or surface the result to the caller.
            // We intentionally do NOT interpret "sent" as a completed deletion request.
            #if DEBUG
            switch result {
            case .cancelled: print("MailComposeView: cancelled")
            case .saved:     print("MailComposeView: saved as draft")
            case .sent:      print("MailComposeView: sent (not a deletion request)")
            case .failed:    print("MailComposeView: failed — \(error?.localizedDescription ?? "unknown")")
            @unknown default: break
            }
            #endif
        }
    }
}

// MARK: - MailUnavailableView

/// Shown when MFMailComposeViewController.canSendMail() returns false.
///
/// Offers to copy the support address to the clipboard rather than silently failing.
struct MailUnavailableView: View {

    let supportEmail: String

    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text("Mail Not Available")
                    .font(.title3.weight(.bold))

                Text(
                    "A Mail account is not configured on this device. " +
                    "You can copy the support address and send an email from another app."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

                // Displayed — not a link, not a mailto: URL, to prevent
                // it from silently failing if Mail is unavailable.
                Text(supportEmail)
                    .font(.body.monospaced())
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    UIPasteboard.general.string = supportEmail
                    copied = true
                } label: {
                    Label(
                        copied ? "Copied!" : "Copy Address",
                        systemImage: copied ? "checkmark" : "doc.on.doc"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .animation(.easeInOut, value: copied)
                .accessibilityLabel(copied ? "Address copied" : "Copy support email address")

                Text(
                    "Remember: sending an email does not delete your account. " +
                    "Use the Delete Account button in settings for an immediate deletion request."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Mail unavailable fallback") {
    MailUnavailableView(supportEmail: "support@busmate.com.au")
}
#endif

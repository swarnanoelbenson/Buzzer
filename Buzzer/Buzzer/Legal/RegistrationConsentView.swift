// RegistrationConsentView.swift
// BusMate
//
// Clickwrap acceptance control for the registration flow.
//
// LEGAL NOTE: This UI component records *local intent* only.
// The backend MUST record acceptance (terms version, privacy version,
// timestamp, and user identifier) server-side against the newly created
// account. Local UI state alone is not durable evidence of consent.
//
// APP STORE NOTE: This component helps satisfy App Store Review Guideline
// 5.1.1 (Privacy - Data Collection and Storage) by providing informed
// consent before account creation.

import SwiftUI

// MARK: - ConsentRecord

/// The data your backend should persist when a user accepts during registration.
///
/// Pass this to your account-creation API alongside the new user's credentials.
/// Do NOT rely on local storage as the authoritative record of acceptance.
struct ConsentRecord: Equatable {
    /// Whether the user ticked the acceptance control.
    let accepted: Bool
    /// Published version string for Terms of Service at time of acceptance.
    let termsVersion: String
    /// Published version string for Privacy Policy at time of acceptance.
    let privacyPolicyVersion: String
    /// UTC timestamp of acceptance, formatted as ISO 8601.
    let acceptedAt: String

    // MARK: Static

    static func makeAccepted() -> ConsentRecord {
        ConsentRecord(
            accepted: true,
            termsVersion: LegalDocument.termsOfService.version,
            privacyPolicyVersion: LegalDocument.privacyPolicy.version,
            acceptedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}

// MARK: - RegistrationConsentView

/// A reusable clickwrap consent section intended for embedding in a
/// registration form.
///
/// Embed this above your Create Account button and pass in a binding to
/// the acceptance toggle state. The `onConsent` callback is fired when
/// the user taps Create Account with the box ticked, giving you a
/// `ConsentRecord` to forward to your backend.
///
/// Example:
/// ```swift
/// @State private var consentAccepted = false
///
/// RegistrationConsentView(isAccepted: $consentAccepted) { record in
///     // Forward record.acceptedAt, record.termsVersion, etc. to your API.
///     await createAccount(consent: record)
/// }
/// ```
struct RegistrationConsentView: View {

    // MARK: Configuration

    /// Binding to acceptance state in the parent form.
    @Binding var isAccepted: Bool

    /// Called when the Create Account button is tapped and `isAccepted` is
    /// true. Provides the `ConsentRecord` to forward to your backend.
    var onConsent: (ConsentRecord) async -> Void

    // MARK: Private State

    @State private var presenter = LegalDocumentPresenter()

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            consentToggleRow
            createAccountButton
        }
        .legalSheet(item: $presenter.activeDocument)
    }

    // MARK: Subviews

    /// Toggle row with multiline, accessible, linkified consent text.
    private var consentToggleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // ── Acceptance control ──────────────────────────────────────────
            // Positioned BEFORE the button so screen readers encounter the
            // checkbox before the actionable text.
            Toggle("", isOn: $isAccepted)
                .labelsHidden()
                .toggleStyle(.checkmark)
                .accessibilityLabel("Accept terms and privacy policy")
                .accessibilityHint(
                    isAccepted
                    ? "Checked. Tap to uncheck."
                    : "Unchecked. Tap to accept the Terms of Service and Privacy Policy."
                )
                .frame(width: 44, height: 44) // minimum tap target

            // ── Consent text ────────────────────────────────────────────────
            consentText
        }
    }

    /// Multiline consent statement with tappable legal-document links.
    ///
    /// Tapping a link opens the relevant document but does NOT toggle
    /// acceptance or trigger form submission.
    private var consentText: some View {
        // We compose using Text concatenation so Dynamic Type and VoiceOver
        // work correctly with the inline link buttons.
        Group {
            Text("I agree to the ")
                .foregroundStyle(.primary)
            +
            Text("Terms of Service")
                .foregroundStyle(Color.accentColor)
                .underline()
            +
            Text(" and acknowledge that I have read the ")
                .foregroundStyle(.primary)
            +
            Text("Privacy Policy")
                .foregroundStyle(Color.accentColor)
                .underline()
            +
            Text(".")
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(
            // Invisible accessible buttons layered over the link text.
            // These open the documents WITHOUT affecting the toggle or form.
            HStack {
                legalLinkButton(for: .termsOfService)
                legalLinkButton(for: .privacyPolicy)
            }
            .opacity(0)
            , alignment: .leading
        )
        // Provide a full accessibility action description since the overlay
        // approach means the tappable regions are not directly visible.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "I agree to the Terms of Service and acknowledge that I have read the Privacy Policy. " +
            "Use the Terms of Service and Privacy Policy buttons to read each document."
        )
        // Surface the document-open actions for VoiceOver users.
        .accessibilityAction(named: "Open Terms of Service") {
            presenter.open(.termsOfService)
        }
        .accessibilityAction(named: "Open Privacy Policy") {
            presenter.open(.privacyPolicy)
        }
    }

    private func legalLinkButton(for document: LegalDocument) -> some View {
        Button {
            // Opening a document must not toggle acceptance.
            presenter.open(document)
        } label: {
            Text(document.title)
        }
        .accessibilityLabel(document.accessibilityLabel)
    }

    /// Create Account button — disabled until the acceptance toggle is ticked.
    private var createAccountButton: some View {
        Button {
            guard isAccepted else { return }
            let record = ConsentRecord.makeAccepted()
            Task { await onConsent(record) }
        } label: {
            Text("Create Account")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isAccepted)
        .accessibilityLabel(
            isAccepted
            ? "Create Account"
            : "Create Account — disabled until you accept the Terms of Service and Privacy Policy"
        )
        .accessibilityHint(
            isAccepted
            ? ""
            : "Tick the acceptance checkbox above to enable this button."
        )
    }
}

// MARK: - CheckmarkToggleStyle

/// A checkbox-style toggle so colour alone does not communicate state.
/// The checkmark glyph reinforces the ticked/unticked state for
/// colour-blind users and satisfies WCAG 1.4.1.
struct CheckmarkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Image(systemName: configuration.isOn
                  ? "checkmark.square.fill"
                  : "square")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == CheckmarkToggleStyle {
    static var checkmark: CheckmarkToggleStyle { CheckmarkToggleStyle() }
}

// MARK: - Preview

#if DEBUG
#Preview("Consent — not accepted") {
    @Previewable @State var accepted = false
    Form {
        RegistrationConsentView(isAccepted: $accepted) { record in
            print("Consent: \(record)")
        }
    }
}

#Preview("Consent — accepted") {
    @Previewable @State var accepted = true
    Form {
        RegistrationConsentView(isAccepted: $accepted) { record in
            print("Consent: \(record)")
        }
    }
}
#endif

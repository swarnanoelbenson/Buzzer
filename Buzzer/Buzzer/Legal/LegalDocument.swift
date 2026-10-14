// LegalDocument.swift
// BusMate
//
// Central configuration for all legal documents served to users.
// Only pre-approved HTTPS URLs may be presented via SafariView.
// No arbitrary URLs are accepted elsewhere in the legal flow.

import Foundation

// MARK: - Version Placeholders
// ⚠️ INTEGRATION REQUIRED: Replace these string literals with your actual
// published document versions before App Store submission.
// These should ideally come from a remote config or your backend so they
// update without a new app release.

private let kTermsVersion        = "1.0"       // e.g. "2025-10-01"
private let kPrivacyPolicyVersion = "1.0"      // e.g. "2025-10-01"

// MARK: - LegalDocument

/// Represents a legal document that BusMate may present to users.
///
/// Only documents whose URLs pass `isValid` may be opened via `SafariView`.
/// Add new cases here — do **not** accept arbitrary `URL` values in
/// legal-document presentation paths.
enum LegalDocument: String, Identifiable, CaseIterable {

    case termsOfService
    case privacyPolicy

    // MARK: Identifiable

    var id: String { rawValue }

    // MARK: Metadata

    var title: String {
        switch self {
        case .termsOfService: return "Terms of Service"
        case .privacyPolicy:  return "Privacy Policy"
        }
    }

    var version: String {
        switch self {
        case .termsOfService: return kTermsVersion
        case .privacyPolicy:  return kPrivacyPolicyVersion
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .termsOfService:
            return "Terms of Service, version \(version). Opens in Safari."
        case .privacyPolicy:
            return "Privacy Policy, version \(version). Opens in Safari."
        }
    }

    // MARK: URL

    /// The validated, fixed HTTPS URL for this document.
    ///
    /// Returns `nil` only if the hard-coded URL string is malformed or
    /// has an unexpected scheme/host — this indicates a programming error
    /// and should be caught during development.
    var url: URL? {
        let raw: String
        switch self {
        case .termsOfService:
            raw = "https://busmate.com.au/terms-of-service"
        case .privacyPolicy:
            raw = "https://busmate.com.au/privacy-policy"
        }
        guard let url = URL(string: raw), isValid(url) else {
            assertionFailure("LegalDocument: hard-coded URL '\(raw)' failed validation.")
            return nil
        }
        return url
    }

    // MARK: URL Validation

    /// Returns `true` only when the URL uses HTTPS and is on the approved host.
    ///
    /// This guard is intentionally strict: legal documents must only be loaded
    /// from busmate.com.au. If you migrate to a different host, update both
    /// the raw string above **and** `approvedHosts` below.
    func isValid(_ url: URL) -> Bool {
        let approvedHosts: Set<String> = ["busmate.com.au", "www.busmate.com.au"]
        return url.scheme == "https" && approvedHosts.contains(url.host ?? "")
    }
}

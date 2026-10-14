// BusMateConstants.swift
// BusMate
//
// App-wide constants. Update these values here only — do not scatter
// literal strings throughout the codebase.

import Foundation

// MARK: - BusMateConstants

enum BusMateConstants {

    // MARK: Email

    /// General user support enquiries and account deletion fallback.
    /// Shown to end users in-app.
    static let supportEmail = "support@busmate.com.au"

    /// Formal legal correspondence and regulatory notices.
    /// Not shown to end users directly; referenced in legal documents and
    /// Terms of Service as the address for written notices to BusMate.
    static let noticesEmail = "notices@busmate.com.au"
}

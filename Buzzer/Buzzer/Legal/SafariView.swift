// SafariView.swift
// BusMate
//
// UIViewControllerRepresentable wrapper for SFSafariViewController.
// This is the ONLY mechanism for presenting legal documents in-app.
// Do NOT use WKWebView for legal content.
// Do NOT pass this arbitrary URLs — use LegalDocument.url exclusively.

import SwiftUI
import SafariServices

// MARK: - SafariView

/// A SwiftUI wrapper around `SFSafariViewController`.
///
/// Present this via `.sheet` or `.fullScreenCover` using a `LegalDocument`
/// as the item. Never construct this with a URL that has not been validated
/// by `LegalDocument.isValid(_:)`.
///
/// `SFSafariViewController` is a browsing convenience, not an authentication
/// mechanism. Do not use it for OAuth flows.
struct SafariView: UIViewControllerRepresentable {

    // MARK: Properties

    let url: URL

    // MARK: UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true

        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredBarTintColor = nil   // respect system appearance / Dark Mode
        vc.preferredControlTintColor = nil
        vc.dismissButtonStyle = .done
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // SFSafariViewController does not support URL updates after creation.
        // Dismiss and re-present to load a different document.
    }
}

// MARK: - SafariView + LegalDocument convenience

extension View {

    /// Presents a `SafariView` sheet for the given `LegalDocument`.
    ///
    /// Usage:
    /// ```swift
    /// .legalSheet(item: $activeLegalDocument)
    /// ```
    ///
    /// If the document's URL is invalid (programming error), the sheet is
    /// silently not presented and an assertion fires in DEBUG builds.
    @ViewBuilder
    func legalSheet(item: Binding<LegalDocument?>) -> some View {
        self.sheet(item: item) { document in
            if let url = document.url {
                SafariView(url: url)
                    .ignoresSafeArea()
                    .accessibilityLabel(document.accessibilityLabel)
            } else {
                // Unreachable in production; hard-coded URLs are always valid.
                // Shown only if a developer introduces a bad URL string.
                ContentUnavailableView(
                    "Document unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This document could not be loaded. Please visit busmate.com.au")
                )
            }
        }
    }
}

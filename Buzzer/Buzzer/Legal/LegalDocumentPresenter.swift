// LegalDocumentPresenter.swift
// BusMate
//
// Observable presentation state for legal documents.
// Attach one instance as an @State or @Environment value and drive
// .legalSheet(item:) from it.

import SwiftUI

// MARK: - LegalDocumentPresenter

/// Manages which (if any) `LegalDocument` is currently being presented.
///
/// Inject into a view hierarchy with `.environment(presenter)` or hold as
/// `@State private var presenter = LegalDocumentPresenter()`.
///
/// Example:
/// ```swift
/// @State private var legalPresenter = LegalDocumentPresenter()
///
/// var body: some View {
///     MyView()
///         .environment(legalPresenter)
///         .legalSheet(item: $legalPresenter.activeDocument)
/// }
/// ```
@Observable
final class LegalDocumentPresenter {

    // MARK: State

    /// The document currently being presented, or `nil` when no sheet is shown.
    var activeDocument: LegalDocument?

    // MARK: Actions

    /// Opens the given legal document in a Safari sheet.
    ///
    /// - Note: Tapping a legal link should never trigger any side-effects
    ///   such as toggling consent or submitting a form. Call this method
    ///   only in response to a deliberate user tap on a labelled legal link.
    func open(_ document: LegalDocument) {
        activeDocument = document
    }

    func dismiss() {
        activeDocument = nil
    }
}

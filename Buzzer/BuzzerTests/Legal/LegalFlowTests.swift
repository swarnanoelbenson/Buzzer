// LegalFlowTests.swift
// BuzzerTests
//
// Unit tests for URL validation, registration consent, and deletion state.
// Uses Swift Testing framework (Xcode 16+).
//
// Run with: Product → Test (⌘U)

import Testing
import Foundation
@testable import Buzzer

// MARK: - LegalDocument URL Tests

@Suite("LegalDocument URL Validation")
struct LegalDocumentURLTests {

    // ── All documents must produce a non-nil URL ──────────────────────────

    @Test("All LegalDocument cases return a non-nil URL")
    func allDocumentsHaveURLs() {
        for document in LegalDocument.allCases {
            #expect(document.url != nil, "\(document.rawValue) returned nil URL")
        }
    }

    @Test("Terms of Service URL uses HTTPS")
    func termsURLUsesHTTPS() throws {
        let url = try #require(LegalDocument.termsOfService.url)
        #expect(url.scheme == "https")
    }

    @Test("Privacy Policy URL uses HTTPS")
    func privacyURLUsesHTTPS() throws {
        let url = try #require(LegalDocument.privacyPolicy.url)
        #expect(url.scheme == "https")
    }

    @Test("Terms of Service URL host is busmate.com.au")
    func termsURLHost() throws {
        let url = try #require(LegalDocument.termsOfService.url)
        #expect(url.host == "busmate.com.au")
    }

    @Test("Privacy Policy URL host is busmate.com.au")
    func privacyURLHost() throws {
        let url = try #require(LegalDocument.privacyPolicy.url)
        #expect(url.host == "busmate.com.au")
    }

    // ── isValid rejects bad inputs ────────────────────────────────────────

    @Test("isValid rejects HTTP URL")
    func rejectsHTTP() {
        let httpURL = URL(string: "http://busmate.com.au/terms-of-service")!
        #expect(!LegalDocument.termsOfService.isValid(httpURL))
    }

    @Test("isValid rejects wrong host")
    func rejectsWrongHost() {
        let wrongHost = URL(string: "https://evil.com/terms-of-service")!
        #expect(!LegalDocument.termsOfService.isValid(wrongHost))
    }

    @Test("isValid rejects subdomain of wrong host")
    func rejectsWrongSubdomain() {
        let wrongSub = URL(string: "https://busmate.com.au.evil.com/privacy")!
        #expect(!LegalDocument.termsOfService.isValid(wrongSub))
    }

    @Test("isValid accepts www.busmate.com.au")
    func acceptsWWW() {
        let www = URL(string: "https://www.busmate.com.au/terms-of-service")!
        #expect(LegalDocument.termsOfService.isValid(www))
    }

    // ── Version strings must not be empty ────────────────────────────────

    @Test("All LegalDocument versions are non-empty")
    func versionsAreNonEmpty() {
        for document in LegalDocument.allCases {
            #expect(!document.version.isEmpty, "\(document.rawValue) has empty version")
        }
    }
}

// MARK: - ConsentRecord Tests

@Suite("ConsentRecord")
struct ConsentRecordTests {

    @Test("makeAccepted sets accepted = true")
    func acceptedFlagIsTrue() {
        let record = ConsentRecord.makeAccepted()
        #expect(record.accepted == true)
    }

    @Test("makeAccepted captures terms version")
    func capturesTermsVersion() {
        let record = ConsentRecord.makeAccepted()
        #expect(record.termsVersion == LegalDocument.termsOfService.version)
    }

    @Test("makeAccepted captures privacy version")
    func capturesPrivacyVersion() {
        let record = ConsentRecord.makeAccepted()
        #expect(record.privacyPolicyVersion == LegalDocument.privacyPolicy.version)
    }

    @Test("makeAccepted produces a valid ISO 8601 timestamp")
    func timestampIsISO8601() {
        let record = ConsentRecord.makeAccepted()
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: record.acceptedAt)
        #expect(date != nil, "acceptedAt '\(record.acceptedAt)' is not valid ISO 8601")
    }

    @Test("makeAccepted timestamp is recent (within 5 seconds)")
    func timestampIsRecent() throws {
        let record = ConsentRecord.makeAccepted()
        let formatter = ISO8601DateFormatter()
        let date = try #require(formatter.date(from: record.acceptedAt))
        #expect(abs(date.timeIntervalSinceNow) < 5)
    }
}

// MARK: - AccountDeletionService Tests

@Suite("AccountDeletionService — Mock Behaviours")
struct AccountDeletionServiceTests {

    @Test("MockAccountDeletionService succeeds with .success behaviour")
    func mockSuccess() async throws {
        let service = MockAccountDeletionService(behaviour: .success)
        // Should not throw
        try await service.requestDeletion()
    }

    @Test("MockAccountDeletionService throws with .failWithError behaviour")
    func mockFailure() async {
        let service = MockAccountDeletionService(
            behaviour: .failWithError(.serverError(statusCode: 500, message: "test"))
        )
        do {
            try await service.requestDeletion()
            Issue.record("Expected AccountDeletionError to be thrown")
        } catch let error as AccountDeletionError {
            if case .serverError(let code, _) = error {
                #expect(code == 500)
            } else {
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("MockAccountDeletionService throws .notAuthenticated")
    func mockNotAuthenticated() async {
        let service = MockAccountDeletionService(
            behaviour: .failWithError(.notAuthenticated)
        )
        do {
            try await service.requestDeletion()
            Issue.record("Expected error was not thrown")
        } catch AccountDeletionError.notAuthenticated {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("AccountDeletionError.serverError has a localised description")
    func serverErrorDescription() {
        let error = AccountDeletionError.serverError(statusCode: 503, message: "Service unavailable")
        #expect(error.localizedDescription == "Service unavailable")
    }

    @Test("AccountDeletionError.networkError has a localised description")
    func networkErrorDescription() {
        let error = AccountDeletionError.networkError("timeout")
        #expect(error.localizedDescription?.contains("timeout") == true)
    }
}

// MARK: - LegalDocumentPresenter Tests

@Suite("LegalDocumentPresenter")
struct LegalDocumentPresenterTests {

    @Test("open sets activeDocument")
    func opensDocument() {
        let presenter = LegalDocumentPresenter()
        presenter.open(.termsOfService)
        #expect(presenter.activeDocument == .termsOfService)
    }

    @Test("dismiss clears activeDocument")
    func dismissesDocument() {
        let presenter = LegalDocumentPresenter()
        presenter.open(.privacyPolicy)
        presenter.dismiss()
        #expect(presenter.activeDocument == nil)
    }

    @Test("open replaces active document")
    func replacesDocument() {
        let presenter = LegalDocumentPresenter()
        presenter.open(.termsOfService)
        presenter.open(.privacyPolicy)
        #expect(presenter.activeDocument == .privacyPolicy)
    }
}

// AccountDeletionService.swift
// BusMate
//
// Protocol and non-production mock for the account deletion API.
//
// ──────────────────────────────────────────────────────────────────────────
// ⚠️  BACKEND INTEGRATION REQUIRED
//
// 1. Replace `[DELETE ACCOUNT ENDPOINT]` with your actual API URL.
// 2. The request MUST be authenticated — send the Firebase ID token in
//    the Authorization header ("Bearer <idToken>").
// 3. Do NOT pass the Firebase ID token in the URL, query string, or
//    request body visible in logs.
// 4. The endpoint must:
//      a. Verify the token server-side via Firebase Admin SDK.
//      b. Mark the account as deleted/deactivated in your database.
//      c. Schedule or execute data deletion/de-identification per your
//         retention policy (see Section 6 — Account Deletion Legal Wording).
//      d. Return HTTP 204 (no content) on success.
//      e. Return HTTP 4xx with a JSON error body on failure.
// 5. After a 204 response, the client will call Firebase Auth signOut().
//    The server has already invalidated the account; the Firebase Auth
//    session revocation is best-effort from the client side.
// 6. Sign in with Apple: if the user authenticated via Sign in with Apple,
//    you MUST revoke their Apple token before deleting the Firebase Auth
//    user. See the integration point marked ⚠️ SiWA below.
// ──────────────────────────────────────────────────────────────────────────

import Foundation

// MARK: - AccountDeletionError

enum AccountDeletionError: LocalizedError, Equatable {
    case notAuthenticated
    case reAuthRequired
    case serverError(statusCode: Int, message: String)
    case networkError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to delete your account."
        case .reAuthRequired:
            return "Please sign in again before deleting your account."
        case .serverError(_, let message):
            return message
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .unknown:
            return "An unexpected error occurred. Please try again or contact support."
        }
    }
}

// MARK: - AccountDeletionService Protocol

/// Abstracts the account deletion network call so DeleteAccountView can be
/// tested without hitting a real API.
protocol AccountDeletionService: Sendable {

    /// Submits a deletion request for the currently authenticated user.
    ///
    /// Implementations must:
    /// - Attach a valid, freshly obtained Firebase ID token.
    /// - Return on success (HTTP 204 from the server).
    /// - Throw `AccountDeletionError` on any failure.
    ///
    /// The caller is responsible for signing the user out **after** this
    /// returns successfully.
    func requestDeletion() async throws
}

// MARK: - LiveAccountDeletionService

/// Production implementation.
///
/// ⚠️  INTEGRATION REQUIRED: Replace the placeholder endpoint URL and
/// fill in the Firebase Auth token retrieval. See comments inline.
final class LiveAccountDeletionService: AccountDeletionService {

    // ⚠️ INTEGRATION REQUIRED: Replace with your actual deletion endpoint.
    private let endpoint = URL(string: "https://[DELETE ACCOUNT ENDPOINT]")!

    func requestDeletion() async throws {
        // ── Step 1: Obtain a fresh Firebase ID token ───────────────────────
        // ⚠️ INTEGRATION REQUIRED: Uncomment and adapt the following using
        // FirebaseAuth. Import FirebaseAuth at the top of this file.
        //
        // guard let user = Auth.auth().currentUser else {
        //     throw AccountDeletionError.notAuthenticated
        // }
        // let idToken: String
        // do {
        //     idToken = try await user.getIDToken()
        // } catch {
        //     throw AccountDeletionError.reAuthRequired
        // }

        // ── Step 2: ⚠️ SiWA — Revoke Apple credential if applicable ───────
        // If you support Sign in with Apple, call ASAuthorizationAppleIDProvider
        // revokeToken before deleting the Firebase user. Apple requires this.
        //
        // let appleRevoked = await revokeAppleCredentialIfNeeded(user: user)
        // If revocation fails and you wish to abort: throw the error.

        // ── Step 3: Build and send the authenticated request ───────────────
        // ⚠️ INTEGRATION REQUIRED: Re-enable when Steps 1–2 are complete.
        // The request must NOT include the token in the URL or body.
        //
        // var request = URLRequest(url: endpoint)
        // request.httpMethod = "DELETE"
        // request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        // request.setValue("application/json", forHTTPHeaderField: "Accept")
        //
        // let (_, response) = try await URLSession.shared.data(for: request)
        // guard let http = response as? HTTPURLResponse else {
        //     throw AccountDeletionError.unknown
        // }
        // switch http.statusCode {
        // case 204:
        //     return  // success — caller will sign out
        // case 401:
        //     throw AccountDeletionError.reAuthRequired
        // default:
        //     throw AccountDeletionError.serverError(
        //         statusCode: http.statusCode,
        //         message: "Deletion request failed (HTTP \(http.statusCode)). Please try again."
        //     )
        // }

        // ── Temporary placeholder (remove when integration is complete) ────
        throw AccountDeletionError.serverError(
            statusCode: 501,
            message: "Account deletion is not yet configured. " +
                     "Please contact \(BusMateConstants.supportEmail)"
        )
    }
}

// MARK: - MockAccountDeletionService

/// Non-production mock for use in SwiftUI previews and unit tests.
/// Do NOT ship this in release builds.
final class MockAccountDeletionService: AccountDeletionService, @unchecked Sendable {

    indirect enum Behaviour {
        case success
        case failWithError(AccountDeletionError)
        case delay(seconds: UInt64, then: Behaviour)
    }

    var behaviour: Behaviour

    init(behaviour: Behaviour = .success) {
        self.behaviour = behaviour
    }

    func requestDeletion() async throws {
        switch behaviour {
        case .success:
            return
        case .failWithError(let error):
            throw error
        case .delay(let seconds, let next):
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            behaviour = next
            try await requestDeletion()
        }
    }
}

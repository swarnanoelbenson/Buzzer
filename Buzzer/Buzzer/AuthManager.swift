//
//  AuthManager.swift
//  Buzzer
//
//  Manages authentication state for all portals.
//  Driver, Parent, and Student portals use email + password.
//  Admin portal uses OTP magic link (unchanged).
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import Observation

enum UserRole {
    case driver
    case parent
    case student
    case admin
    case none
}

@Observable
@MainActor
class AuthManager {
    var currentRole: UserRole = .none
    var currentUserId: String? = nil
    var schoolId: String? = nil     // Set only for admin role — the school doc ID
    var isLoading: Bool = true

    private let db = Firestore.db
    @ObservationIgnored nonisolated(unsafe) private var authStateListener: AuthStateDidChangeListenerHandle?
    @ObservationIgnored nonisolated(unsafe) private var tokenObserver: NSObjectProtocol?

    init() {
        listenToAuthState()
        listenForTokenRefresh()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth State

    private func listenToAuthState() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task {
                if let user = user {
                    await self.resolveRole(for: user.uid)
                } else {
                    self.currentRole = .none
                    self.currentUserId = nil
                    self.schoolId = nil
                    self.isLoading = false
                }
            }
        }
    }

    /// After Firebase login, check Firestore to determine the user's role.
    /// First tries UID-based lookup, then falls back to email-based lookup
    /// (needed for driver/parent/student accounts whose Firestore docs were
    /// pre-created by WAC with auto-generated IDs before first login).
    private func resolveRole(for uid: String) async {
        let email = Auth.auth().currentUser?.email?.trimmingCharacters(in: .whitespaces).lowercased()

        // MARK: Drivers

        // Direct UID lookup (works after first sign-in syncs the doc)
        let driverDoc = try? await db.collection("drivers").document(uid).getDocument()
        if driverDoc?.exists == true {
            self.currentRole = .driver
            self.currentUserId = uid
            self.isLoading = false
            await saveCurrentFCMToken()
            return
        }

        // Email-based lookup (first login — WAC created doc with a different ID)
        if let email {
            let snap = try? await db.collection("drivers")
                .whereField("email", isEqualTo: email)
                .whereField("isActive", isEqualTo: true)
                .limit(to: 1)
                .getDocuments()
            if let doc = snap?.documents.first {
                self.currentRole = .driver
                self.currentUserId = doc.documentID
                self.isLoading = false
                await saveCurrentFCMToken()
                return
            }
        }

        // Simulator bypass: driver auth account links to a fixed-ID driver doc
        #if targetEnvironment(simulator)
        let bypassSnapshot = try? await db.collection("drivers")
            .whereField("simulatorBypass", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()
        if let linkedId = bypassSnapshot?.documents.first?.data()["linkedDriverId"] as? String {
            self.currentRole = .driver
            self.currentUserId = linkedId   // use the real driver doc ID
            self.isLoading = false
            return
        }
        #endif

        // MARK: Parents

        let parentDoc = try? await db.collection("parents").document(uid).getDocument()
        if parentDoc?.exists == true {
            self.currentRole = .parent
            self.currentUserId = uid
            self.isLoading = false
            await saveCurrentFCMToken()
            return
        }

        if let email {
            let snap = try? await db.collection("parents")
                .whereField("email", isEqualTo: email)
                .whereField("isActive", isEqualTo: true)
                .limit(to: 1)
                .getDocuments()
            if let doc = snap?.documents.first {
                self.currentRole = .parent
                self.currentUserId = doc.documentID
                self.isLoading = false
                await saveCurrentFCMToken()
                return
            }
        }

        // MARK: Students

        let studentDoc = try? await db.collection("students").document(uid).getDocument()
        if studentDoc?.exists == true {
            self.currentRole = .student
            self.currentUserId = uid
            self.isLoading = false
            return
        }

        if let email {
            let snap = try? await db.collection("students")
                .whereField("email", isEqualTo: email)
                .whereField("isActive", isEqualTo: true)
                .limit(to: 1)
                .getDocuments()
            if let doc = snap?.documents.first {
                self.currentRole = .student
                self.currentUserId = doc.documentID
                self.isLoading = false
                return
            }
        }

        // MARK: Admin

        let schoolSnap = try? await db.collection("schools")
            .whereField("adminUid", isEqualTo: uid)
            .limit(to: 1)
            .getDocuments()
        if let schoolDoc = schoolSnap?.documents.first {
            self.currentRole = .admin
            self.currentUserId = uid           // Firebase Auth UID of the admin
            self.schoolId = schoolDoc.documentID  // Firestore school doc ID
            self.isLoading = false
            return
        }

        // Authenticated but no role found — sign out
        try? Auth.auth().signOut()
        self.currentRole = .none
        self.currentUserId = nil
        self.schoolId = nil
        self.isLoading = false
    }

    // MARK: - Email + Password Sign-In (Driver / Parent / Student)

    /// Signs in with email and password. Used by all three non-admin portals.
    func signInWithEmailPassword(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    /// Creates a new Firebase Auth account and signs in.
    /// Called during first-time password setup when `passwordSet == false`.
    func signUpWithEmailPassword(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    /// Updates the password for the currently signed-in user.
    /// Called when the user wants to change their password (forgot password flow).
    func updatePassword(_ newPassword: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No signed-in user."])
        }
        try await user.updatePassword(to: newPassword)
    }

    // MARK: - Admin Login (Custom Token from OTP API)

    func signInWithCustomToken(_ token: String) async throws {
        try await Auth.auth().signIn(withCustomToken: token)
    }

    // MARK: - Admin Login (Magic Link — Universal Link handler)

    /// Called from BuzzerApp.onOpenURL when the admin taps the magic-link email on a real device.
    /// Calls WAC /api/admin-signin-link/verify, gets a Firebase custom token, and signs in.
    func signInWithMagicLink(token: String, email: String) async {
        guard let url = URL(string: "https://busmate-admin.vercel.app/api/admin-signin-link/verify") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token, "email": email])

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let customToken = json?["customToken"] as? String else { return }
            try await Auth.auth().signIn(withCustomToken: customToken)
        } catch {
            // Silent failure — the admin will see they're not logged in and can retry
        }
    }

    // MARK: - FCM Token

    private func listenForTokenRefresh() {
        tokenObserver = NotificationCenter.default.addObserver(
            forName: .fcmTokenRefreshed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let token = notification.userInfo?["token"] as? String else { return }
            Task { await self.saveFCMToken(token) }
        }
    }

    func saveFCMToken(_ token: String) async {
        guard let uid = currentUserId else { return }
        let collection: String
        switch currentRole {
        case .driver:  collection = "drivers"
        case .parent:  collection = "parents"
        case .student: collection = "students"
        case .admin:   collection = "schools"
        case .none:    return
        }
        try? await db.collection(collection).document(uid).updateData(["fcmToken": token])
    }

    /// Call this after login to immediately save the current FCM token.
    func saveCurrentFCMToken() async {
        guard let token = Messaging.messaging().fcmToken else { return }
        await saveFCMToken(token)
    }

    // MARK: - Sign Out

    func signOut() {
        try? Auth.auth().signOut()
        currentRole = .none
        currentUserId = nil
        schoolId = nil
    }
}

//
//  FirebaseAuthManager.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//

import Foundation
import Combine

/// Firebase Authentication Manager
/// Note: This is a mock implementation. In production, you would:
/// 1. Add Firebase SDK via SPM: https://github.com/firebase/firebase-ios-sdk
/// 2. Add GoogleService-Info.plist to your project
/// 3. Replace this mock with real Firebase authentication
class FirebaseAuthManager: ObservableObject {
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var authError: String?
    
    static let shared = FirebaseAuthManager()
    
    // Mock user storage (in production, this would be Firebase)
    private let userDefaultsKey = "BuzzerAuthenticatedUser"
    private let mockUsersKey = "BuzzerMockUsers"
    private let mockUserProfilesKey = "BuzzerMockUserProfiles"
    
    private init() {
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Status
    
    func checkAuthenticationStatus() {
        if let savedEmail = UserDefaults.standard.string(forKey: userDefaultsKey) {
            // User is logged in - load full profile
            if let profile = getUserProfile(email: savedEmail) {
                currentUser = User(email: savedEmail, phone: profile.phone, busRegistration: profile.busRegistration)
            } else {
                currentUser = User(email: savedEmail, phone: "", busRegistration: "")
            }
            isAuthenticated = true
        } else {
            // User is not logged in
            currentUser = nil
            isAuthenticated = false
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String, completion: @escaping (Result<User, AuthError>) -> Void) {
        // Validate input
        guard !email.isEmpty else {
            authError = "Email cannot be empty"
            completion(.failure(.invalidEmail))
            return
        }
        
        guard !password.isEmpty else {
            authError = "Password cannot be empty"
            completion(.failure(.invalidPassword))
            return
        }
        
        guard password.count >= 4 else {
            authError = "Password must be at least 4 characters"
            completion(.failure(.invalidPassword))
            return
        }
        
        // Mock authentication delay (simulating network request)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // Get mock users
            let mockUsers = self.getMockUsers()
            
            // Check if user exists and password matches
            if let storedPassword = mockUsers[email], storedPassword == password {
                // Sign in successful - load full profile
                let profile = self.getUserProfile(email: email)
                let user = User(email: email, phone: profile?.phone ?? "", busRegistration: profile?.busRegistration ?? "")
                self.currentUser = user
                self.isAuthenticated = true
                self.authError = nil
                
                // Save authentication state
                UserDefaults.standard.set(email, forKey: self.userDefaultsKey)
                
                completion(.success(user))
            } else {
                // Sign in failed
                self.authError = "Invalid email or password"
                completion(.failure(.invalidCredentials))
            }
        }
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, phone: String, busRegistration: String, completion: @escaping (Result<User, AuthError>) -> Void) {
        // Validate input
        guard !email.isEmpty else {
            authError = "Email cannot be empty"
            completion(.failure(.invalidEmail))
            return
        }
        
        guard isValidEmail(email) else {
            authError = "Please enter a valid email address"
            completion(.failure(.invalidEmail))
            return
        }
        
        guard !password.isEmpty else {
            authError = "Password cannot be empty"
            completion(.failure(.invalidPassword))
            return
        }
        
        guard password.count >= 4 else {
            authError = "Password must be at least 4 characters"
            completion(.failure(.weakPassword))
            return
        }
        
        // Mock authentication delay (simulating network request)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // Get mock users
            var mockUsers = self.getMockUsers()
            
            // Check if user already exists
            if mockUsers[email] != nil {
                self.authError = "An account with this email already exists"
                completion(.failure(.emailAlreadyInUse))
                return
            }
            
            // Create new user
            mockUsers[email] = password
            self.saveMockUsers(mockUsers)
            
            // Save user profile with phone and bus registration
            let profile = UserProfile(email: email, phone: phone, busRegistration: busRegistration)
            self.saveUserProfile(profile)
            
            // Sign in the new user
            let user = User(email: email, phone: phone, busRegistration: busRegistration)
            self.currentUser = user
            self.isAuthenticated = true
            self.authError = nil
            
            // Save authentication state
            UserDefaults.standard.set(email, forKey: self.userDefaultsKey)
            
            completion(.success(user))
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        authError = nil
        
        // Clear authentication state
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String, completion: @escaping (Result<Void, AuthError>) -> Void) {
        guard !email.isEmpty else {
            authError = "Email cannot be empty"
            completion(.failure(.invalidEmail))
            return
        }
        
        guard isValidEmail(email) else {
            authError = "Please enter a valid email address"
            completion(.failure(.invalidEmail))
            return
        }
        
        // Mock network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            let mockUsers = self.getMockUsers()
            
            if mockUsers[email] != nil {
                // User exists, simulate sending reset email
                self.authError = nil
                completion(.success(()))
            } else {
                // User doesn't exist (but we don't reveal this for security)
                // In production Firebase, this would still return success
                self.authError = nil
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Helpers
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func getMockUsers() -> [String: String] {
        if let data = UserDefaults.standard.data(forKey: mockUsersKey),
           let users = try? JSONDecoder().decode([String: String].self, from: data) {
            return users
        }
        return [:]
    }
    
    private func saveMockUsers(_ users: [String: String]) {
        if let data = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(data, forKey: mockUsersKey)
        }
    }
    
    private func getUserProfile(email: String) -> UserProfile? {
        if let data = UserDefaults.standard.data(forKey: mockUserProfilesKey),
           let profiles = try? JSONDecoder().decode([String: UserProfile].self, from: data) {
            return profiles[email]
        }
        return nil
    }
    
    private func saveUserProfile(_ profile: UserProfile) {
        var profiles = getAllUserProfiles()
        profiles[profile.email] = profile
        
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: mockUserProfilesKey)
        }
    }
    
    private func getAllUserProfiles() -> [String: UserProfile] {
        if let data = UserDefaults.standard.data(forKey: mockUserProfilesKey),
           let profiles = try? JSONDecoder().decode([String: UserProfile].self, from: data) {
            return profiles
        }
        return [:]
    }
}

// MARK: - User Profile

struct UserProfile: Codable {
    let email: String
    let phone: String
    let busRegistration: String
}

// MARK: - User Model

struct User {
    let email: String
    let phone: String
    let busRegistration: String
    
    var displayName: String {
        // Return email prefix as display name
        email.components(separatedBy: "@").first ?? email
    }
}

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case invalidEmail
    case invalidPassword
    case weakPassword
    case invalidCredentials
    case emailAlreadyInUse
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidPassword:
            return "Password cannot be empty"
        case .weakPassword:
            return "Password must be at least 4 characters"
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailAlreadyInUse:
            return "An account with this email already exists"
        case .networkError:
            return "Network error. Please check your connection"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

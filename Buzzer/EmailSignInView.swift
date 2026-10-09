//
//  EmailSignInView.swift
//  Buzzer
//
//  Shared email + password sign-in screen for Driver, Parent, and Student portals.
//  Flow:
//    1. Select school → enter email → enter password → tap Sign In
//    2. FirestoreService.fetchUserByEmail checks the account exists and reads passwordSet.
//    3a. passwordSet == true  → Auth.signIn(email, password) → dashboard via AuthManager
//    3b. passwordSet == false → navigate to PasswordSetupView for first-time setup
//

import SwiftUI
import FirebaseAuth

struct EmailSignInView: View {
    let role: UserRole
    let accentColor: Color
    let icon: String
    let title: String

    @Environment(AuthManager.self) private var authManager
    private let service = FirestoreService.shared

    // School picker
    @State private var schools: [School] = []
    @State private var selectedSchool: School? = nil
    @State private var isLoadingSchools = true

    // Form fields
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    // Navigation
    @State private var navigateToSetup = false
    @State private var setupSchoolId = ""

    // UI state
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                NavigationLink(destination: PasswordSetupView(
                    schoolId: setupSchoolId,
                    role: role,
                    accentColor: accentColor
                ), isActive: $navigateToSetup) { EmptyView() }
                // Header
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 48))
                        .foregroundColor(accentColor)
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Sign in with your email and password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                VStack(spacing: 20) {
                    // School picker
                    VStack(alignment: .leading, spacing: 8) {
                        Label("School", systemImage: "building.2.fill")
                            .font(.headline)

                        if isLoadingSchools {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else if schools.isEmpty {
                            Text("No schools found. Check your connection.")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                        } else {
                            Picker("Select your school", selection: $selectedSchool) {
                                Text("Select your school...").tag(Optional<School>.none)
                                ForEach(schools) { school in
                                    Text(school.schoolName).tag(Optional(school))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tint(.primary)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }

                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Email", systemImage: "envelope.fill")
                            .font(.headline)

                        TextField("your@email.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Password", systemImage: "lock.fill")
                            .font(.headline)

                        HStack {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .textContentType(.password)
                            .padding(.leading)

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                                    .padding(.trailing)
                            }
                        }
                        .frame(height: 50)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }

                    // Set password (left) / Forgot password (right)
                    HStack {
                        Button("Set password") {
                            guard let school = selectedSchool else {
                                errorMessage = "Please select a school first."
                                return
                            }
                            setupSchoolId = school.id ?? ""
                            navigateToSetup = true
                        }
                        .font(.subheadline)
                        .foregroundColor(accentColor)

                        Spacer()

                        Button("Forgot password?") {
                            guard let school = selectedSchool else {
                                errorMessage = "Please select a school first."
                                return
                            }
                            setupSchoolId = school.id ?? ""
                            navigateToSetup = true
                        }
                        .font(.subheadline)
                        .foregroundColor(accentColor)
                    }

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Sign In button
                    Button {
                        Task { await handleSignIn() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSignIn ? accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(!canSignIn || isLoading)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSchools() }
    }

    // MARK: - Computed

    private var canSignIn: Bool {
        selectedSchool != nil &&
        email.contains("@") &&
        password.count >= 6
    }

    // MARK: - Actions

    private func loadSchools() async {
        do {
            schools = try await service.fetchSchools()
        } catch {
            errorMessage = "Failed to load schools. Check your connection."
        }
        isLoadingSchools = false
    }

    private func handleSignIn() async {
        guard let school = selectedSchool, let schoolId = school.id else { return }
        errorMessage = nil
        isLoading = true

        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()

        do {
            // Check account exists and get passwordSet flag
            let result = try await service.fetchUserByEmail(trimmedEmail, schoolId: schoolId, role: role)

            if !result.passwordSet {
                // First-time setup — navigate to PasswordSetupView
                setupSchoolId = schoolId
                isLoading = false
                navigateToSetup = true
                return
            }

            // Account exists and password is set — sign in with Firebase Auth
            try await authManager.signInWithEmailPassword(email: trimmedEmail, password: password)
            // AuthManager's auth state listener will resolve the role and update UI
        } catch let error as NSError {
            if error.domain == "Auth" && error.code == 404 {
                errorMessage = error.localizedDescription
            } else if (error as NSError).code == AuthErrorCode.wrongPassword.rawValue ||
                      (error as NSError).code == AuthErrorCode.invalidCredential.rawValue {
                errorMessage = "Incorrect password. Please try again."
            } else if (error as NSError).code == AuthErrorCode.userNotFound.rawValue {
                // Firebase Auth account not yet created — password may not be set
                errorMessage = "No sign-in account found. Please set up your password first."
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}

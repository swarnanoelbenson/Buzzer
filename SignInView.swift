//
//  SignInView.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//

import SwiftUI

struct SignInView: View {
    @StateObject private var authManager = FirebaseAuthManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var phone = ""
    @State private var busRegistration = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var showForgotPassword = false
    @State private var isLoading = false
    
    // Validation states
    @State private var emailError: String?
    @State private var phoneError: String?
    @State private var busRegoError: String?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, phone, busRegistration
    }
    
    // Check if all fields are valid for sign up
    private var isSignUpFormValid: Bool {
        guard isSignUp else { return true }
        return email.isValidEmail && 
               phone.isValidAustralianPhone && 
               busRegistration.isValidBusRego &&
               !password.isEmpty &&
               emailError == nil &&
               phoneError == nil &&
               busRegoError == nil
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.accentColor.opacity(0.1), Color.accentColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    
                    Spacer(minLength: 60)
                    
                    // Logo
                    BuzzerLogo(size: 120)
                        .accessibilityLabel("Buzzer app logo")
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Welcome to Buzzer")
                            .font(.system(size: 28, weight: .bold))
                            .accessibilityAddTraits(.isHeader)
                        
                        Text("Bus Attendance Tracking")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                    
                    // Form
                    VStack(spacing: 20) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 18, weight: .semibold))
                                .accessibilityHidden(true)
                            
                            TextField("email@example.com", text: $email)
                                .textFieldStyle(AccessibleTextFieldStyle())
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .focused($focusedField, equals: .email)
                                .accessibilityLabel("Email address")
                                .accessibilityHint("Enter your email address")
                                .onChange(of: email) { newValue in
                                    if isSignUp && !newValue.isEmpty {
                                        if !newValue.isValidEmail {
                                            emailError = "Invalid email format"
                                        } else {
                                            emailError = nil
                                        }
                                    } else {
                                        emailError = nil
                                    }
                                }
                            
                            if let emailError = emailError {
                                Text(emailError)
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                    .accessibilityLabel("Email error: \(emailError)")
                            }
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 18, weight: .semibold))
                                .accessibilityHidden(true)
                            
                            SecureField("Minimum 4 characters", text: $password)
                                .textFieldStyle(AccessibleTextFieldStyle())
                                .textContentType(isSignUp ? .newPassword : .password)
                                .focused($focusedField, equals: .password)
                                .accessibilityLabel("Password")
                                .accessibilityHint("Enter your password, minimum 4 characters")
                        }
                        
                        // Phone number field (signup only)
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phone Number")
                                    .font(.system(size: 18, weight: .semibold))
                                    .accessibilityHidden(true)
                                
                                HStack(spacing: 8) {
                                    Text("04-")
                                        .font(.system(size: 18))
                                        .padding(.leading, 16)
                                        .foregroundColor(.primary)
                                    
                                    TextField("123456789", text: $phone)
                                        .font(.system(size: 18))
                                        .padding(.vertical)
                                        .keyboardType(.numberPad)
                                        .focused($focusedField, equals: .phone)
                                        .accessibilityLabel("Phone number")
                                        .accessibilityHint("Enter 9 digits for your phone number")
                                        .onChange(of: phone) { newValue in
                                            // Limit to 9 digits
                                            let filtered = newValue.filter { $0.isNumber }
                                            if filtered.count > 9 {
                                                phone = String(filtered.prefix(9))
                                            } else {
                                                phone = filtered
                                            }
                                            
                                            // Validate
                                            if !phone.isEmpty {
                                                if !phone.isValidAustralianPhone {
                                                    phoneError = "Must be exactly 9 digits"
                                                } else {
                                                    phoneError = nil
                                                }
                                            } else {
                                                phoneError = nil
                                            }
                                        }
                                }
                                .frame(height: 60)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                )
                                
                                if let phoneError = phoneError {
                                    Text(phoneError)
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                        .accessibilityLabel("Phone error: \(phoneError)")
                                }
                            }
                        }
                        
                        // Bus registration field (signup only)
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bus Registration")
                                    .font(.system(size: 18, weight: .semibold))
                                    .accessibilityHidden(true)
                                
                                TextField("BS08CA", text: $busRegistration)
                                    .textFieldStyle(AccessibleTextFieldStyle())
                                    .autocapitalization(.allCharacters)
                                    .focused($focusedField, equals: .busRegistration)
                                    .accessibilityLabel("Bus registration")
                                    .accessibilityHint("Enter 6 alphanumeric characters for your bus registration")
                                    .onChange(of: busRegistration) { newValue in
                                        // Limit to 6 characters
                                        if newValue.count > 6 {
                                            busRegistration = String(newValue.prefix(6))
                                        }
                                        
                                        // Validate
                                        if !busRegistration.isEmpty {
                                            if !busRegistration.isValidBusRego {
                                                busRegoError = "Must be exactly 6 alphanumeric characters"
                                            } else {
                                                busRegoError = nil
                                            }
                                        } else {
                                            busRegoError = nil
                                        }
                                    }
                                
                                if let busRegoError = busRegoError {
                                    Text(busRegoError)
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                        .accessibilityLabel("Bus registration error: \(busRegoError)")
                                }
                            }
                        }
                        
                        // Forgot password (sign in only)
                        if !isSignUp {
                            Button {
                                showForgotPassword = true
                            } label: {
                                Text("Forgot Password?")
                                    .font(.system(size: 16))
                                    .foregroundColor(.accentColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .accessibilityHint("Reset your password")
                        }
                        
                        // Sign In/Sign Up button
                        Button {
                            authenticate()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(isSignUp ? "Sign Up" : "Sign In")
                                        .font(.system(size: 22, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 70) // Accessibility: 70pt height
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty || (isSignUp && !isSignUpFormValid))
                        .accessibilityLabel(isSignUp ? "Sign up" : "Sign in")
                        .accessibilityHint(isSignUp ? "Create a new account" : "Sign in to your account")
                        
                        // Toggle between sign in and sign up
                        Button {
                            withAnimation {
                                isSignUp.toggle()
                                authManager.authError = nil
                                // Clear validation errors
                                emailError = nil
                                phoneError = nil
                                busRegoError = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                
                                Text(isSignUp ? "Sign In" : "Sign Up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.top, 8)
                        .accessibilityLabel(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 60)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                authManager.authError = nil
            }
        } message: {
            Text(authManager.authError ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .onChange(of: authManager.authError) { error in
            if error != nil {
                showError = true
            }
        }
    }
    
    // MARK: - Authentication
    
    private func authenticate() {
        focusedField = nil // Dismiss keyboard
        isLoading = true
        
        if isSignUp {
            authManager.signUp(email: email, password: password, phone: phone, busRegistration: busRegistration) { result in
                isLoading = false
                switch result {
                case .success:
                    // Authentication state will update automatically
                    break
                case .failure:
                    // Error will be shown via alert
                    break
                }
            }
        } else {
            authManager.signIn(email: email, password: password) { result in
                isLoading = false
                switch result {
                case .success:
                    // Authentication state will update automatically
                    break
                case .failure:
                    // Error will be shown via alert
                    break
                }
            }
        }
    }
}

// MARK: - Accessible Text Field Style

struct AccessibleTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 18)) // Minimum 18pt for accessibility
            .padding()
            .frame(height: 60) // Large touch target
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = FirebaseAuthManager.shared
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                
                Image(systemName: "lock.rotation")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .padding(.top, 40)
                    .accessibilityHidden(true)
                
                Text("Reset Password")
                    .font(.system(size: 24, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                
                Text("Enter your email address and we'll send you instructions to reset your password.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(size: 18, weight: .semibold))
                        .accessibilityHidden(true)
                    
                    TextField("email@example.com", text: $email)
                        .textFieldStyle(AccessibleTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .accessibilityLabel("Email address")
                }
                .padding(.horizontal, 32)
                
                Button {
                    resetPassword()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Reset Instructions")
                                .font(.system(size: 20, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(isLoading || email.isEmpty)
                .padding(.horizontal, 32)
                .accessibilityLabel("Send password reset instructions")
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 18))
                }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Password reset instructions have been sent to \(email)")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    authManager.authError = nil
                }
            } message: {
                Text(authManager.authError ?? "An unknown error occurred")
            }
        }
    }
    
    private func resetPassword() {
        isLoading = true
        
        authManager.resetPassword(email: email) { result in
            isLoading = false
            
            switch result {
            case .success:
                showSuccess = true
            case .failure:
                showError = true
            }
        }
    }
}

#Preview("Sign In") {
    SignInView()
}

#Preview("Forgot Password") {
    ForgotPasswordView()
}

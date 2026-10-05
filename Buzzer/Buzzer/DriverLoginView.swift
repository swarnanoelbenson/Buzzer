//
//  DriverLoginView.swift
//  Buzzer
//
//  Driver login: select name from dropdown, verify full phone number, receive OTP.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct DriverLoginView: View {
    @Environment(AuthManager.self) private var authManager

    // Step 1 state
    @State private var drivers: [DriverListItem] = []
    @State private var selectedDriver: DriverListItem? = nil
    @State private var phoneNumber: String = ""
    @State private var isLoadingDrivers = true

    // Step 2 state (OTP)
    @State private var verificationID: String? = nil
    @State private var otpCode: String = ""
    @State private var isOTPSent = false

    // UI state
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var rememberMe = false

    private let db = Firestore.db

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    Text("Driver Login")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Select your name and verify your identity")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                if !isOTPSent {
                    // MARK: Step 1 — Identity Verification
                    VStack(spacing: 20) {
                        // Name dropdown
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Your Name", systemImage: "person.fill")
                                .font(.headline)

                            if isLoadingDrivers {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else if drivers.isEmpty {
                                Text("No drivers found. Seed demo data first.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            } else {
                                // Picker with .menu style is more reliable than Menu in SwiftUI
                                HStack {
                                    Picker("Select your name", selection: $selectedDriver) {
                                        Text("Select your name...").tag(Optional<DriverListItem>.none)
                                        ForEach(drivers) { driver in
                                            Text(driver.name).tag(Optional(driver))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .tint(.primary)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }

                        // Full phone number
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Your Phone Number", systemImage: "phone.fill")
                                .font(.headline)

                            TextField("e.g. 0412 345 678", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)

                            Text("Enter the number registered with your school.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Error
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Send OTP button
                        Button {
                            Task { await handleSendOTP() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Send OTP")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSendOTP ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(!canSendOTP || isLoading)
                    }
                    .padding(.horizontal, 24)

                } else {
                    // MARK: Step 2 — OTP Entry
                    VStack(spacing: 20) {
                        Text("Enter the OTP sent to your phone")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        TextField("6-digit OTP", text: $otpCode)
                            .keyboardType(.numberPad)
                            .font(.system(size: 24, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .onChange(of: otpCode) { _, newValue in
                                if newValue.count > 6 {
                                    otpCode = String(newValue.prefix(6))
                                }
                            }

                        Toggle("Remember me for 30 days", isOn: $rememberMe)
                            .padding(.horizontal, 4)

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }

                        Button {
                            Task { await handleVerifyOTP() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Verify & Login")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(otpCode.count == 6 ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(otpCode.count < 6 || isLoading)

                        Button("Use a different name") {
                            isOTPSent = false
                            otpCode = ""
                            verificationID = nil
                            errorMessage = nil
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDrivers() }
    }

    // MARK: - Computed

    private var canSendOTP: Bool {
        selectedDriver != nil && phoneNumber.filter(\.isNumber).count >= 8
    }

    // MARK: - Actions

    private func loadDrivers() async {
        do {
            let snapshot = try await db.collection("drivers").getDocuments()
            drivers = snapshot.documents.compactMap { doc in
                guard let name = doc.data()["name"] as? String else { return nil }
                return DriverListItem(id: doc.documentID, name: name)
            }.sorted { $0.name < $1.name }
        } catch {
            errorMessage = "Failed to load drivers. Check your connection."
        }
        isLoadingDrivers = false
    }

    private func handleSendOTP() async {
        guard let driver = selectedDriver else { return }
        errorMessage = nil
        isLoading = true

        do {
            // Fetch driver phone from Firestore and verify full number
            let doc = try await db.collection("drivers").document(driver.id).getDocument()
            guard let storedPhone = doc.data()?["phone"] as? String else {
                errorMessage = "Driver phone not found."
                isLoading = false
                return
            }

            // Normalise both numbers to digits only for comparison
            let enteredDigits = phoneNumber.filter(\.isNumber)
            let storedDigits = storedPhone.filter(\.isNumber)

            // Compare last 9 digits to handle +61 vs 0 prefix differences (Australian numbers)
            let enteredSuffix = String(enteredDigits.suffix(9))
            let storedSuffix = String(storedDigits.suffix(9))

            guard enteredSuffix == storedSuffix else {
                errorMessage = "Phone number does not match our records. Please try again."
                isLoading = false
                return
            }

            // On simulator, phone auth hangs (no APNs). Use instant bypass instead.
            #if targetEnvironment(simulator)
            verificationID = "SIMULATOR_BYPASS"
            isOTPSent = true
            #else
            // Send OTP with a 15s timeout on real device
            let vid = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await self.authManager.sendOTP(to: storedPhone)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(15))
                    throw NSError(domain: "OTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "OTP request timed out. Check your network."])
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            verificationID = vid
            isOTPSent = true
            #endif
        } catch {
            errorMessage = "Failed to send OTP: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func handleVerifyOTP() async {
        guard let vid = verificationID else { return }
        errorMessage = nil
        isLoading = true

        #if targetEnvironment(simulator)
        // Simulator bypass: sign in using the driver's Firestore doc ID as a
        // fake custom token isn't possible, so we use email/password fallback.
        // The driver doc uses a fixed ID — sign in with a synthetic email.
        if vid == "SIMULATOR_BYPASS", let driver = selectedDriver {
            do {
                let email = "\(driver.id)@busmate-driver.app"
                // Create account if needed, then sign in
                do {
                    try await authManager.signInParent(email: email, password: "driver-simulator-bypass")
                } catch {
                    _ = try await Auth.auth().createUser(withEmail: email, password: "driver-simulator-bypass")
                    // Write driver role doc so AuthManager resolves as driver
                    try await Firestore.db.collection("drivers").document(
                        Auth.auth().currentUser?.uid ?? ""
                    ).setData(["simulatorBypass": true, "linkedDriverId": driver.id], merge: true)
                    try await authManager.signInParent(email: email, password: "driver-simulator-bypass")
                }
            } catch {
                errorMessage = "Simulator login failed: \(error.localizedDescription)"
            }
            isLoading = false
            return
        }
        #endif

        do {
            try await authManager.verifyOTP(verificationID: vid, code: otpCode)
        } catch {
            errorMessage = "Invalid OTP. Please try again."
        }
        isLoading = false
    }
}

// MARK: - Supporting Model

struct DriverListItem: Identifiable, Hashable {
    let id: String
    let name: String
}

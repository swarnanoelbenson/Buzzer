//
//  DeveloperMenuView.swift
//  Buzzer
//
//  Accessible from the Login Selection screen (bottom of screen, dev-only button).
//  Remove or hide before App Store submission.
//

import SwiftUI

struct DeveloperMenuView: View {
    @State private var isSeeding = false
    @State private var resultMessage: String? = nil
    @State private var isSuccess = false

    var body: some View {
        NavigationStack {
            List {
                Section("Demo Data") {
                    Button {
                        Task { await seedDemoData() }
                    } label: {
                        HStack {
                            Label("Seed Demo Data", systemImage: "wand.and.stars")
                            Spacer()
                            if isSeeding { ProgressView() }
                        }
                    }
                    .disabled(isSeeding)

                    if let msg = resultMessage {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isSuccess ? .green : .red)
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(isSuccess ? .green : .red)
                        }
                    }
                }

                Section("Demo Credentials") {
                    CredentialRow(role: "Driver", label: "John Mitchell", detail: "Phone: +61412345001 → OTP: 123001")
                    CredentialRow(role: "Driver", label: "Sarah Thompson", detail: "Phone: +61412345002 → OTP: 123002")
                    CredentialRow(role: "Driver", label: "David Nguyen", detail: "Phone: +61412345003 → OTP: 123003")
                    CredentialRow(role: "Parent", label: "parent.emma", detail: "Password: Demo@1234 (Liam's mother)")
                    CredentialRow(role: "Parent", label: "parent.james", detail: "Password: Demo@1234 (Liam's father)")
                    CredentialRow(role: "Parent", label: "parent.sofia", detail: "Password: Demo@1234 (Mia & Noah's mother)")
                }

                Section("Firebase Console Steps") {
                    Text("To enable OTP test numbers:\n1. Firebase Console → Authentication\n2. Sign-in method → Phone\n3. Phone numbers for testing\n4. Add each +6141234500X with OTP 12300X")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Developer Menu")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func seedDemoData() async {
        isSeeding = true
        resultMessage = nil
        do {
            try await DemoSeeder.shared.seedAll()
            resultMessage = "Demo data seeded successfully."
            isSuccess = true
        } catch {
            resultMessage = "Failed: \(error.localizedDescription)"
            isSuccess = false
        }
        isSeeding = false
    }
}

// MARK: - Credential Row

struct CredentialRow: View {
    let role: String
    let label: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(role)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(role == "Driver" ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(role == "Driver" ? .blue : .orange)
                    .clipShape(Capsule())
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

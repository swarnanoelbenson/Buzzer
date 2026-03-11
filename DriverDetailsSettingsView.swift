//
//  DriverDetailsSettingsView.swift
//  Buzzer
//
//  Created by Noel Benson on 11/3/2026.
//

import SwiftUI

/// Optional settings view for displaying and managing driver details
/// Add this to your settings/profile screen if you want users to view or reset their driver information
struct DriverDetailsSettingsView: View {
    @EnvironmentObject var driverManager: DriverManager
    @State private var showResetConfirmation = false
    
    var body: some View {
        List {
            if let driver = driverManager.driverDetails {
                driverInfoSection(driver)
                resetSection
            } else {
                emptyStateSection
            }
        }
        .navigationTitle("Driver Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Reset Driver Details?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset and Re-enter Details", role: .destructive) {
                driverManager.clearDriverDetails()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will clear your driver information. You'll need to enter it again when you restart the app.")
        }
    }
    
    // MARK: - View Sections
    
    private func driverInfoSection(_ driver: DriverDetails) -> some View {
        Section {
            LabeledContent {
                Text(driver.name)
                    .foregroundColor(.primary)
            } label: {
                Label("Name", systemImage: "person.fill")
                    .foregroundColor(.blue)
            }
            
            LabeledContent {
                Text(driver.busRego)
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)
            } label: {
                Label("Bus Registration", systemImage: "bus.fill")
                    .foregroundColor(.orange)
            }
            
            LabeledContent {
                Text(driver.phoneNo)
                    .foregroundColor(.primary)
            } label: {
                Label("Phone", systemImage: "phone.fill")
                    .foregroundColor(.green)
            }
            
            LabeledContent {
                Text(driver.email)
                    .foregroundColor(.primary)
            } label: {
                Label("Email", systemImage: "envelope.fill")
                    .foregroundColor(.purple)
            }
        } header: {
            Text("Driver Information")
        } footer: {
            Text("This information appears in attendance reports and is used for email delivery.")
                .font(.caption)
        }
    }
    
    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("Reset Driver Details", systemImage: "arrow.counterclockwise")
                    Spacer()
                }
            }
        } footer: {
            Text("Resetting will clear your saved driver information. You'll be asked to enter it again when you restart the app.")
                .font(.caption)
        }
    }
    
    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("No Driver Details Found")
                    .font(.headline)
                
                Text("Please restart the app to complete driver setup.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }
}

#Preview {
    NavigationView {
        DriverDetailsSettingsView()
            .environmentObject({
                let manager = DriverManager.shared
                // Simulate saved driver details for preview
                manager.saveDriverDetails(DriverDetails(
                    name: "John Smith",
                    busRego: "ABC123",
                    phoneNo: "123456789",
                    email: "john.smith@example.com"
                ))
                return manager
            }())
    }
}

#Preview("Empty State") {
    NavigationView {
        DriverDetailsSettingsView()
            .environmentObject({
                let manager = DriverManager.shared
                manager.clearDriverDetails()
                return manager
            }())
    }
}

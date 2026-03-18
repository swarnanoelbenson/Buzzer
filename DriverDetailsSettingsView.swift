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
    @EnvironmentObject var dataManager: DataManager
    @State private var showDeleteConfirmation = false
    
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
        .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete & Reset", role: .destructive) {
                performFullReset()
            }
        } message: {
            Text("This will delete all driver details, all lists, and all attendance records. This action cannot be undone.")
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
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("Delete & Reset", systemImage: "trash.fill")
                    Spacer()
                }
            }
        } footer: {
            Text("This will delete all driver details, all attendee lists, and all attendance records. This action cannot be undone.")
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
    
    // MARK: - Helper Methods
    
    private func performFullReset() {
        print("🗑️ Starting full app reset...")
        
        // Delete all Core Data records (lists, attendees, sessions, records)
        dataManager.deleteAllData()
        
        // Delete driver details from Keychain
        driverManager.clearDriverDetails()
        
        print("✅ Full reset completed - app will return to setup screen")
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
            .environmentObject(DataManager(persistenceController: .shared))
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
            .environmentObject(DataManager(persistenceController: .shared))
    }
}

//
//  ProfileView.swift
//  Buzzer
//
//  Created by Noel Benson on 5/3/2026.
//  Updated by Assistant on 11/3/2026.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var driverManager: DriverManager
    @EnvironmentObject var dataManager: DataManager
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Profile Header
                    VStack(spacing: 16) {
                        // Profile Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Profile picture")
                        
                        // Driver Name
                        Text(driverManager.driverDetails?.name ?? "Driver")
                            .font(.system(size: 28, weight: .bold))
                            .accessibilityAddTraits(.isHeader)
                        
                        Text("Bus Driver")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // Profile Details Card
                    if let driver = driverManager.driverDetails {
                        VStack(spacing: 0) {
                            // Email
                            ProfileDetailRow(
                                icon: "envelope.fill",
                                title: "Email",
                                value: driver.email,
                                isFirst: true
                            )
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            // Phone
                            ProfileDetailRow(
                                icon: "phone.fill",
                                title: "Phone",
                                value: driver.phoneNo
                            )
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            // Bus Registration
                            ProfileDetailRow(
                                icon: "bus.fill",
                                title: "Bus Registration",
                                value: driver.busRego,
                                isLast: true
                            )
                        }
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }
                    
                    // App Information
                    VStack(spacing: 12) {
                        Text("Buzzer")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Bus Attendance Tracking")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("Version 1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    Spacer(minLength: 30)
                    
                    // Delete & Reset Button
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("Delete & Reset")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .foregroundColor(.white)
                        .background(Color.red)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .accessibilityLabel("Delete all data and reset app")
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete & Reset", role: .destructive) {
                    performFullReset()
                }
            } message: {
                Text("This will delete all driver details, all lists, and all attendance records. This action cannot be undone.")
            }
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
        
        // Dismiss will automatically trigger return to DriverSetupView
        // because driverManager.isSetupComplete is now false
        dismiss()
    }
}

// MARK: - Profile Detail Row

struct ProfileDetailRow: View {
    let icon: String
    let title: String
    let value: String
    var isFirst: Bool = false
    var isLast: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }
            .accessibilityHidden(true)
            
            // Title and Value
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(DriverManager.shared)
        .environmentObject(DataManager(persistenceController: .shared))
}

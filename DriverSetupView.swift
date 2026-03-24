//
//  DriverSetupView.swift
//  Buzzer
//
//  Created by Noel Benson on 11/3/2026.
//

import SwiftUI

struct DriverSetupView: View {
    @EnvironmentObject var driverManager: DriverManager
    @EnvironmentObject var dataManager: DataManager

    @State private var name: String = ""
    @State private var busRego: String = ""
    @State private var phoneNo: String = ""
    @State private var email: String = ""

    @State private var showValidationErrors: Bool = false
    @State private var validationMessages: [String] = []
    @State private var showDemoConfirmation: Bool = false

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name, busRego, phoneNo, email
    }

    var body: some View {
        NavigationView {
            Form {
                headerSection
                nameSection
                busRegoSection
                phoneSection
                emailSection

                if showValidationErrors && !validationMessages.isEmpty {
                    validationErrorSection
                }

                submitButtonSection
                demoModeSection
            }
            .navigationTitle("Driver Setup")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .alert("Enter Demo Mode?", isPresented: $showDemoConfirmation) {
                Button("Enter Demo Mode", role: .none) {
                    DemoModeManager.shared.enableDemoMode(dataManager: dataManager)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Demo Mode pre-loads sample driver details, 10 passengers, attendance records, and passenger notes so you can explore all features immediately. All data can be cleared from Settings.")
            }
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .padding(.top, 8)
                
                Text("Welcome to Buzzer")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Please enter your driver details to get started. This information will be used in attendance reports.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }
    
    private var nameSection: some View {
        Section {
            HStack {
                Label("Name", systemImage: "person.fill")
                    .foregroundColor(.blue)
                    .frame(width: 100, alignment: .leading)
                
                TextField("Full Name", text: $name)
                    .focused($focusedField, equals: .name)
                    .textContentType(.name)
                    .autocapitalization(.words)
            }
        } header: {
            Text("Driver Information")
        } footer: {
            Text("Your full name as it appears on official documents")
                .font(.caption)
        }
    }
    
    private var busRegoSection: some View {
        Section {
            HStack {
                Label("Bus Rego", systemImage: "bus.fill")
                    .foregroundColor(.orange)
                    .frame(width: 100, alignment: .leading)
                
                TextField("ABC123", text: $busRego)
                    .focused($focusedField, equals: .busRego)
                    .textContentType(.none)
                    .autocapitalization(.allCharacters)
                    .onChange(of: busRego) { newValue in
                        // Limit to 6 characters
                        if newValue.count > 6 {
                            busRego = String(newValue.prefix(6))
                        }
                    }
            }
        } footer: {
            Text("6 alphanumeric characters (letters and numbers only)")
                .font(.caption)
        }
    }
    
    private var phoneSection: some View {
        Section {
            HStack {
                Label("Phone", systemImage: "phone.fill")
                    .foregroundColor(.green)
                    .frame(width: 100, alignment: .leading)
                
                TextField("04xx xxx xxx", text: $phoneNo)
                    .focused($focusedField, equals: .phoneNo)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.numberPad)
                    .onChange(of: phoneNo) { newValue in
                        // Filter to digits only and limit to 10
                        let filtered = newValue.filter { $0.isNumber }
                        phoneNo = String(filtered.prefix(10))
                    }
            }
        } footer: {
            Text("10 digits — mobile (04xx/05xx) or landline (02/03/07/08 + 8 digits)")
                .font(.caption)
        }
    }
    
    private var emailSection: some View {
        Section {
            HStack {
                Label("Email", systemImage: "envelope.fill")
                    .foregroundColor(.purple)
                    .frame(width: 100, alignment: .leading)
                
                TextField("driver@example.com", text: $email)
                    .focused($focusedField, equals: .email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
        } footer: {
            Text("Reports will be sent to this email address")
                .font(.caption)
        }
    }
    
    private var validationErrorSection: some View {
        Section {
            ForEach(validationMessages, id: \.self) { message in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
        } header: {
            Text("Validation Errors")
        }
    }
    
    private var submitButtonSection: some View {
        Section {
            Button(action: saveDriverDetails) {
                HStack {
                    Spacer()
                    Text("Complete Setup")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .listRowBackground(Color.accentColor)
        }
    }

    private var demoModeSection: some View {
        Section {
            Button(action: { showDemoConfirmation = true }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enter Demo Mode")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text("Pre-loads sample data for app review")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("App Review")
        } footer: {
            Text("Demo Mode loads a driver, 10 passengers, this week's attendance sessions, and sample notes so reviewers can explore all features without manual data entry.")
                .font(.caption)
        }
    }
    
    // MARK: - Validation & Save
    
    private func saveDriverDetails() {
        focusedField = nil
        
        validationMessages.removeAll()
        showValidationErrors = false
        
        // Validate all fields
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessages.append("Name is required")
        }
        
        if !DriverManager.isValidBusRego(busRego) {
            validationMessages.append("Bus Rego must be exactly 6 alphanumeric characters")
        }
        
        if !DriverManager.isValidPhoneNumber(phoneNo) {
            validationMessages.append("Phone must be 10 digits starting with 04, 05, 02, 03, 07, or 08")
        }
        
        if !DriverManager.isValidEmail(email) {
            validationMessages.append("Email address is invalid")
        }
        
        // Show errors if any
        if !validationMessages.isEmpty {
            showValidationErrors = true
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            return
        }
        
        // All validation passed - save details
        let details = DriverDetails(
            name: name.trimmingCharacters(in: .whitespaces),
            busRego: busRego.uppercased(),
            phoneNo: phoneNo,
            email: email.lowercased()
        )
        
        // Success haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Save to DriverManager
        driverManager.saveDriverDetails(details)
    }
}

#Preview {
    DriverSetupView()
        .environmentObject(DriverManager.shared)
}

//
//  DriverManager.swift
//  Buzzer
//
//  Created by Noel Benson on 11/3/2026.
//

import Foundation
import Combine

class DriverManager: ObservableObject {
    static let shared = DriverManager()
    
    @Published private(set) var driverDetails: DriverDetails?
    @Published private(set) var isSetupComplete: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let driverDetailsKey = "driverDetails"
    private let setupCompleteKey = "driverSetupComplete"
    
    private init() {
        loadDriverDetails()
    }
    
    // MARK: - Public Methods
    
    func saveDriverDetails(_ details: DriverDetails) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(details) {
            userDefaults.set(encoded, forKey: driverDetailsKey)
            userDefaults.set(true, forKey: setupCompleteKey)
            userDefaults.synchronize()
            
            self.driverDetails = details
            self.isSetupComplete = true
            
            print("✅ Driver details saved successfully")
            print("   Name: \(details.name)")
            print("   Bus Rego: \(details.busRego)")
            print("   Phone: \(details.phoneNo)")
            print("   Email: \(details.email)")
        }
    }
    
    func loadDriverDetails() {
        isSetupComplete = userDefaults.bool(forKey: setupCompleteKey)
        
        if let savedData = userDefaults.data(forKey: driverDetailsKey) {
            let decoder = JSONDecoder()
            if let loadedDetails = try? decoder.decode(DriverDetails.self, from: savedData) {
                self.driverDetails = loadedDetails
                print("✅ Driver details loaded successfully")
            }
        } else {
            print("ℹ️ No driver details found in UserDefaults")
        }
    }
    
    func clearDriverDetails() {
        userDefaults.removeObject(forKey: driverDetailsKey)
        userDefaults.removeObject(forKey: setupCompleteKey)
        userDefaults.synchronize()
        
        self.driverDetails = nil
        self.isSetupComplete = false
        
        print("🗑️ Driver details cleared")
    }
    
    // MARK: - Validation Helpers
    
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    static func isValidPhoneNumber(_ phone: String) -> Bool {
        // Must be exactly 9 digits
        let phoneRegex = "^[0-9]{9}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }
    
    static func isValidBusRego(_ busRego: String) -> Bool {
        // Must be exactly 6 alphanumeric characters
        let regoRegex = "^[A-Za-z0-9]{6}$"
        let regoPredicate = NSPredicate(format: "SELF MATCHES %@", regoRegex)
        return regoPredicate.evaluate(with: busRego)
    }
}

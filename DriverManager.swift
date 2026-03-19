//
//  DriverManager.swift
//  Buzzer
//
//  Created by Noel Benson on 11/3/2026.
//

import Foundation
import Combine
import Security

class DriverManager: ObservableObject {
    static let shared = DriverManager()
    
    @Published private(set) var driverDetails: DriverDetails?
    @Published private(set) var isSetupComplete: Bool = false
    
    private let driverDetailsKey = "driverDetails"
    private let setupCompleteKey = "driverSetupComplete"
    private let keychainService = "com.buzzer.driverManager"
    
    private init() {
        loadDriverDetails()
    }
    
    // MARK: - Public Methods
    
    func saveDriverDetails(_ details: DriverDetails) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(details) {
            saveToKeychain(data: encoded, key: driverDetailsKey)
            saveToKeychain(data: Data([1]), key: setupCompleteKey) // Store boolean as data
            
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
        if let setupData = retrieveFromKeychain(key: setupCompleteKey) {
            isSetupComplete = !setupData.isEmpty
        }
        
        if let savedData = retrieveFromKeychain(key: driverDetailsKey) {
            let decoder = JSONDecoder()
            if let loadedDetails = try? decoder.decode(DriverDetails.self, from: savedData) {
                self.driverDetails = loadedDetails
                print("✅ Driver details loaded successfully")
            }
        } else {
            print("ℹ️ No driver details found in Keychain")
        }
    }
    
    func clearDriverDetails() {
        deleteFromKeychain(key: driverDetailsKey)
        deleteFromKeychain(key: setupCompleteKey)
        
        self.driverDetails = nil
        self.isSetupComplete = false
        
        print("🗑️ Driver details cleared")
    }
    
    // MARK: - Keychain Methods
    
    private func saveToKeychain(data: Data, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Saved \(key) to Keychain")
        } else {
            print("❌ Failed to save \(key) to Keychain: \(status)")
        }
    }
    
    private func retrieveFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        } else {
            return nil
        }
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ Deleted \(key) from Keychain")
        } else {
            print("❌ Failed to delete \(key) from Keychain: \(status)")
        }
    }
    
    // MARK: - Validation Helpers
    
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    static func isValidPhoneNumber(_ phone: String) -> Bool {
        // Must be 10 digits and start with a valid Australian prefix:
        // Mobile:   04xx or 05xx
        // Landline: 02, 03, 07, 08 (NSW/ACT, VIC/TAS, QLD, WA/SA/NT)
        let phoneRegex = "^(04|05|02|03|07|08)[0-9]{8}$"
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

//
//  SimpleValidationTests.swift
//  BuzzerTests
//
//  A minimal test file to verify your test target is working
//  If this runs successfully, you can add the other test files
//

import XCTest
@testable import Buzzer

/// Simple test class to verify test setup is working
final class SimpleValidationTests: XCTestCase {
    
    // MARK: - Setup Test
    
    func testSetupWorking() {
        // If this test runs, your test target is configured correctly!
        XCTAssertTrue(true, "Test setup is working! ✅")
    }
    
    // MARK: - Email Validation Tests
    
    func testValidEmail() {
        let validEmail = "test@example.com"
        XCTAssertTrue(validEmail.isValidEmail, "Valid email should pass")
    }
    
    func testInvalidEmail() {
        let invalidEmail = "notanemail"
        XCTAssertFalse(invalidEmail.isValidEmail, "Invalid email should fail")
    }
    
    // MARK: - Phone Validation Tests
    
    func testValidPhone() {
        let validPhone = "123456789" // 9 digits
        XCTAssertTrue(validPhone.isValidAustralianPhone, "Valid 9-digit phone should pass")
    }
    
    func testInvalidPhone() {
        let invalidPhone = "12345" // Too short
        XCTAssertFalse(invalidPhone.isValidAustralianPhone, "Short phone should fail")
    }
    
    // MARK: - Bus Rego Validation Tests
    
    func testValidBusRego() {
        let validRego = "ABC123" // 6 alphanumeric
        XCTAssertTrue(validRego.isValidBusRego, "Valid 6-char rego should pass")
    }
    
    func testInvalidBusRego() {
        let invalidRego = "ABC" // Too short
        XCTAssertFalse(invalidRego.isValidBusRego, "Short rego should fail")
    }
    
    // MARK: - DriverDetails Tests
    
    func testDriverDetailsCreation() {
        let driver = DriverDetails(
            name: "Test Driver",
            busRego: "TEST01",
            phoneNo: "123456789",
            email: "test@example.com"
        )
        
        XCTAssertEqual(driver.name, "Test Driver")
        XCTAssertEqual(driver.busRego, "TEST01")
        XCTAssertEqual(driver.phoneNo, "123456789")
        XCTAssertEqual(driver.email, "test@example.com")
    }
    
    func testDriverDetailsEncoding() {
        let driver = DriverDetails(
            name: "Test",
            busRego: "TEST01",
            phoneNo: "123456789",
            email: "test@example.com"
        )
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(driver)
            XCTAssertNotNil(data, "Should encode successfully")
            XCTAssertGreaterThan(data.count, 0, "Encoded data should not be empty")
        } catch {
            XCTFail("Encoding failed: \(error)")
        }
    }
}

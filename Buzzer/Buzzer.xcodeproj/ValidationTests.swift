//
//  ValidationTests.swift
//  BuzzerTests
//
//  Created by Noel Benson on 16/3/2026.
//

import XCTest
@testable import Buzzer

final class ValidationTests: XCTestCase {
    
    // MARK: - Email Validation Tests
    
    func testValidEmailFormats() {
        // Valid emails should return true
        XCTAssertTrue("john@gmail.com".isValidEmail, "john@gmail.com should be valid")
        XCTAssertTrue("sarah.smith@company.com.au".isValidEmail, "sarah.smith@company.com.au should be valid")
        XCTAssertTrue("driver123@yahoo.com".isValidEmail, "driver123@yahoo.com should be valid")
        XCTAssertTrue("test.name+tag@domain.co.uk".isValidEmail, "test.name+tag@domain.co.uk should be valid")
        XCTAssertTrue("user@example.org".isValidEmail, "user@example.org should be valid")
    }
    
    func testInvalidEmailFormats() {
        // Invalid emails should return false
        XCTAssertFalse("john@gmail".isValidEmail, "john@gmail missing TLD should be invalid")
        XCTAssertFalse("john.gmail.com".isValidEmail, "john.gmail.com missing @ should be invalid")
        XCTAssertFalse("@gmail.com".isValidEmail, "@gmail.com missing local part should be invalid")
        XCTAssertFalse("".isValidEmail, "Empty string should be invalid")
        XCTAssertFalse("john@".isValidEmail, "john@ incomplete should be invalid")
    }
    
    func testEmailEdgeCases() {
        XCTAssertFalse("john@".isValidEmail, "Incomplete email should be invalid")
        XCTAssertFalse("john@.com".isValidEmail, "Email with no domain name should be invalid")
        XCTAssertTrue("a@b.co".isValidEmail, "Minimum valid email should be valid")
        XCTAssertFalse("john@@gmail.com".isValidEmail, "Email with double @ should be invalid")
        XCTAssertFalse("john @gmail.com".isValidEmail, "Email with space should be invalid")
    }
    
    // MARK: - Phone Number Validation Tests
    
    func testValidAustralianPhoneNumbers() {
        // Valid Australian phone (9 digits)
        XCTAssertTrue("123456789".isValidAustralianPhone, "9 digits should be valid")
        XCTAssertTrue("987654321".isValidAustralianPhone, "9 digits should be valid")
        XCTAssertTrue("000000000".isValidAustralianPhone, "9 zeros should be valid")
        XCTAssertTrue("555555555".isValidAustralianPhone, "9 fives should be valid")
        XCTAssertTrue("412345678".isValidAustralianPhone, "Mobile pattern should be valid")
    }
    
    func testInvalidAustralianPhoneNumbers() {
        // Invalid - wrong number of digits
        XCTAssertFalse("12345678".isValidAustralianPhone, "8 digits should be invalid")
        XCTAssertFalse("1234567890".isValidAustralianPhone, "10 digits should be invalid")
        XCTAssertFalse("1234".isValidAustralianPhone, "4 digits should be invalid")
        
        // Invalid - non-numeric
        XCTAssertFalse("12345678a".isValidAustralianPhone, "Contains letter should be invalid")
        XCTAssertFalse("123-456-789".isValidAustralianPhone, "Contains dashes should be invalid")
        XCTAssertFalse("123 456 789".isValidAustralianPhone, "Contains spaces should be invalid")
        XCTAssertFalse("(04)123456".isValidAustralianPhone, "Contains parentheses should be invalid")
        
        // Invalid - empty
        XCTAssertFalse("".isValidAustralianPhone, "Empty string should be invalid")
    }
    
    // MARK: - Bus Registration Validation Tests
    
    func testValidBusRegistration() {
        // Valid - 6 alphanumeric characters
        XCTAssertTrue("ABC123".isValidBusRego, "ABC123 should be valid")
        XCTAssertTrue("BUS001".isValidBusRego, "BUS001 should be valid")
        XCTAssertTrue("123456".isValidBusRego, "123456 should be valid")
        XCTAssertTrue("ABCDEF".isValidBusRego, "ABCDEF should be valid")
        XCTAssertTrue("aB1c2d".isValidBusRego, "Mixed case should be valid")
        XCTAssertTrue("000000".isValidBusRego, "All zeros should be valid")
    }
    
    func testInvalidBusRegistration() {
        // Invalid - wrong length
        XCTAssertFalse("ABC12".isValidBusRego, "5 chars should be invalid")
        XCTAssertFalse("ABC1234".isValidBusRego, "7 chars should be invalid")
        XCTAssertFalse("AB".isValidBusRego, "2 chars should be invalid")
        XCTAssertFalse("ABCDEFGH".isValidBusRego, "8 chars should be invalid")
        
        // Invalid - special characters
        XCTAssertFalse("ABC-12".isValidBusRego, "Contains dash should be invalid")
        XCTAssertFalse("ABC@12".isValidBusRego, "Contains @ should be invalid")
        XCTAssertFalse("ABC 12".isValidBusRego, "Contains space should be invalid")
        XCTAssertFalse("ABC.12".isValidBusRego, "Contains period should be invalid")
        
        // Invalid - empty
        XCTAssertFalse("".isValidBusRego, "Empty string should be invalid")
    }
    
    // MARK: - DriverManager Validation Tests
    
    func testDriverManagerEmailValidation() {
        XCTAssertTrue(DriverManager.isValidEmail("test@example.com"))
        XCTAssertFalse(DriverManager.isValidEmail("invalid"))
        XCTAssertFalse(DriverManager.isValidEmail(""))
    }
    
    func testDriverManagerPhoneValidation() {
        XCTAssertTrue(DriverManager.isValidPhoneNumber("123456789"))
        XCTAssertFalse(DriverManager.isValidPhoneNumber("12345678"))
        XCTAssertFalse(DriverManager.isValidPhoneNumber("abc123456"))
    }
    
    func testDriverManagerBusRegoValidation() {
        XCTAssertTrue(DriverManager.isValidBusRego("ABC123"))
        XCTAssertFalse(DriverManager.isValidBusRego("ABC12"))
        XCTAssertFalse(DriverManager.isValidBusRego("ABC-123"))
    }
}

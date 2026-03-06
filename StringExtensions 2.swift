import Foundation

extension String {
    
    // Email validation
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
    
    // Australian phone validation (9 digits only - 04- prefix is automatic)
    var isValidAustralianPhone: Bool {
        let phoneRegEx = "^[0-9]{9}$"
        let phonePred = NSPredicate(format: "SELF MATCHES %@", phoneRegEx)
        return phonePred.evaluate(with: self)
    }
    
    // Bus registration validation (6 alphanumeric characters)
    var isValidBusRego: Bool {
        let regoRegEx = "^[A-Za-z0-9]{6}$"
        let regoPred = NSPredicate(format: "SELF MATCHES %@", regoRegEx)
        return regoPred.evaluate(with: self)
    }
}

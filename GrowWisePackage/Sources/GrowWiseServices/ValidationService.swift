import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// ValidationService provides comprehensive input validation for all user inputs
public final class ValidationService: Sendable {
    
    // MARK: - Singleton
    
    public static let shared = ValidationService()
    
    // MARK: - Validation Result
    
    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let errorMessage: String?
        
        public static let valid = ValidationResult(isValid: true, errorMessage: nil)
        
        public static func invalid(_ message: String) -> ValidationResult {
            ValidationResult(isValid: false, errorMessage: message)
        }
    }
    
    // MARK: - Email Validation
    
    public func validateEmail(_ email: String) -> ValidationResult {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedEmail.isEmpty {
            return .invalid("Email is required")
        }
        
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !emailPredicate.evaluate(with: trimmedEmail) {
            return .invalid("Please enter a valid email address")
        }
        
        // Check for common typos
        let commonDomains = ["gmail.com", "yahoo.com", "outlook.com", "icloud.com", "hotmail.com"]
        let emailParts = trimmedEmail.split(separator: "@")
        if emailParts.count == 2 {
            let domain = String(emailParts[1])
            let similarDomains = ["gmial.com", "gmai.com", "yahooo.com", "outlok.com"]
            if similarDomains.contains(domain) {
                return .invalid("Please check your email domain for typos")
            }
        }
        
        return .valid
    }
    
    // MARK: - Text Validation
    
    public func validateText(_ text: String, fieldName: String, minLength: Int = 0, maxLength: Int = 500) -> ValidationResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if minLength > 0 && trimmedText.isEmpty {
            return .invalid("\(fieldName) is required")
        }
        
        if trimmedText.count < minLength {
            return .invalid("\(fieldName) must be at least \(minLength) characters")
        }
        
        if trimmedText.count > maxLength {
            return .invalid("\(fieldName) must be less than \(maxLength) characters")
        }
        
        // Check for potential SQL injection patterns
        let dangerousPatterns = ["DROP TABLE", "DELETE FROM", "INSERT INTO", "UPDATE SET", "'; --", "UNION SELECT"]
        let upperText = trimmedText.uppercased()
        for pattern in dangerousPatterns {
            if upperText.contains(pattern) {
                return .invalid("Invalid characters detected")
            }
        }
        
        return .valid
    }
    
    // MARK: - Name Validation
    
    public func validateName(_ name: String, fieldName: String = "Name") -> ValidationResult {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return .invalid("\(fieldName) is required")
        }
        
        if trimmedName.count < 2 {
            return .invalid("\(fieldName) must be at least 2 characters")
        }
        
        if trimmedName.count > 50 {
            return .invalid("\(fieldName) must be less than 50 characters")
        }
        
        // Allow letters, spaces, hyphens, and apostrophes
        let nameRegex = #"^[a-zA-Z\s\-']+$"#
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        
        if !namePredicate.evaluate(with: trimmedName) {
            return .invalid("\(fieldName) can only contain letters, spaces, hyphens, and apostrophes")
        }
        
        return .valid
    }
    
    // MARK: - Number Validation
    
    public func validateNumber(_ text: String, fieldName: String, min: Double? = nil, max: Double? = nil, allowDecimals: Bool = true) -> ValidationResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedText.isEmpty {
            return .valid // Empty is valid for optional numeric fields
        }
        
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.current
        numberFormatter.numberStyle = .decimal
        
        guard let number = numberFormatter.number(from: trimmedText)?.doubleValue else {
            return .invalid("\(fieldName) must be a valid number")
        }
        
        if !allowDecimals && number.truncatingRemainder(dividingBy: 1) != 0 {
            return .invalid("\(fieldName) must be a whole number")
        }
        
        if let min = min, number < min {
            return .invalid("\(fieldName) must be at least \(min)")
        }
        
        if let max = max, number > max {
            return .invalid("\(fieldName) must be at most \(max)")
        }
        
        return .valid
    }
    
    // MARK: - Plant Name Validation
    
    public func validatePlantName(_ name: String) -> ValidationResult {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return .invalid("Plant name is required")
        }
        
        if trimmedName.count < 2 {
            return .invalid("Plant name must be at least 2 characters")
        }
        
        if trimmedName.count > 100 {
            return .invalid("Plant name must be less than 100 characters")
        }
        
        // Allow letters, numbers, spaces, hyphens, apostrophes, and parentheses (for cultivar names)
        let plantNameRegex = #"^[a-zA-Z0-9\s\-'()\.,]+$"#
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", plantNameRegex)
        
        if !namePredicate.evaluate(with: trimmedName) {
            return .invalid("Plant name contains invalid characters")
        }
        
        return .valid
    }
    
    // MARK: - Tag Validation
    
    public func validateTag(_ tag: String) -> ValidationResult {
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedTag.isEmpty {
            return .invalid("Tag cannot be empty")
        }
        
        if trimmedTag.count > 30 {
            return .invalid("Tag must be less than 30 characters")
        }
        
        // Allow alphanumeric and basic punctuation
        let tagRegex = #"^[a-zA-Z0-9\s\-_]+$"#
        let tagPredicate = NSPredicate(format: "SELF MATCHES %@", tagRegex)
        
        if !tagPredicate.evaluate(with: trimmedTag) {
            return .invalid("Tag can only contain letters, numbers, spaces, hyphens, and underscores")
        }
        
        return .valid
    }
    
    // MARK: - Measurement Validation
    
    public func validateHeight(_ text: String) -> ValidationResult {
        return validateNumber(text, fieldName: "Height", min: 0, max: 10000, allowDecimals: true)
    }
    
    public func validateWidth(_ text: String) -> ValidationResult {
        return validateNumber(text, fieldName: "Width", min: 0, max: 10000, allowDecimals: true)
    }
    
    public func validateTemperature(_ text: String) -> ValidationResult {
        return validateNumber(text, fieldName: "Temperature", min: -50, max: 150, allowDecimals: true)
    }
    
    public func validateHumidity(_ text: String) -> ValidationResult {
        return validateNumber(text, fieldName: "Humidity", min: 0, max: 100, allowDecimals: true)
    }
    
    public func validateWaterAmount(_ text: String) -> ValidationResult {
        return validateNumber(text, fieldName: "Water amount", min: 0, max: 10000, allowDecimals: true)
    }
    
    // MARK: - Search Query Validation
    
    public func validateSearchQuery(_ query: String) -> ValidationResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedQuery.count > 100 {
            return .invalid("Search query is too long")
        }
        
        // Remove potential SQL injection attempts
        let dangerousPatterns = ["DROP", "DELETE", "INSERT", "UPDATE", "EXEC", "SCRIPT", "<script>", "</script>"]
        let upperQuery = trimmedQuery.uppercased()
        for pattern in dangerousPatterns {
            if upperQuery.contains(pattern.uppercased()) {
                return .invalid("Invalid search query")
            }
        }
        
        return .valid
    }
    
    // MARK: - Sanitization
    
    public func sanitizeInput(_ input: String) -> String {
        var sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove HTML/Script tags
        let htmlTagPattern = "<[^>]+>"
        sanitized = sanitized.replacingOccurrences(of: htmlTagPattern, with: "", options: .regularExpression)
        
        // Escape special characters
        let specialChars = [
            ("&", "&amp;"),
            ("<", "&lt;"),
            (">", "&gt;"),
            ("\"", "&quot;"),
            ("'", "&#x27;"),
            ("/", "&#x2F;")
        ]
        
        for (char, escaped) in specialChars {
            sanitized = sanitized.replacingOccurrences(of: char, with: escaped)
        }
        
        return sanitized
    }
    
    // MARK: - Batch Validation
    
    public func validateFields(_ validations: [(String, ValidationResult)]) -> (isValid: Bool, errors: [String: String]) {
        var errors: [String: String] = [:]
        var isValid = true
        
        for (fieldName, result) in validations {
            if !result.isValid {
                isValid = false
                errors[fieldName] = result.errorMessage ?? "Invalid input"
            }
        }
        
        return (isValid, errors)
    }
}

// MARK: - SwiftUI View Modifiers

public struct ValidationModifier: ViewModifier {
    let validation: () -> ValidationService.ValidationResult
    @State private var errorMessage: String?
    @State private var showError = false
    
    public func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content
                .onChange(of: showError) { _, newValue in
                    if newValue {
                        let result = validation()
                        errorMessage = result.errorMessage
                        showError = !result.isValid
                    }
                }
            
            if showError, let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
    }
}

extension View {
    public func validate(_ validation: @escaping () -> ValidationService.ValidationResult) -> some View {
        modifier(ValidationModifier(validation: validation))
    }
}

// MARK: - TextField Extensions

public struct ValidatedTextField: View {
    let title: String
    @Binding var text: String
    let validation: (String) -> ValidationService.ValidationResult
    #if canImport(UIKit)
    let keyboardType: UIKeyboardType
    #else
    let keyboardType: Int
    #endif
    
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool
    
    #if canImport(UIKit)
    public init(
        _ title: String,
        text: Binding<String>,
        validation: @escaping (String) -> ValidationService.ValidationResult,
        keyboardType: UIKeyboardType = .default
    ) {
        self.title = title
        self._text = text
        self.validation = validation
        self.keyboardType = keyboardType
    }
    #else
    public init(
        _ title: String,
        text: Binding<String>,
        validation: @escaping (String) -> ValidationService.ValidationResult,
        keyboardType: Int = 0
    ) {
        self.title = title
        self._text = text
        self.validation = validation
        self.keyboardType = keyboardType
    }
    #endif
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                #if canImport(UIKit)
                .keyboardType(keyboardType)
                #endif
                .focused($isFocused)
                .onChange(of: isFocused) { _, newValue in
                    if !newValue {
                        // Validate on focus loss
                        let result = validation(text)
                        errorMessage = result.isValid ? nil : result.errorMessage
                    }
                }
                .onChange(of: text) { _, _ in
                    // Clear error when user starts typing
                    if errorMessage != nil {
                        errorMessage = nil
                    }
                }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
    }
}
import GrowWiseServices
import SwiftUI

public struct ValidatedTextField: View {
    let title: String
    @Binding var text: String
    let validation: (String) -> ValidationService.ValidationResult
    let accessibilityId: String
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
        accessibilityId: String = "validated_text_field",
        keyboardType: UIKeyboardType = .default
    ) {
        self.title = title
        _text = text
        self.validation = validation
        self.accessibilityId = accessibilityId
        self.keyboardType = keyboardType
    }
    #else
    public init(
        _ title: String,
        text: Binding<String>,
        validation: @escaping (String) -> ValidationService.ValidationResult,
        accessibilityId: String = "validated_text_field",
        keyboardType: Int = 0
    ) {
        self.title = title
        _text = text
        self.validation = validation
        self.accessibilityId = accessibilityId
        self.keyboardType = keyboardType
    }
    #endif

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: $text)
                .accessibilityIdentifier(accessibilityId)
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

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
    }
}

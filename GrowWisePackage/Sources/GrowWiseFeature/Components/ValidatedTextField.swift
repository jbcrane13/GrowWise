import SwiftUI
import GrowWiseServices

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

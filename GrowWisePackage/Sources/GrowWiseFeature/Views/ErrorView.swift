import SwiftUI

/// Error view for displaying initialization failures
public struct ErrorView: View {
    let error: Error
    let retry: () -> Void
    
    public init(error: Error, retry: @escaping () -> Void) {
        self.error = error
        self.retry = retry
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("Failed to Load")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: retry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    ErrorView(error: NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize data service"])) {
        print("Retry tapped")
    }
}
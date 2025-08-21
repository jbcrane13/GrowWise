import SwiftUI

struct OnboardingProgressView: View {
    let currentStep: OnboardingStep
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            HStack(spacing: 4) {
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    Rectangle()
                        .fill(step.stepNumber <= currentStep.stepNumber ? Color.adaptiveGreen : Color(UIColor.quaternaryLabel))
                        .frame(height: 4)
                        .animation(.easeInOut, value: currentStep)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            
            // Step indicator
            HStack {
                Text("\(currentStep.stepNumber + 1) of \(currentStep.totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(currentStep.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach(OnboardingStep.allCases, id: \.self) { step in
            OnboardingProgressView(currentStep: step)
        }
    }
    .padding()
}
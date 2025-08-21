import SwiftUI
import UIKit

struct CompletionView: View {
    @Binding var userProfile: UserProfile
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success animation/icon
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.adaptiveGreenBackground)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(Color.adaptiveGreen.opacity(0.6))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.adaptiveGreen)
                }
                
                Text("Welcome to GrowWise!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Your garden journey starts now")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Profile summary
            VStack(spacing: 20) {
                Text("Your Profile Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    ProfileSummaryRow(
                        icon: "brain.head.profile",
                        title: "Experience Level",
                        value: userProfile.skillLevel.displayName
                    )
                    
                    if !userProfile.goals.isEmpty {
                        ProfileSummaryRow(
                            icon: "target",
                            title: "Primary Goals",
                            value: userProfile.goals.prefix(2).map(\.displayName).joined(separator: ", ")
                        )
                    }
                    
                    ProfileSummaryRow(
                        icon: "house.fill",
                        title: "Garden Type",
                        value: userProfile.gardenType.displayName
                    )
                    
                    ProfileSummaryRow(
                        icon: "square.grid.2x2",
                        title: "Space Size",
                        value: userProfile.spaceSize.displayName
                    )
                    
                    if userProfile.hasLocationPermission {
                        ProfileSummaryRow(
                            icon: "location.fill",
                            title: "Location",
                            value: "Enabled for weather & tips"
                        )
                    }
                    
                    if userProfile.hasNotificationPermission {
                        ProfileSummaryRow(
                            icon: "bell.fill",
                            title: "Notifications",
                            value: "Enabled for reminders"
                        )
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.adaptiveCardBackground)
            )
            .padding(.horizontal)
            
            Spacer()
            
            // Next steps
            VStack(spacing: 16) {
                Text("What's Next?")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    NextStepRow(
                        icon: "plus.circle.fill",
                        title: "Add Your First Plant",
                        description: "Browse our plant database or add your existing plants"
                    )
                    
                    NextStepRow(
                        icon: "bell.badge.fill",
                        title: "Set Up Care Reminders",
                        description: "Never forget to water or care for your plants"
                    )
                    
                    NextStepRow(
                        icon: "book.pages.fill",
                        title: "Explore Learning Resources",
                        description: "Discover tutorials and tips for successful gardening"
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct ProfileSummaryRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.adaptiveGreen)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct NextStepRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.adaptiveGreen)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CompletionView(userProfile: .constant(UserProfile()))
        .padding()
}
import Foundation

/// Tutorial data model for caching
public struct TutorialData: Identifiable {
    public let id: String
    public let title: String
    public let progress: Double
    
    public init(id: String, title: String, progress: Double) {
        self.id = id
        self.title = title
        self.progress = progress
    }
}
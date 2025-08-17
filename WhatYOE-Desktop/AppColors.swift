import SwiftUI

// MARK: - Universal Color Constants
// Shared across desktop app, Safari extension, and backend
public struct AppColors {
    // Job Rating Colors - consistent across all platforms
    public static let goodGreen = Color(red: 24/255, green: 165/255, blue: 0/255)
    public static let maybeYellow = Color(red: 230/255, green: 189/255, blue: 0/255)
    public static let poorRed = Color(red: 195/255, green: 0/255, blue: 0/255)
    public static let rejectedBlack = Color(red: 50/255, green: 50/255, blue: 50/255)
    
    // Alternative access for extension compatibility
    public static let jobRatingColors = [
        "good": goodGreen,
        "maybe": maybeYellow,
        "poor": poorRed,
        "rejected": rejectedBlack
    ]
    
    // Helper function to get color by score
    public static func colorForScore(_ score: Double) -> Color {
        if score >= 2.7 {
            return goodGreen
        } else if score >= 2.0 {
            return maybeYellow
        } else if score >= 1.3 {
            return poorRed
        } else {
            return rejectedBlack
        }
    }
    
    // Helper function to get category name by score
    public static func categoryForScore(_ score: Double) -> String {
        if score >= 2.7 {
            return "Good"
        } else if score >= 2.0 {
            return "Maybe"
        } else if score >= 1.3 {
            return "Poor"
        } else {
            return "Rejected"
        }
    }
}
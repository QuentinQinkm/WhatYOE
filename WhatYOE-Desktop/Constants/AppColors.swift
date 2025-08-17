import SwiftUI

// MARK: - Global Color Constants
// Shared between desktop app and Safari extension
public struct AppColors {
    // Job Rating Colors
    public static let goodGreen = Color(red: 24/255, green: 176/255, blue: 0/255)
    public static let maybeYellow = Color(red: 236/255, green: 189/255, blue: 0/255)
    public static let poorRed = Color(red: 208/255, green: 0/255, blue: 0/255)
    public static let rejectedBlack = Color(red: 50/255, green: 50/255, blue: 50/255)
    
    // Alternative access for extension compatibility
    public static let jobRatingColors = [
        "good": goodGreen,
        "maybe": maybeYellow,
        "poor": poorRed,
        "rejected": rejectedBlack
    ]
}
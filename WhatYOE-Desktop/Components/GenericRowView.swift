import SwiftUI

// MARK: - Job Rating Colors
public struct AppColors {
    public static let goodGreen = Color(red: 24/255, green: 165/255, blue: 0/255)
    public static let maybeYellow = Color(red: 230/255, green: 189/255, blue: 0/255)
    public static let poorRed = Color(red: 195/255, green: 0/255, blue: 0/255)
    public static let rejectedBlack = Color(red: 50/255, green: 50/255, blue: 50/255)
}

// MARK: - Generic List Protocol
protocol ListRowData {
    var id: String { get }
    var primaryText: String { get }
    var secondaryText: String { get }
}

extension JobItem: ListRowData {
    var id: String { jobId }
    var primaryText: String { jobTitle }
    var secondaryText: String { company }
}

extension ResumeItem: ListRowData {
    var primaryText: String { name }
    var secondaryText: String { DateFormatter.shortDate.string(from: dateCreated) }
}

// MARK: - Generic Row View
struct GenericRowView<T: ListRowData>: View {
    let item: T
    let isSelected: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(getBorderColor())
                .frame(width: getBorderWidth())
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.primaryText)
                    .font(isSelected ? .title2 : .headline)
                    .fontWeight(.light)
                    .foregroundColor(.black.opacity(isSelected ? 1.0 : (isHovered ? 1.0 : 0.5)))
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                
                Text(item.secondaryText)
                    .font(isSelected ? .body : .caption)
                    .fontWeight(.light)
                    .foregroundColor(.black.opacity(isSelected ? 1.0 : (isHovered ? 1.0 : 0.5)))
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .background(Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private func getBorderColor() -> Color {
        let baseColor = getRatingColor()
        
        if isSelected || isHovered {
            return baseColor.opacity(1.0)
        } else {
            return baseColor.opacity(0.8)
        }
    }
    
    private func getRatingColor() -> Color {
        guard let jobItem = item as? JobItem else {
            return .gray
        }
        
        let finalScore = jobItem.analysisScores.finalScore
        
        if finalScore >= 0 && finalScore < 1.3 {
            return AppColors.rejectedBlack
        } else if finalScore >= 1.3 && finalScore < 2.0 {
            return AppColors.poorRed
        } else if finalScore >= 2.0 && finalScore < 2.7 {
            return AppColors.maybeYellow
        } else if finalScore >= 2.7 {
            return AppColors.goodGreen
        } else {
            return .gray
        }
    }
    
    private func getBorderWidth() -> CGFloat {
        return isSelected ? 8 : 5
    }
}
import SwiftUI


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
    
}
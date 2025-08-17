import SwiftUI

struct CustomTabPicker: View {
    @Binding var selectedTab: Int
    @State private var hoveringTab: Int? = nil
    
    private let tabs = [
        (index: 0, title: "Jobs"),
        (index: 1, title: "Resume"),
        (index: 2, title: "Analysis")
    ]
    
    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            ForEach(tabs, id: \.index) { tab in
                HStack(spacing: 6) {
                    if selectedTab == tab.index {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                    }
                    
                    Text(tab.title)
                        .font(.title)
                        .fontWeight(.light)
                        .foregroundColor(.black.opacity(textOpacity(for: tab.index)))
                        .animation(.easeInOut(duration: 0.15), value: selectedTab)
                        .animation(.easeInOut(duration: 0.1), value: hoveringTab)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTab = tab.index
                }
                .onHover { hovering in
                    hoveringTab = hovering ? tab.index : nil
                }
            }
            
            Spacer()
        }
    }
    
    private func textOpacity(for tabIndex: Int) -> Double {
        if selectedTab == tabIndex {
            return 1.0
        } else if hoveringTab == tabIndex {
            return 0.7
        } else {
            return 0.5
        }
    }
}
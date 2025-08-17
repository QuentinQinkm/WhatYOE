import SwiftUI

struct ResumeContentView: View {
    let text: String
    let bottomLabel: String
    let horizontalPadding: CGFloat
    let overlayButtons: (() -> AnyView)?
    
    init(text: String, bottomLabel: String, horizontalPadding: CGFloat, overlayButtons: (() -> AnyView)? = nil) {
        self.text = text
        self.bottomLabel = bottomLabel
        self.horizontalPadding = horizontalPadding
        self.overlayButtons = overlayButtons
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    ScrollView {
                        Text(text)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.black)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 12)
                            .padding(.bottom, 12)
                    }
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.05),
                                .init(color: .black, location: 0.95),
                                .init(color: .clear, location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    if let overlayButtons = overlayButtons {
                        overlayButtons()
                            .padding(16)
                    }
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
}
import SwiftUI

// MARK: - Button State and Configuration
enum ButtonState {
    case `default`
    case pressed
    case running
    case disabled
}

struct GlassButtonConfig {
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    let fontSize: CGFloat
    
    static let textButton = GlassButtonConfig(
        cornerRadius: 15,
        padding: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16),
        fontSize: 14
    )
    
    static let iconButton = GlassButtonConfig(
        cornerRadius: 20,
        padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
        fontSize: 16
    )
}

struct GlassButtonStyle {
    static func textColor(for state: ButtonState, baseColor: Color, isPressed: Bool) -> Color {
        let currentState = isPressed ? .pressed : state
        switch currentState {
        case .default:
            return baseColor.opacity(0.8)
        case .pressed:
            return .white
        case .running:
            return baseColor.opacity(0.8)
        case .disabled:
            return baseColor.opacity(0.5)
        }
    }
    
    static func backgroundFill(for state: ButtonState, baseColor: Color, isPressed: Bool) -> Color {
        let currentState = isPressed ? .pressed : state
        switch currentState {
        case .default:
            return Color.white.opacity(0.8)
        case .pressed:
            return baseColor.opacity(0.8)
        case .running:
            return baseColor.opacity(0.8)
        case .disabled:
            return Color.white.opacity(0.8)
        }
    }
}

// MARK: - Glass Button Components
struct GlassButton: View {
    let title: String
    let color: Color
    let state: ButtonState
    let action: () -> Void
    @State private var isPressed = false
    
    private let config = GlassButtonConfig.textButton
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: config.fontSize, weight: .light))
                .foregroundColor(GlassButtonStyle.textColor(for: state, baseColor: color, isPressed: isPressed))
                .padding(config.padding)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                            .fill(GlassButtonStyle.backgroundFill(for: state, baseColor: color, isPressed: isPressed))
                            .blendMode(.screen)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(state == .disabled)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct GlassIconButton: View {
    let icon: String
    let color: Color
    let state: ButtonState
    let action: () -> Void
    @State private var isPressed = false
    
    private let config = GlassButtonConfig.iconButton
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: config.fontSize, weight: .light))
                .foregroundColor(GlassButtonStyle.textColor(for: state, baseColor: color, isPressed: isPressed))
                .padding(config.padding)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                            .fill(GlassButtonStyle.backgroundFill(for: state, baseColor: color, isPressed: isPressed))
                            .blendMode(.screen)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(state == .disabled)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
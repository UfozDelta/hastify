import SwiftUI
import UIKit

/// Haptics are reserved for meaningful moments: a commit, a choice, a success.
enum Haptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

/// One set of curves so everything moves the same way. All stay under 300ms to feel instant.
enum Motion {
    /// Strong ease-out for entrances and state changes.
    static func out(_ duration: Double = 0.28) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: duration)
    }

    /// Critically damped: settles with no overshoot.
    static let settle = Animation.spring(response: 0.3, dampingFraction: 1)

    /// A little bounce, for things the user just chose.
    static let pop = Animation.spring(response: 0.3, dampingFraction: 0.65)
}

/// Responds on press-down, not release: scales in 100ms.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Fades and lifts into place once, staggered by `index`. Reduced motion keeps only the fade.
private struct Entrance: ViewModifier {
    let index: Int
    var scale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 10)
            .scaleEffect(shown || reduceMotion ? 1 : scale)
            .onAppear {
                withAnimation(Motion.out().delay(Double(index) * 0.05)) { shown = true }
            }
    }
}

extension View {
    func entrance(_ index: Int, scale: CGFloat = 1) -> some View {
        modifier(Entrance(index: index, scale: scale))
    }

    /// Digits roll when `value` changes (iOS 17+); a plain update before that.
    @ViewBuilder
    func numericText(_ value: String) -> some View {
        if #available(iOS 17.0, *) {
            contentTransition(.numericText()).animation(Motion.settle, value: value)
        } else {
            self
        }
    }
}

extension Color {
    /// Slightly darker shade for gradients.
    func deepened(_ amount: Double = 0.25) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(b) * (1 - amount))
    }
}

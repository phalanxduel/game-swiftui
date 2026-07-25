import SwiftUI
#if os(iOS)
import UIKit
#endif

@MainActor
public final class HapticAndAudioEngine {
    public static let shared = HapticAndAudioEngine()

    private init() {}

    public func playCardSelectedHaptic() {
#if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
#endif
    }

    public func playDeployHaptic() {
#if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
#endif
    }

    public func playAttackHaptic() {
#if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
#endif
    }

    public func playReinforceHaptic() {
#if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
#endif
    }

    public func playVictoryHaptic() {
#if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
#endif
    }

    public func playDefeatHaptic() {
#if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
#endif
    }
}

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Real trackpad haptics (NSHapticFeedbackManager) and system-sound-backed
/// audio cues for the macOS build — this app's actual target. The iOS
/// branches are kept for portability but are not exercised by this project.
///
/// Sound cues use bundled macOS system sounds (/System/Library/Sounds) as
/// honest placeholders, not bespoke SFX: swap the `NSSound(named:)` string
/// in each `play*` method for a custom asset name once real sound design
/// exists, no call-site changes needed.
@MainActor
public final class HapticAndAudioEngine {
    public static let shared = HapticAndAudioEngine()

    private init() {}

    public func playCardSelectedHaptic() {
        performHaptic(.generic)
        playSound("Tink")
    }

    public func playDeployHaptic() {
        performHaptic(.alignment)
        playSound("Pop")
    }

    public func playAttackHaptic() {
        performHaptic(.levelChange)
        playSound("Basso")
    }

    public func playReinforceHaptic() {
        performHaptic(.generic)
        playSound("Pop")
    }

    public func playVictoryHaptic() {
        performHaptic(.levelChange)
        playSound("Hero")
    }

    public func playDefeatHaptic() {
        performHaptic(.generic)
        playSound("Sosumi")
    }

    private func performHaptic(_ pattern: HapticPattern) {
#if os(iOS)
        switch pattern {
        case .generic:
            UISelectionFeedbackGenerator().selectionChanged()
        case .alignment:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .levelChange:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
#elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(
            pattern.macPattern,
            performanceTime: .now
        )
#endif
    }

    private func playSound(_ systemSoundName: String) {
#if os(macOS)
        NSSound(named: systemSoundName)?.play()
#endif
    }

    private enum HapticPattern {
        case generic
        case alignment
        case levelChange

#if os(macOS)
        var macPattern: NSHapticFeedbackManager.FeedbackPattern {
            switch self {
            case .generic: .generic
            case .alignment: .alignment
            case .levelChange: .levelChange
            }
        }
#endif
    }
}

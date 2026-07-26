import SwiftUI

public enum AppSpacing {
    public static let tiny: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 24
    public static let huge: CGFloat = 40
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

public extension Color {
    static let primaryAction = Color.blue
    static let destructiveAction = Color.red
    static let successStatus = Color.green
    static let warningStatus = Color.orange

    static let cardBorder = Color.gray.opacity(0.35)
    static let slotBackground = Color.gray.opacity(0.08)

    static let amberHighlight = Color.orange
    static let goldAccent = Color(hex: 0xFBBF24)
    static let goldBright = Color(hex: 0xFCD34D)
    static let goldDim = Color(hex: 0xD97706)
    static let emeraldGreen = Color.green

#if os(iOS)
    static let cardBackground = Color(uiColor: .systemBackground)
#else
    static let cardBackground = Color(nsColor: .windowBackgroundColor)
#endif

    // MARK: - Game chrome
    //
    // The gameplay screen (GameSessionView/GameTableView/PhxCardView) commits
    // to a fixed dark tactical palette regardless of system appearance,
    // ported from the browser reference client's actual design tokens
    // (client/src/style.css :root, client/src/cards.ts SUIT_COLORS) rather
    // than adapting to light mode. Non-game screens (Profile/Store/Leaderboard/
    // Social) are unaffected — they keep using the tokens above.
    static let gameBackground = Color(hex: 0x121212)
    static let gameSurface = Color(hex: 0x1A1F2E)
    static let gameSurfaceElevated = Color(hex: 0x232838)
    static let gameCardSurface = Color(hex: 0x0E1422)
    static let gameBorder = Color.white.opacity(0.08)
    static let gameBorderElevated = Color.white.opacity(0.18)
    static let gameTextPrimary = Color(hex: 0xF3F4F6)
    static let gameTextMuted = Color(hex: 0x9CA3AF)
    static let gameTextDim = Color(hex: 0x6B7280)

    /// Matches client/src/cards.ts SUIT_COLORS: spades/clubs are "neon
    /// offense" blue, hearts/diamonds are "neon defense" red — a tactical
    /// reinterpretation, not literal card-color convention.
    static let neonOffense = Color(hex: 0x007AFF)
    static let neonDefense = Color(hex: 0xFF2D55)
}

public extension Suit {
    var accentColor: Color {
        switch self {
        case .spades, .clubs: .neonOffense
        case .hearts, .diamonds: .neonDefense
        }
    }
}

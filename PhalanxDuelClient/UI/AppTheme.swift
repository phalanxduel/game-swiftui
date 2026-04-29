import SwiftUI

public enum AppSpacing {
    public static let tiny: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 24
    public static let huge: CGFloat = 40
}

public extension Color {
    static let primaryAction = Color.blue
    static let destructiveAction = Color.red
    static let successStatus = Color.green
    static let warningStatus = Color.orange

    static let cardBorder = Color.gray.opacity(0.35)
    static let slotBackground = Color.gray.opacity(0.08)

    static let suitRed = Color.red
    static let suitBlack = Color.primary
}

public extension ShapeStyle where Self == Color {
    static var primaryAction: Color {
        .blue
    }

    static var suitRed: Color {
        .red
    }
}

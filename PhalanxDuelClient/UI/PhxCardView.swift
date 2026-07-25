import SwiftUI

public struct PhxCardView: View {
    public let card: Card?
    public let isFaceUp: Bool
    public let isSelected: Bool
    public let isHighlighted: Bool

    public init(
        card: Card?,
        isFaceUp: Bool = true,
        isSelected: Bool = false,
        isHighlighted: Bool = false
    ) {
        self.card = card
        self.isFaceUp = isFaceUp
        self.isSelected = isSelected
        self.isHighlighted = isHighlighted
    }

    public var body: some View {
        ZStack {
            if isFaceUp, let card = card {
                faceUpView(card: card)
            } else {
                faceDownView
            }
        }
        .frame(width: 68, height: 98)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: isSelected ? suitGlowColor.opacity(0.6) : Color.black.opacity(0.15), radius: isSelected ? 8 : 3, x: 0, y: 2)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isSelected ? suitGlowColor : (isHighlighted ? Color.amberHighlight : Color.cardBorder),
                    lineWidth: isSelected ? 2.5 : (isHighlighted ? 2 : 1)
                )
        }
    }

    private func faceUpView(card: Card) -> some View {
        ZStack {
            // Background fill
            LinearGradient(
                colors: [Color.cardBackground, Color.cardBackground.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Central suit watermark
            Text(card.suit.symbol)
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(suitColor.opacity(0.12))

            // Corner Index - Top Left
            VStack(alignment: .leading, spacing: 0) {
                Text(card.face)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(suitColor)
                Text(card.suit.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(suitColor)
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Center Face / Rank Icon
            VStack(spacing: 2) {
                Text(card.suit.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(suitColor)
                if card.type == .ace {
                    Text("ACE")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(Color.goldAccent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.goldAccent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            // Corner Index - Bottom Right (Rotated)
            VStack(alignment: .trailing, spacing: 0) {
                Text(card.face)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(suitColor)
                Text(card.suit.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(suitColor)
            }
            .rotationEffect(.degrees(180))
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private var faceDownView: some View {
        ZStack {
            // Card back gradient
            LinearGradient(
                colors: [Color.indigo.opacity(0.85), Color.blue.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Shield emblem watermark
            Image(systemName: "shield.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.white.opacity(0.25))

            // Decorative inner border
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                .padding(5)
        }
    }

    private var suitColor: Color {
        guard let card = card else { return Color.primary }
        return card.suit.isRed ? Color.suitRed : Color.suitBlack
    }

    private var suitGlowColor: Color {
        guard let card = card else { return Color.blue }
        switch card.suit {
        case .hearts: return Color.red
        case .diamonds: return Color.cyan
        case .spades: return Color.purple
        case .clubs: return Color.emeraldGreen
        }
    }
}

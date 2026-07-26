import SwiftUI

/// Ports client/src/game.tsx's CardView + client/src/style.css's .phx-card
/// (rank/suit corners, suit-colored HP bar with fraction text, dim
/// monospace type caption, suit-tinted glow border).
public struct PhxCardView: View {
    public let card: Card?
    public let isFaceUp: Bool
    public let isSelected: Bool
    public let isHighlighted: Bool
    public let currentHp: Int?

    public init(
        card: Card?,
        isFaceUp: Bool = true,
        isSelected: Bool = false,
        isHighlighted: Bool = false,
        currentHp: Int? = nil
    ) {
        self.card = card
        self.isFaceUp = isFaceUp
        self.isSelected = isSelected
        self.isHighlighted = isHighlighted
        self.currentHp = currentHp
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
        .background(Color.gameCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: isSelected ? glowColor.opacity(0.7) : Color.black.opacity(0.3), radius: isSelected ? 10 : 4, x: 0, y: 2)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? glowColor : (isHighlighted ? Color.goldBright : Color.gameBorder),
                    lineWidth: isSelected ? 2.5 : (isHighlighted ? 2 : 1)
                )
        }
    }

    private func faceUpView(card: Card) -> some View {
        let accent = card.suit.accentColor
        return ZStack {
            RadialGradient(
                colors: [accent.opacity(0.16), Color.clear],
                center: .top,
                startRadius: 2,
                endRadius: 56
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(card.face)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                    Spacer()
                    Text(card.suit.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                }

                Spacer(minLength: 2)

                if let currentHp {
                    hpBar(currentHp: currentHp, maxHp: card.value, accent: accent)
                }

                Text(card.type.rawValue.uppercased())
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(Color.gameTextDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
            .padding(6)
        }
    }

    private func hpBar(currentHp: Int, maxHp: Int, accent: Color) -> some View {
        let ratio = maxHp > 0 ? max(0, min(1, Double(currentHp) / Double(maxHp))) : 0
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.black.opacity(0.45))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accent)
                    .frame(width: geometry.size.width * ratio)
                Text("\(currentHp)/\(maxHp)")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 2)
                    .frame(width: geometry.size.width, alignment: .center)
            }
        }
        .frame(height: 14)
    }

    private var faceDownView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gameSurface, Color.gameCardSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 26))
                .foregroundStyle(Color.goldAccent.opacity(0.35))

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.goldAccent.opacity(0.25), lineWidth: 1)
                .padding(5)
        }
    }

    private var glowColor: Color {
        card?.suit.accentColor ?? .goldAccent
    }
}

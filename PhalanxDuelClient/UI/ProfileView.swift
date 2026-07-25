import SwiftUI

public struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreManager.shared

    public let gamertag: String
    public let suffix: Int
    public let elo: Int
    public let wins: Int
    public let losses: Int

    public init(gamertag: String = "Valeryk", suffix: Int = 1042, elo: Int = 1850, wins: Int = 110, losses: Int = 32) {
        self.gamertag = gamertag
        self.suffix = suffix
        self.elo = elo
        self.wins = wins
        self.losses = losses
    }

    public var totalMatches: Int { wins + losses }
    public var winRate: Double {
        guard totalMatches > 0 else { return 0.0 }
        return Double(wins) / Double(totalMatches) * 100.0
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLAYER PROFILE")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(Color.goldAccent)
                    Text("Career Statistics & Equipped Cosmetics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(white: 0.1))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Identity Card
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.goldAccent.opacity(0.2))
                                .frame(width: 64, height: 64)
                                .overlay(Circle().stroke(Color.goldAccent, lineWidth: 2))

                            Image(systemName: "shield.fill")
                                .font(.title)
                                .foregroundColor(Color.goldAccent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(gamertag)#\(suffix)")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundColor(.white)

                                Text("FOUNDER")
                                    .font(.system(size: 9, weight: .black))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.goldAccent)
                                    .foregroundColor(.black)
                                    .cornerRadius(4)
                            }

                            Text("Rank #1 • Diamond Tier")
                                .font(.caption)
                                .foregroundColor(Color.goldAccent)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.12)))

                    // Career Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatBoxView(title: "ELO RATING", value: "\(elo)", color: Color.goldAccent)
                        StatBoxView(title: "WIN RATE", value: String(format: "%.1f%%", winRate), color: Color.emeraldGreen)
                        StatBoxView(title: "TOTAL MATCHES", value: "\(totalMatches)", color: .blue)
                    }

                    // Cosmetic Inventory & Loadout Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EQUIPPED LOADOUT")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            LoadoutSlotView(title: "Card Frame Skin", item: "Neon Cyber Spades", icon: "paintpalette.fill")
                            LoadoutSlotView(title: "Victory Banner", item: "Founders Crown Glow", icon: "crown.fill")
                            LoadoutSlotView(title: "Battlefield Grid", item: "Obsidian Glassmorphism", icon: "square.grid.3x3.fill")
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.1)))
                }
                .padding()
            }
            .background(Color(white: 0.05).ignoresSafeArea())
        }
        .frame(minWidth: 480, minHeight: 540)
    }
}

struct StatBoxView: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
    }
}

struct LoadoutSlotView: View {
    let title: String
    let item: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.goldAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(item)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Text("EQUIPPED")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.emeraldGreen.opacity(0.2))
                .foregroundColor(Color.emeraldGreen)
                .cornerRadius(4)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.08)))
    }
}

import SwiftUI

public struct LadderEntryItem: Identifiable, Decodable {
    public var id: String { userId }
    public let userId: String
    public let gamertag: String
    public let suffix: Int?
    public let elo: Int
    public let matchesPlayed: Int
    public let wins: Int
    public let winRate: Double?

    public var displayGamertag: String {
        if let s = suffix {
            return "\(gamertag)#\(s)"
        }
        return gamertag
    }

    public var computedWinRate: Double {
        if let wr = winRate { return wr }
        guard matchesPlayed > 0 else { return 0.0 }
        return Double(wins) / Double(matchesPlayed) * 100.0
    }
}

public struct LeaderboardView: View {
    @State private var entries: [LadderEntryItem] = []
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GLOBAL LADDER")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(Color.goldAccent)
                    Text("Top Ranked Phalanx Duel Players")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { fetchLadder() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)

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

            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading Ladder...")
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        // Top 3 Podium
                        if entries.count >= 3 {
                            HStack(alignment: .bottom, spacing: 12) {
                                PodiumBadgeView(entry: entries[1], rank: 2, accentColor: .gray)
                                PodiumBadgeView(entry: entries[0], rank: 1, accentColor: Color.goldAccent)
                                PodiumBadgeView(entry: entries[2], rank: 3, accentColor: .orange)
                            }
                            .padding(.vertical, 8)
                        }

                        // Full Ladder Table
                        VStack(spacing: 6) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                LeaderboardRowView(entry: entry, rank: index + 1)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(white: 0.05).ignoresSafeArea())
            }
        }
        .frame(minWidth: 500, minHeight: 560)
        .onAppear { fetchLadder() }
    }

    private func fetchLadder() {
        isLoading = true
        Task {
            let endpoint = URL(string: "http://127.0.0.1:3001/api/ladder")!
            do {
                let (data, response) = try await URLSession.shared.data(from: endpoint)
                guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                    useFallbackData()
                    return
                }

                struct LadderResponse: Decodable {
                    let success: Bool
                    let ladder: [LadderEntryItem]
                }

                let decoded = try JSONDecoder().decode(LadderResponse.self, from: data)
                self.entries = decoded.ladder.isEmpty ? fallbackEntries : decoded.ladder
                self.isLoading = false
            } catch {
                useFallbackData()
            }
        }
    }

    private var fallbackEntries: [LadderEntryItem] {
        [
            LadderEntryItem(userId: "1", gamertag: "Valeryk", suffix: 1042, elo: 1850, matchesPlayed: 142, wins: 110, winRate: 77.4),
            LadderEntryItem(userId: "2", gamertag: "PhalanxMaster", suffix: 99, elo: 1780, matchesPlayed: 210, wins: 148, winRate: 70.5),
            LadderEntryItem(userId: "3", gamertag: "AegisTactician", suffix: 404, elo: 1720, matchesPlayed: 98, wins: 65, winRate: 66.3),
            LadderEntryItem(userId: "4", gamertag: "CyberSpade", suffix: 88, elo: 1650, matchesPlayed: 75, wins: 48, winRate: 64.0),
            LadderEntryItem(userId: "5", gamertag: "IronShield", suffix: 12, elo: 1590, matchesPlayed: 120, wins: 72, winRate: 60.0),
        ]
    }

    private func useFallbackData() {
        self.entries = fallbackEntries
        self.isLoading = false
    }
}

struct PodiumBadgeView: View {
    let entry: LadderEntryItem
    let rank: Int
    let accentColor: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(accentColor, lineWidth: 2))

                Text("#\(rank)")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(accentColor)
            }

            Text(entry.displayGamertag)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text("\(entry.elo) ELO")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.4), lineWidth: 1))
    }
}

struct LeaderboardRowView: View {
    let entry: LadderEntryItem
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(rank <= 3 ? Color.goldAccent : .secondary)
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayGamertag)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("\(entry.wins)W / \(entry.matchesPlayed - entry.wins)L (\(String(format: "%.1f", entry.computedWinRate))%)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(entry.elo)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color.goldAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.1)))
    }
}

import SwiftUI

public struct SocialActivityItem: Identifiable {
    public let id = UUID()
    public let playerGamertag: String
    public let playerSuffix: Int
    public let activityType: String
    public let description: String
    public let timeAgo: String
    public var isFollowing: Bool

    public var displayGamertag: String {
        "\(playerGamertag)#\(playerSuffix)"
    }
}

public struct SocialFeedView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var activities: [SocialActivityItem] = [
        SocialActivityItem(playerGamertag: "Valeryk", playerSuffix: 1042, activityType: "victory", description: "Defeated Aegis (1850 ELO) in Ranked 1v1", timeAgo: "12m ago", isFollowing: true),
        SocialActivityItem(playerGamertag: "PhalanxMaster", playerSuffix: 99, activityType: "achievement", description: "Unlocked 'Master Tactician' (100 Wins)", timeAgo: "1h ago", isFollowing: true),
        SocialActivityItem(playerGamertag: "CyberSpade", playerSuffix: 88, activityType: "rank_up", description: "Promoted to Diamond Tier (#4 Global)", timeAgo: "3h ago", isFollowing: false),
        SocialActivityItem(playerGamertag: "IronShield", playerSuffix: 12, activityType: "cosmetic", description: "Equipped 'Founders Supporter Pass'", timeAgo: "5h ago", isFollowing: false),
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FRIEND & COMMUNITY FEED")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Color.goldAccent)
                    Text("Recent Victories & Unlocked Achievements")
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
                VStack(spacing: 12) {
                    ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                        SocialActivityRowView(activity: activity, onToggleFollow: {
                            activities[index].isFollowing.toggle()
                        })
                    }
                }
                .padding()
            }
            .background(Color(white: 0.05).ignoresSafeArea())
        }
        .frame(minWidth: 480, minHeight: 520)
    }
}

struct SocialActivityRowView: View {
    let activity: SocialActivityItem
    let onToggleFollow: () -> Void

    var iconName: String {
        switch activity.activityType {
        case "victory": return "trophy.fill"
        case "achievement": return "star.fill"
        case "rank_up": return "arrow.up.circle.fill"
        default: return "sparkles"
        }
    }

    var iconColor: Color {
        switch activity.activityType {
        case "victory": return Color.goldAccent
        case "achievement": return Color.amberHighlight
        case "rank_up": return Color.emeraldGreen
        default: return .blue
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(iconColor, lineWidth: 1))

                Image(systemName: iconName)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(activity.displayGamertag)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text("• \(activity.timeAgo)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(activity.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onToggleFollow) {
                Text(activity.isFollowing ? "Following" : "+ Follow")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(activity.isFollowing ? Color.white.opacity(0.1) : Color.goldAccent)
                    .foregroundColor(activity.isFollowing ? .white : .black)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.1)))
    }
}

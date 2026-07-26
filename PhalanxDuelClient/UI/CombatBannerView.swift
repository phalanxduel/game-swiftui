import SwiftUI

public struct CombatBannerView: View {
    public let turnResult: PhalanxTurnResult?
    public let events: [PhalanxEvent]

    public init(turnResult: PhalanxTurnResult?, events: [PhalanxEvent]) {
        self.turnResult = turnResult
        self.events = events
    }

    public var body: some View {
        if let result = turnResult {
            let action = result.action
            VStack(spacing: AppSpacing.tiny) {
                HStack(spacing: 8) {
                    Image(systemName: actionIcon(for: action.type))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(actionColor(for: action.type))

                    Text(actionTitle(for: action))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)

                    Spacer()

                    if let causeTag = latestCauseTag {
                        Text(causeTag)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.goldAccent)
                            .clipShape(Capsule())
                    }
                }

                if let summary = combatSummary {
                    Text(summary)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(actionColor(for: action.type).opacity(0.4), lineWidth: 1)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var latestCauseTag: String? {
        guard let lastEvent = events.last else { return nil }
        return lastEvent.payload["causeTag"]?.displayString ?? lastEvent.payload["cause"]?.displayString
    }

    private var combatSummary: String? {
        guard let result = turnResult, let turnEvents = result.events, !turnEvents.isEmpty else { return nil }
        return "\(turnEvents.count) combat event(s) resolved"
    }

    private func actionIcon(for type: ActionType) -> String {
        switch type {
        case .deploy: return "arrow.down.square.fill"
        case .attack: return "bolt.shield.fill"
        case .pass: return "forward.fill"
        case .reinforce: return "shield.fill"
        case .forfeit: return "flag.fill"
        case .systemInit: return "gearshape.fill"
        }
    }

    private func actionColor(for type: ActionType) -> Color {
        switch type {
        case .deploy: return Color.neonOffense
        case .attack: return Color.neonDefense
        case .pass: return Color.gray
        case .reinforce: return Color.goldAccent
        case .forfeit: return Color.purple
        case .systemInit: return Color.orange
        }
    }

    private func actionTitle(for action: Action) -> String {
        let pLabel = action.playerIndex != nil ? "P\(action.playerIndex! + 1)" : "Player"
        switch action.type {
        case .deploy: return "\(pLabel) Deployed Card"
        case .attack: return "\(pLabel) Initiated Attack"
        case .pass: return "\(pLabel) Passed Turn"
        case .reinforce: return "\(pLabel) Reinforced Position"
        case .forfeit: return "\(pLabel) Forfeited Match"
        case .systemInit: return "Match Initialized"
        }
    }
}

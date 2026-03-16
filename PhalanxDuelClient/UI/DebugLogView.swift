import SwiftUI

public struct DebugLogView: View {
    public let entries: [DebugLogEntry]
    public let events: [PhalanxEvent]
    public let compact: Bool

    public init(entries: [DebugLogEntry], events: [PhalanxEvent], compact: Bool = false) {
        self.entries = entries
        self.events = events
        self.compact = compact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent PhalanxEvent Stream")
                        .font(.headline)

                    ForEach(displayEvents) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.name)
                                .font(.subheadline.weight(.semibold))
                            Text(event.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !event.payloadSummary.isEmpty {
                                Text(event.payloadSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(compact ? 2 : nil)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Diagnostic Log")
                    .font(.headline)

                if displayEntries.isEmpty {
                    Text("No diagnostic entries yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(displayEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.subheadline.weight(.semibold))
                            Text("\(entry.category.rawValue) | \(entry.timestamp.formatted(date: .omitted, time: .standard))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let detail = entry.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(compact ? 2 : nil)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                    }
                }
            }
        }
    }

    private var displayEntries: [DebugLogEntry] {
        compact ? Array(entries.suffix(4)) : Array(entries.suffix(20))
    }

    private var displayEvents: [PhalanxEvent] {
        compact ? Array(events.suffix(3)) : Array(events.suffix(12))
    }
}

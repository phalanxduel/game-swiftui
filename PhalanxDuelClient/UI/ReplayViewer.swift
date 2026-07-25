import SwiftUI

public struct ReplayViewer: View {
    public let matchId: String
    @Environment(\.dismiss) private var dismiss

    @State private var currentTurn: Int = 0
    @State private var maxTurns: Int = 12
    @State private var isPlaying: Bool = false
    @State private var playbackSpeed: Double = 1.0
    @State private var playbackTimer: Timer? = nil

    public init(matchId: String = "demo-replay-001") {
        self.matchId = matchId
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MATCH REPLAY VIEWER")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Color.goldAccent)
                    Text("Match ID: \(matchId)")
                        .font(.caption2.monospaced())
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

            // Simulated Battlefield View Snapshot
            VStack {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.08))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .padding()

                    VStack(spacing: 12) {
                        HStack {
                            Label("Turn \(currentTurn) of \(maxTurns)", systemImage: "clock.arrow.circlepath")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.goldAccent)
                            Spacer()
                            Text("P1: Valeryk vs P2: Aegis")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        HStack(spacing: 20) {
                            PhxCardView(card: Card(id: "c1", suit: .spades, face: "A", value: 14, type: .ace))
                                .frame(width: 80, height: 112)
                            Image(systemName: "line.horizontal.star.fill.line.horizontal")
                                .font(.title2)
                                .foregroundColor(Color.amberHighlight)
                            PhxCardView(card: Card(id: "c2", suit: .hearts, face: "Q", value: 12, type: .queen))
                                .frame(width: 80, height: 112)
                        }

                        Text(currentTurn == 0 ? "Initial State — Game Start" : "Turn \(currentTurn): Attack deployed to Column 2 (HEART SHIELD trigger)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.top, 4)
                    }
                    .padding(24)
                }

                Spacer()
            }
            .background(Color(white: 0.05).ignoresSafeArea())

            Divider()

            // Playback Controls Bar
            VStack(spacing: 12) {
                // Scrubber Slider
                HStack(spacing: 12) {
                    Text("Turn 0")
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)

                    Slider(value: Binding(
                        get: { Double(currentTurn) },
                        set: { currentTurn = Int($0) }
                    ), in: 0...Double(maxTurns), step: 1)

                    Text("Turn \(maxTurns)")
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                }

                // Playback Buttons
                HStack(spacing: 20) {
                    Button(action: { currentTurn = max(0, currentTurn - 1) }) {
                        Image(systemName: "backward.fill")
                    }

                    Button(action: { togglePlayback() }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(Color.goldAccent)
                    }

                    Button(action: { currentTurn = min(maxTurns, currentTurn + 1) }) {
                        Image(systemName: "forward.fill")
                    }

                    Spacer()

                    // Speed Selector
                    Menu {
                        Button("1.0x") { playbackSpeed = 1.0 }
                        Button("2.0x") { playbackSpeed = 2.0 }
                        Button("4.0x") { playbackSpeed = 4.0 }
                    } label: {
                        Label("\(String(format: "%.1fx", playbackSpeed))", systemImage: "speedometer")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(white: 0.1))
        }
        .frame(minWidth: 520, minHeight: 560)
        .onDisappear { stopPlayback() }
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        isPlaying = true
        let interval = 1.5 / playbackSpeed
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if currentTurn < maxTurns {
                currentTurn += 1
            } else {
                stopPlayback()
            }
        }
    }

    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}

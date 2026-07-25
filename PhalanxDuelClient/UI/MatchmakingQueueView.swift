import SwiftUI

public struct MatchmakingQueueView: View {
    @ObservedObject public var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var elapsedSeconds: Int = 0
    @State private var queueTimer: Timer? = nil
    @State private var radarRotation: Double = 0.0

    public init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    public var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var eloRangeText: String {
        let expansion = (elapsedSeconds / 10) * 25
        return "1850 ± \(50 + expansion) ELO"
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("RANKED MATCHMAKING")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(Color.goldAccent)
                Spacer()
                Button(action: { cancelQueue() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top)

            Spacer()

            // Radar Animation Graphic
            ZStack {
                Circle()
                    .stroke(Color.goldAccent.opacity(0.2), lineWidth: 2)
                    .frame(width: 140, height: 140)

                Circle()
                    .stroke(Color.goldAccent.opacity(0.4), lineWidth: 1)
                    .frame(width: 90, height: 90)

                Circle()
                    .fill(Color.goldAccent.opacity(0.15))
                    .frame(width: 40, height: 40)

                // Radar Scanner Needle
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.goldAccent, Color.goldAccent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2, height: 70)
                    .offset(y: -35)
                    .rotationEffect(.degrees(radarRotation))
            }
            .padding(.vertical)

            // Status Texts
            VStack(spacing: 8) {
                Text("SEARCHING FOR OPPONENT...")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(formattedTime)
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(Color.goldAccent)

                HStack(spacing: 12) {
                    Label(eloRangeText, systemImage: "line.horizontal.3.decrease.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Label("Mode: Ranked 1v1", systemImage: "gamecontroller.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Cancel Search Button
            Button(action: { cancelQueue() }) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                    Text("CANCEL MATCHMAKING")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red, lineWidth: 1))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(minWidth: 400, minHeight: 460)
        .background(Color(white: 0.08).ignoresSafeArea())
        .onAppear {
            startTimer()
            startRadarAnimation()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        elapsedSeconds = 0
        queueTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        queueTimer?.invalidate()
        queueTimer = nil
    }

    private func startRadarAnimation() {
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            radarRotation = 360.0
        }
    }

    private func cancelQueue() {
        stopTimer()
        dismiss()
    }
}

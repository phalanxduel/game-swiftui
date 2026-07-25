import SwiftUI

public struct BootView: View {
    @ObservedObject var sessionStore: SessionStore
    @State private var opacity: Double = 0
    @State private var logoScale: CGFloat = 0.8

    public init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    public var body: some View {
        ZStack {
            // Background
#if os(iOS)
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
#else
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
#endif

            VStack(spacing: 40) {
                Spacer()

                // App Branding / Logo
                VStack(spacing: 16) {
                    Image(systemName: "shield.righthalf.filled")
                        .font(.system(size: 80))
                        .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .scaleEffect(logoScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                logoScale = 1.0
                            }
                        }

                    Text("PHALANX DUEL")
                        .font(.system(size: 28, weight: .black, design: .serif))
                        .tracking(4)
                }

                // Boot Sequence Progress
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(sessionStore.bootTasks) { task in
                        BootTaskRow(task: task)
                    }
                }
                .padding(30)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        }
                }
                .padding(.horizontal, 40)

                Spacer()

                // Version Info
                Text("NATIVE iOS CLIENT v0.1.0")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                opacity = 1.0
            }
            Task {
                await sessionStore.runBootSequence()
            }
        }
    }
}

struct BootTaskRow: View {
    let task: BootTask

    var body: some View {
        HStack(spacing: 16) {
            statusIcon
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(task.status == .pending ? .secondary : .primary)

                if let error = task.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .pending:
            Circle()
                .stroke(.secondary.opacity(0.3), lineWidth: 2)
        case .loading:
            ProgressView()
                .tint(.blue)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

#Preview {
    BootView(sessionStore: SessionStore())
}

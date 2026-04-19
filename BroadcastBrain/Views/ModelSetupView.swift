import SwiftUI

/// First-launch onboarding. Shown until `ModelInstaller.state == .installed`,
/// at which point the app transitions to the main UI.
struct ModelSetupView: View {
    let installer: ModelInstaller

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            VStack(spacing: 28) {
                header

                switch installer.state {
                case .notStarted, .preparing:
                    checkingBody
                case .downloading(let received, let total):
                    downloadingBody(received: received, total: total)
                case .extracting:
                    extractingBody
                case .installed:
                    Text("READY")
                        .font(Typography.sectionHead)
                        .foregroundStyle(Color.verified)
                        .tracking(1.2)
                case .failed(let msg):
                    failedBody(msg)
                }
            }
            .frame(maxWidth: 480)
            .padding(40)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.live)
                Text("BROADCASTBRAIN")
                    .font(Typography.sectionHead)
                    .tracking(1.4)
                    .foregroundStyle(Color.textPrimary)
            }
            Text("Setting up your on-device AI co-pilot")
                .font(Typography.body)
                .foregroundStyle(Color.textMuted)
        }
    }

    private var checkingBody: some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Preparing on-device AI…")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
                .tracking(0.5)
        }
    }

    private var extractingBody: some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Extracting weights…")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
                .tracking(0.5)
        }
    }

    private func downloadingBody(received: Int64, total: Int64) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DOWNLOADING GEMMA · FIRST LAUNCH ONLY")
                .font(Typography.sectionHead)
                .foregroundStyle(Color.textSubtle)
                .tracking(1.2)
            if total > 0 {
                let ratio = max(0, min(1, Double(received) / Double(total)))
                ProgressView(value: ratio)
                    .progressViewStyle(.linear)
                    .tint(Color.live)
                HStack {
                    Text("\(format(received)) / \(format(total))")
                        .font(Typography.chip)
                        .foregroundStyle(Color.textMuted)
                        .monospacedDigit()
                    Spacer()
                    Text("\(Int(ratio * 100))%")
                        .font(Typography.chip)
                        .foregroundStyle(Color.textMuted)
                        .monospacedDigit()
                }
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color.live)
                Text("Connecting…")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }
            Text("Model runs entirely on-device after download. You'll never need to wait for this again.")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(18)
        .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.bbBorder, lineWidth: 1)
        )
    }

    private func failedBody(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.live)
                Text("SETUP FAILED")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.live)
                    .tracking(1.2)
            }
            Text(msg)
                .font(Typography.body)
                .foregroundStyle(Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: { installer.retry() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11))
                    Text("RETRY")
                        .font(Typography.chip)
                        .tracking(0.6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(Color.textPrimary)
                .background(Color.live, in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.live.opacity(0.6), lineWidth: 1)
        )
    }

    private func format(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 {
            return String(format: "%.2f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }
}

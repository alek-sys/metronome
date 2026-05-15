import SwiftUI

struct ManualBPMView: View {
    @Binding var bpm: Int
    @ObservedObject var engine: MetronomeEngine

    @State private var taps: [Date] = []
    @State private var isTapping = false
    @State private var shouldAutoStart = false
    @State private var isStoppingForTapTempo = false

    private let maxTapGap: TimeInterval = 4.0
    private let maxTaps = 5

    var body: some View {
        VStack(spacing: 32) {
            Text("\(bpm)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text("BPM")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                Slider(
                    value: Binding(
                        get: { Double(bpm) },
                        set: { bpm = Int($0) }
                    ),
                    in: 20...208,
                    step: 1
                )
                .tint(.accentColor)

                HStack(spacing: 40) {
                    Button {
                        bpm = max(20, bpm - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        bpm = min(208, bpm + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                handleTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isTapping ? 1.18 : 1.0)
                        .opacity(isTapping ? 0.6 : 1.0)

                    Circle()
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
                        .frame(width: 120, height: 120)

                    VStack(spacing: 2) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 22, weight: .medium))
                        Text("Tap")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .animation(.spring(response: 0.12, dampingFraction: 0.5), value: isTapping)
            }
            .buttonStyle(.plain)

            Text(tapHint)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(height: 20)
        }
        .padding(.horizontal, 40)
        .onChange(of: engine.isPlaying) { _, isPlaying in
            guard !isPlaying else { return }
            if isStoppingForTapTempo {
                isStoppingForTapTempo = false
            } else {
                taps.removeAll()
            }
        }
    }

    private var tapHint: String {
        if taps.count < 3 {
            return "Tap repeatedly to set BPM"
        } else {
            return "Detected: \(bpm) BPM"
        }
    }

    private func handleTap() {
        let now = Date()

        if let lastTap = taps.last, now.timeIntervalSince(lastTap) > maxTapGap {
            taps.removeAll()
        }

        // New tapping session
        if taps.isEmpty {
            shouldAutoStart = true
            if engine.isPlaying {
                isStoppingForTapTempo = true
                engine.stop()
            }
        }

        // Add current tap
        taps.append(now)

        // Keep only the most recent maxTaps
        if taps.count > maxTaps {
            taps = Array(taps.suffix(maxTaps))
        }

        // Visual feedback
        withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) {
            isTapping = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isTapping = false
            }
        }

        // Calculate BPM once there are enough intervals to smooth out early taps.
        guard taps.count >= 3 else { return }

        let intervals = zip(taps, taps.dropFirst()).map { $1.timeIntervalSince($0) }
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard averageInterval > 0 else { return }

        let detected = Int(round(60.0 / averageInterval))
        let clamped = min(max(detected, 20), 208)

        bpm = clamped

        // Auto-start after 3 taps, including when tapping temporarily stopped playback.
        if shouldAutoStart && taps.count >= 3 {
            shouldAutoStart = false
            engine.start(bpm: bpm)
        }
    }
}

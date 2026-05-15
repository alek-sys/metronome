import SwiftUI

struct ContentView: View {
    @StateObject private var engine = MetronomeEngine()
    @State private var selectedTempo = Tempo.all.first { $0.id == "moderato" }!
    @State private var manualBPM = 92
    @State private var isManualMode = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var pulseTask: Task<Void, Never>?
    @State private var isPulsing = false

    private var tabIndex: Binding<Int> {
        Binding(
            get: { isManualMode ? 1 : 0 },
            set: { isManualMode = $0 == 1 }
        )
    }

    private var currentBPM: Int {
        isManualMode ? manualBPM : selectedTempo.defaultBPM
    }

    private func startPulsing(bpm: Int) {
        pulseTask?.cancel()
        let interval = 60.0 / Double(bpm)
        let hit = min(0.08, interval * 0.35)
        pulseTask = Task { @MainActor in
            while !Task.isCancelled {
                withAnimation(.easeOut(duration: hit)) { isPulsing = true }
                try? await Task.sleep(for: .seconds(hit))
                withAnimation(.easeInOut(duration: max(0.05, interval - hit))) { isPulsing = false }
                try? await Task.sleep(for: .seconds(max(0.05, interval - hit)))
            }
        }
    }

    private func stopPulsing() {
        pulseTask?.cancel()
        pulseTask = nil
        withAnimation(.easeOut(duration: 0.2)) { isPulsing = false }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $isManualMode) {
                Text("Tempos").tag(false)
                Text("Manual").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 80)

            TabView(selection: tabIndex) {
                TempoPickerView(selectedTempo: $selectedTempo, tempos: Tempo.all)
                    .tag(0)
                ManualBPMView(bpm: $manualBPM, engine: engine)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            Button {
                if engine.isPlaying {
                    engine.stop()
                } else {
                    engine.start(bpm: currentBPM)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill((engine.isPlaying ? Color.red : Color.accentColor).opacity(0.3))
                        .frame(width: 72, height: 72)
                        .scaleEffect(isPulsing ? 1.6 : 1.0)
                        .opacity(isPulsing ? 0 : 0.5)

                    Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(engine.isPlaying ? Color.red : Color.accentColor)
                        .clipShape(Circle())
                        .shadow(
                            color: (engine.isPlaying ? Color.red : Color.accentColor).opacity(isPulsing ? 0.75 : 0.35),
                            radius: isPulsing ? 28 : 12,
                            y: 4
                        )
                        .scaleEffect(isPulsing ? 1.12 : 1.0)
                }
                .animation(.spring(response: 0.12, dampingFraction: 0.5), value: isPulsing)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: isManualMode) { manual in
            if manual {
                manualBPM = selectedTempo.defaultBPM
            } else {
                selectedTempo = Tempo.nearest(to: manualBPM)
            }
        }
        .onChange(of: engine.isPlaying) { _, playing in
            if playing {
                startPulsing(bpm: currentBPM)
            } else {
                stopPulsing()
            }
        }
        .onChange(of: engine.currentBPM) { _, newBPM in
            selectedTempo = Tempo.nearest(to: newBPM)
            manualBPM = newBPM
        }
        .onChange(of: currentBPM) { _, newBPM in
            engine.syncBPM(newBPM)
            if engine.isPlaying {
                startPulsing(bpm: newBPM)
            }
            guard engine.isPlaying else { return }
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                engine.restart(bpm: newBPM)
            }
        }
    }
}

import AVFoundation
import Foundation
import MediaPlayer

final class MetronomeEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var currentBPM: Int = 92

    private let queue = DispatchQueue(label: "metronome", qos: .userInteractive)
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var audioBuffer: AVAudioPCMBuffer?
    private var scheduleGeneration = 0
    private let scheduledBatchDurationSeconds = 30.0 * 60.0

    func start(bpm: Int) {
        currentBPM = bpm
        queue.async { [weak self] in
            self?.startOnQueue(bpm: bpm)
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopOnQueue()
        }
    }

    func restart(bpm: Int) {
        currentBPM = bpm
        queue.async { [weak self] in
            guard let self, self.isPlaying else { return }
            self.stopOnQueue()
            self.startOnQueue(bpm: bpm)
        }
    }

    func syncBPM(_ bpm: Int) {
        currentBPM = bpm
        if !isPlaying {
            updateNowPlaying(playing: false, bpm: bpm)
        }
    }

    // MARK: - Remote Commands

    init() {
        setupRemoteCommands()
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.stopCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)

        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.start(bpm: self.currentBPM)
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }

        center.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.isPlaying {
                self.stop()
            } else {
                self.start(bpm: self.currentBPM)
            }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTempo()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTempo()
            return .success
        }

        center.changePlaybackRateCommand.isEnabled = false
        center.seekForwardCommand.isEnabled = false
        center.seekBackwardCommand.isEnabled = false
    }

    private func updateNowPlaying(playing: Bool, bpm: Int) {
        let tempo = Tempo.nearest(to: bpm)
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = [
            MPMediaItemPropertyTitle: tempo.name,
            MPMediaItemPropertyArtist: "\(bpm) BPM",
            MPMediaItemPropertyPlaybackDuration: 0,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: true,
        ]
    }

    private func nextTempo() {
        let tempos = Tempo.all
        let nextIndex: Int
        if let currentIndex = tempos.firstIndex(where: { $0.defaultBPM == currentBPM }) {
            nextIndex = min(currentIndex + 1, tempos.count - 1)
        } else {
            nextIndex = tempos.firstIndex(where: { $0.defaultBPM > currentBPM }) ?? tempos.count - 1
        }
        let newBPM = tempos[nextIndex].defaultBPM
        currentBPM = newBPM
        if isPlaying {
            restart(bpm: newBPM)
        } else {
            updateNowPlaying(playing: false, bpm: newBPM)
        }
    }

    private func previousTempo() {
        let tempos = Tempo.all
        let currentIndex = tempos.firstIndex(where: { $0.defaultBPM >= currentBPM }) ?? tempos.count - 1
        let prevIndex = max(currentIndex - 1, 0)
        let newBPM = tempos[prevIndex].defaultBPM
        currentBPM = newBPM
        if isPlaying {
            restart(bpm: newBPM)
        } else {
            updateNowPlaying(playing: false, bpm: newBPM)
        }
    }

    // MARK: - Queue-serialized internals

    private func stopOnQueue() {
        scheduleGeneration += 1
        player?.stop()
        engine?.stop()
        engine = nil
        player = nil
        audioBuffer = nil
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.updateNowPlaying(playing: false, bpm: self?.currentBPM ?? 92)
        }
    }

    private func startOnQueue(bpm: Int) {
        stopOnQueue()
        scheduleGeneration += 1
        let generation = scheduleGeneration

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
            return
        }

        let eng = AVAudioEngine()
        let play = AVAudioPlayerNode()
        eng.attach(play)
        eng.connect(play, to: eng.mainMixerNode, format: nil)

        let sampleRate = 44100.0
        let duration = 0.012
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount)
        else { return }

        buf.frameLength = frameCount
        if let left = buf.floatChannelData?[0], let right = buf.floatChannelData?[1] {
            let freqHigh: Float = 3400
            let freqBody: Float = 700
            for i in 0..<Int(frameCount) {
                let progress = Float(i) / Float(frameCount)
                let t = Float(i) / Float(sampleRate)
                let env = expf(-progress * 14)
                let sweep = freqHigh + (200 - freqHigh) * progress
                let click = sin(2 * .pi * sweep * t)
                let body = sin(2 * .pi * freqBody * t) * 0.4
                let sample = (click + body) * env * 0.65
                left[i] = sample
                right[i] = sample
            }
        }

        engine = eng
        player = play
        audioBuffer = buf

        do {
            try eng.start()
        } catch {
            print("Engine start error: \(error)")
            stopOnQueue()
            return
        }

        let outputRate = play.outputFormat(forBus: 0).sampleRate
        let samplesPerBeat = AVAudioFramePosition(outputRate * 60.0 / Double(bpm))
        let lead = AVAudioFramePosition(outputRate * 0.03)
        let scheduledBeatCount = max(1, Int(ceil(scheduledBatchDurationSeconds * Double(bpm) / 60.0)))

        scheduleBatch(
            startingAtBeat: 0,
            beatCount: scheduledBeatCount,
            samplesPerBeat: samplesPerBeat,
            lead: lead,
            outputRate: outputRate,
            generation: generation
        )
        scheduleBatch(
            startingAtBeat: scheduledBeatCount,
            beatCount: scheduledBeatCount,
            samplesPerBeat: samplesPerBeat,
            lead: lead,
            outputRate: outputRate,
            generation: generation
        )

        play.play()

        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = true
            self?.updateNowPlaying(playing: true, bpm: bpm)
        }
    }

    private func scheduleBatch(
        startingAtBeat startBeat: Int,
        beatCount: Int,
        samplesPerBeat: AVAudioFramePosition,
        lead: AVAudioFramePosition,
        outputRate: Double,
        generation: Int
    ) {
        guard generation == scheduleGeneration,
              let play = player,
              let buf = audioBuffer
        else { return }

        for offset in 0..<beatCount {
            let beat = startBeat + offset
            let when = AVAudioTime(
                sampleTime: lead + AVAudioFramePosition(beat) * samplesPerBeat,
                atRate: outputRate
            )

            if offset == beatCount - 1 {
                play.scheduleBuffer(buf, at: when) { [weak self] in
                    self?.queue.async { [weak self] in
                        self?.scheduleBatch(
                            startingAtBeat: startBeat + beatCount * 2,
                            beatCount: beatCount,
                            samplesPerBeat: samplesPerBeat,
                            lead: lead,
                            outputRate: outputRate,
                            generation: generation
                        )
                    }
                }
            } else {
                play.scheduleBuffer(buf, at: when)
            }
        }
    }
}

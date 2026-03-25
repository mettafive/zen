import AVFoundation
import AppKit

@MainActor
final class SoundService {
    static let shared = SoundService()

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    private init() {}

    // Soft singing bowl tone for drain completion
    func playDrainSound() {
        guard AppSettings.shared.soundEnabled else { return }
        playSineChord(frequencies: [528, 396], duration: 1.5, fadeOut: true)
    }

    // Gentle chime for edge selection confirmation
    func playSelectionSound() {
        guard AppSettings.shared.soundEnabled else { return }
        playSineChord(frequencies: [639, 528, 741], duration: 1.0, fadeOut: true)
    }

    // Soft tick while holding at edge
    func playEdgeTickSound() {
        guard AppSettings.shared.soundEnabled else { return }
        playSineChord(frequencies: [396], duration: 0.15, fadeOut: true)
    }

    private func playSineChord(frequencies: [Double], duration: Double, fadeOut: Bool) {
        let sampleRate: Double = 44100
        let frameCount = Int(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))
        else { return }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let amplitude: Float = 0.15 / Float(frequencies.count)

        for frame in 0..<frameCount {
            let t = Double(frame) / sampleRate
            var sample: Float = 0

            for freq in frequencies {
                sample += amplitude * sin(Float(2.0 * .pi * freq * t))
            }

            // Fade out envelope
            if fadeOut {
                let envelope = Float(1.0 - (t / duration))
                let smoothEnvelope = envelope * envelope // quadratic fade
                sample *= smoothEnvelope
            }

            // Fade in to avoid click (first 10ms)
            let fadeInSamples = Int(sampleRate * 0.01)
            if frame < fadeInSamples {
                sample *= Float(frame) / Float(fadeInSamples)
            }

            channelData[frame] = sample
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            player.play()
            player.scheduleBuffer(buffer) {
                DispatchQueue.main.async {
                    engine.stop()
                }
            }
            // Keep references alive
            self.audioEngine = engine
            self.playerNode = player
        } catch {
            print("[Zen] Sound error: \(error)")
        }
    }
}

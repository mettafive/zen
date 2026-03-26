import AVFoundation
import AppKit

struct ZenSound: Identifiable {
    let id: String
    let name: String
    let frequencies: [Double]
    let duration: Double
}

@MainActor
final class SoundService {
    static let shared = SoundService()

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var engineRunning = false

    private init() {
        audioEngine.attach(playerNode)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
    }

    private func ensureEngineRunning() {
        guard !engineRunning else { return }
        do {
            try audioEngine.start()
            engineRunning = true
        } catch {
            print("[Zen] Sound engine error: \(error)")
        }
    }

    // MARK: - Sound Catalog

    static let quoteSounds: [ZenSound] = [
        ZenSound(id: "singing-bowl", name: "Singing Bowl", frequencies: [528, 396], duration: 1.5),
        ZenSound(id: "temple-bell", name: "Temple Bell", frequencies: [880, 1320, 660], duration: 1.8),
        ZenSound(id: "rain-drop", name: "Rain Drop", frequencies: [1200, 900], duration: 0.8),
        ZenSound(id: "ocean-wave", name: "Ocean Wave", frequencies: [120, 180, 90], duration: 2.0),
        ZenSound(id: "wind-chime", name: "Wind Chime", frequencies: [1047, 1319, 1568], duration: 1.2),
        ZenSound(id: "bamboo", name: "Bamboo", frequencies: [440, 330], duration: 1.0),
        ZenSound(id: "crystal", name: "Crystal", frequencies: [1760, 2093, 1397], duration: 1.0),
        ZenSound(id: "gong", name: "Gong", frequencies: [110, 220, 165], duration: 2.0),
        ZenSound(id: "stream", name: "Stream", frequencies: [600, 750, 900], duration: 1.5),
        ZenSound(id: "dawn", name: "Dawn", frequencies: [396, 528, 639], duration: 1.8),
        ZenSound(id: "silence", name: "Silence", frequencies: [], duration: 0),
    ]

    static let reminderSounds: [ZenSound] = [
        ZenSound(id: "soft-tap", name: "Soft Tap", frequencies: [800], duration: 0.3),
        ZenSound(id: "water-drop", name: "Water Drop", frequencies: [1400, 1050], duration: 0.4),
        ZenSound(id: "bell-tap", name: "Bell Tap", frequencies: [1200, 900, 600], duration: 0.5),
        ZenSound(id: "breeze", name: "Breeze", frequencies: [200, 300], duration: 0.8),
        ZenSound(id: "pebble", name: "Pebble", frequencies: [500, 750], duration: 0.3),
        ZenSound(id: "leaf", name: "Leaf", frequencies: [1000, 1500], duration: 0.5),
        ZenSound(id: "ripple", name: "Ripple", frequencies: [660, 880, 1100], duration: 0.6),
        ZenSound(id: "whisper", name: "Whisper", frequencies: [150, 225], duration: 0.7),
        ZenSound(id: "tink", name: "Tink", frequencies: [2000, 1500], duration: 0.2),
        ZenSound(id: "chime-soft", name: "Soft Chime", frequencies: [523, 659, 784], duration: 0.6),
        ZenSound(id: "silence", name: "Silence", frequencies: [], duration: 0),
    ]

    // MARK: - Play by ID

    func playSound(id: String) {
        guard AppSettings.shared.soundEnabled else { return }
        guard id != "silence" else { return }
        let all = Self.quoteSounds + Self.reminderSounds
        guard let sound = all.first(where: { $0.id == id }) else { return }
        playSineChord(frequencies: sound.frequencies, duration: sound.duration, fadeOut: true)
    }

    /// Preview a sound (plays even if global sound is off, for picker UX)
    func previewSound(id: String) {
        guard id != "silence" else { return }
        let all = Self.quoteSounds + Self.reminderSounds
        guard let sound = all.first(where: { $0.id == id }) else { return }
        playSineChord(frequencies: sound.frequencies, duration: sound.duration, fadeOut: true)
    }

    // MARK: - Legacy convenience methods

    func playDrainSound() {
        guard AppSettings.shared.soundEnabled else { return }
        playSineChord(frequencies: [528, 396], duration: 1.5, fadeOut: true)
    }

    func playSelectionSound() {
        guard AppSettings.shared.soundEnabled else { return }
        playSineChord(frequencies: [639, 528, 741], duration: 1.0, fadeOut: true)
    }

    func playEdgeTickSound() {
        guard AppSettings.shared.soundEnabled else { return }
        playSineChord(frequencies: [396], duration: 0.15, fadeOut: true)
    }

    // MARK: - Synthesis

    private func playSineChord(frequencies: [Double], duration: Double, fadeOut: Bool) {
        guard !frequencies.isEmpty, duration > 0 else { return }
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

        ensureEngineRunning()
        playerNode.stop()
        playerNode.play()
        playerNode.scheduleBuffer(buffer)
    }
}

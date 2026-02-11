//
//  SoundManager.swift
//  DnDTextRPG
//
//  Retro synthesized sound effects using AVAudioEngine
//

import AVFoundation

class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let sampleRate: Double = 44100
    private let format: AVAudioFormat

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            try engine.start()
        } catch {
            // Silent failure — sounds are optional
        }
    }

    // MARK: - Waveform Generation

    private func generateTone(frequency: Double, duration: Double, volume: Float = 0.3, waveform: Waveform = .square) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return nil }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let sample: Float

            switch waveform {
            case .square:
                let phase = t * frequency
                sample = (phase - floor(phase)) < 0.5 ? volume : -volume
            case .sine:
                sample = volume * Float(sin(2.0 * .pi * frequency * t))
            case .noise:
                sample = volume * Float.random(in: -1...1) * 0.5
            }

            // Apply fade-out envelope to avoid clicks
            let fadeFrames = min(Int(sampleRate * 0.02), Int(frameCount) / 4)
            let envelope: Float
            if i < fadeFrames {
                envelope = Float(i) / Float(fadeFrames)
            } else if i > Int(frameCount) - fadeFrames {
                envelope = Float(Int(frameCount) - i) / Float(fadeFrames)
            } else {
                envelope = 1.0
            }

            data[i] = sample * envelope
        }

        return buffer
    }

    private enum Waveform {
        case square
        case sine
        case noise
    }

    // MARK: - Playback

    private func playSequence(_ tones: [(frequency: Double, duration: Double, volume: Float, waveform: Waveform)]) {
        if !engine.isRunning {
            try? engine.start()
        }
        guard engine.isRunning else { return }

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }

            for tone in tones {
                if let buffer = self.generateTone(
                    frequency: tone.frequency,
                    duration: tone.duration,
                    volume: tone.volume,
                    waveform: tone.waveform
                ) {
                    self.playerNode.scheduleBuffer(buffer, completionHandler: nil)
                    if !self.playerNode.isPlaying {
                        self.playerNode.play()
                    }
                    Thread.sleep(forTimeInterval: tone.duration)
                }
            }
        }
    }

    // MARK: - Sound Effects

    /// Sword hitting armor/flesh — sharp rising tone
    func playHit() {
        playSequence([
            (440, 0.05, 0.25, .square),
            (660, 0.05, 0.3, .square),
            (880, 0.08, 0.2, .square),
        ])
    }

    /// Critical hit — dramatic ascending with emphasis
    func playCrit() {
        playSequence([
            (440, 0.04, 0.3, .square),
            (660, 0.04, 0.35, .square),
            (880, 0.04, 0.35, .square),
            (1100, 0.06, 0.3, .square),
            (1320, 0.1, 0.25, .sine),
        ])
    }

    /// Miss — descending whoosh
    func playMiss() {
        playSequence([
            (400, 0.06, 0.15, .sine),
            (300, 0.06, 0.12, .sine),
            (200, 0.08, 0.08, .sine),
        ])
    }

    /// Monster attacks — low aggressive growl-strike
    func playMonsterAttack() {
        playSequence([
            (150, 0.06, 0.3, .square),
            (200, 0.04, 0.25, .square),
            (120, 0.08, 0.3, .square),
        ])
    }

    /// Battle start — alarm/fanfare
    func playBattleStart() {
        playSequence([
            (523, 0.1, 0.25, .square),  // C5
            (659, 0.1, 0.25, .square),  // E5
            (784, 0.1, 0.25, .square),  // G5
            (1047, 0.2, 0.3, .square),  // C6
        ])
    }

    /// Victory — triumphant ascending fanfare
    func playVictory() {
        playSequence([
            (523, 0.12, 0.25, .square),  // C5
            (587, 0.12, 0.25, .square),  // D5
            (659, 0.12, 0.25, .square),  // E5
            (784, 0.15, 0.25, .square),  // G5
            (1047, 0.25, 0.3, .sine),    // C6
        ])
    }

    /// Defeat — sad descending tones
    func playDefeat() {
        playSequence([
            (440, 0.2, 0.25, .sine),    // A4
            (370, 0.2, 0.22, .sine),    // F#4
            (330, 0.2, 0.2, .sine),     // E4
            (262, 0.4, 0.18, .sine),    // C4
        ])
    }

    /// Save game — quick confirmation chirp
    func playSave() {
        playSequence([
            (800, 0.06, 0.2, .square),
            (1000, 0.06, 0.2, .square),
            (1200, 0.1, 0.25, .square),
        ])
    }

    /// Healing/rest — gentle ascending shimmer
    func playHeal() {
        playSequence([
            (523, 0.1, 0.15, .sine),   // C5
            (659, 0.1, 0.15, .sine),   // E5
            (784, 0.1, 0.18, .sine),   // G5
            (1047, 0.15, 0.2, .sine),  // C6
        ])
    }

    /// Dice roll — rapid random clicks
    func playDiceRoll() {
        playSequence([
            (800, 0.03, 0.15, .noise),
            (900, 0.03, 0.15, .noise),
            (700, 0.03, 0.15, .noise),
            (1000, 0.03, 0.15, .noise),
            (850, 0.03, 0.15, .noise),
            (750, 0.05, 0.2, .square),
        ])
    }
}

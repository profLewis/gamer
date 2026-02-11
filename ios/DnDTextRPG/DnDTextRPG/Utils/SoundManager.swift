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
    private let musicNode = AVAudioPlayerNode()
    private let sampleRate: Double = 44100
    private let format: AVAudioFormat

    // Music state
    private var musicPlaying = false
    private var currentMusic: MusicType?
    private var musicQueue: DispatchQueue = DispatchQueue(label: "com.dnd.music", qos: .background)

    enum MusicType {
        case menu
        case exploration
        case combat
    }

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(playerNode)
        engine.attach(musicNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        engine.connect(musicNode, to: engine.mainMixerNode, format: format)

        // Music is quieter than SFX
        musicNode.volume = 0.4

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

    // MARK: - Background Music

    func startMusic(_ type: MusicType) {
        if currentMusic == type && musicPlaying { return }
        stopMusic()

        if !engine.isRunning {
            try? engine.start()
        }
        guard engine.isRunning else { return }

        currentMusic = type
        musicPlaying = true

        musicQueue.async { [weak self] in
            guard let self = self else { return }

            while self.musicPlaying {
                let melody = self.melodyFor(type)
                for note in melody {
                    guard self.musicPlaying else { break }

                    if note.frequency == 0 {
                        // Rest note
                        Thread.sleep(forTimeInterval: note.duration)
                        continue
                    }

                    if let buffer = self.generateTone(
                        frequency: note.frequency,
                        duration: note.duration,
                        volume: note.volume,
                        waveform: note.waveform
                    ) {
                        self.musicNode.scheduleBuffer(buffer, completionHandler: nil)
                        if !self.musicNode.isPlaying {
                            self.musicNode.play()
                        }
                        Thread.sleep(forTimeInterval: note.duration)
                    }
                }
            }
        }
    }

    func stopMusic() {
        musicPlaying = false
        currentMusic = nil
        musicNode.stop()
    }

    private func melodyFor(_ type: MusicType) -> [(frequency: Double, duration: Double, volume: Float, waveform: Waveform)] {
        switch type {
        case .menu:
            return menuMelody()
        case .exploration:
            return explorationMelody()
        case .combat:
            return combatMelody()
        }
    }

    /// Menu — slow, mysterious arpeggios in A minor
    private func menuMelody() -> [(frequency: Double, duration: Double, volume: Float, waveform: Waveform)] {
        let v: Float = 0.12
        return [
            // A minor arpeggio up
            (220, 0.5, v, .sine),     // A3
            (262, 0.5, v, .sine),     // C4
            (330, 0.5, v, .sine),     // E4
            (440, 0.7, v, .sine),     // A4
            (0, 0.3, 0, .sine),       // rest
            // Descend
            (392, 0.5, v, .sine),     // G4
            (330, 0.5, v, .sine),     // E4
            (294, 0.5, v, .sine),     // D4
            (262, 0.7, v, .sine),     // C4
            (0, 0.3, 0, .sine),       // rest
            // Second phrase — F major
            (175, 0.5, v, .sine),     // F3
            (220, 0.5, v, .sine),     // A3
            (262, 0.5, v, .sine),     // C4
            (349, 0.7, v, .sine),     // F4
            (0, 0.3, 0, .sine),       // rest
            // Resolve to Am
            (330, 0.5, v, .sine),     // E4
            (294, 0.4, v, .sine),     // D4
            (262, 0.4, v, .sine),     // C4
            (220, 0.9, v, .sine),     // A3
            (0, 0.6, 0, .sine),       // rest
        ]
    }

    /// Exploration — adventurous melody in D minor, medium tempo
    private func explorationMelody() -> [(frequency: Double, duration: Double, volume: Float, waveform: Waveform)] {
        let v: Float = 0.10
        let sq: Float = 0.06
        return [
            // Phrase 1 — walking bass + melody
            (147, 0.3, sq, .square),  // D3 bass
            (294, 0.3, v, .sine),     // D4
            (349, 0.3, v, .sine),     // F4
            (392, 0.3, v, .sine),     // G4
            (440, 0.5, v, .sine),     // A4
            (0, 0.2, 0, .sine),
            (392, 0.3, v, .sine),     // G4
            (349, 0.4, v, .sine),     // F4
            (0, 0.2, 0, .sine),
            // Phrase 2
            (175, 0.3, sq, .square),  // F3 bass
            (349, 0.3, v, .sine),     // F4
            (392, 0.3, v, .sine),     // G4
            (440, 0.3, v, .sine),     // A4
            (523, 0.5, v, .sine),     // C5
            (0, 0.2, 0, .sine),
            (440, 0.3, v, .sine),     // A4
            (392, 0.4, v, .sine),     // G4
            (0, 0.2, 0, .sine),
            // Phrase 3 — descend
            (165, 0.3, sq, .square),  // E3 bass
            (523, 0.3, v, .sine),     // C5
            (440, 0.3, v, .sine),     // A4
            (392, 0.3, v, .sine),     // G4
            (349, 0.5, v, .sine),     // F4
            (0, 0.2, 0, .sine),
            (330, 0.3, v, .sine),     // E4
            (294, 0.6, v, .sine),     // D4
            (0, 0.4, 0, .sine),
        ]
    }

    /// Combat — fast, intense driving rhythm in E minor
    private func combatMelody() -> [(frequency: Double, duration: Double, volume: Float, waveform: Waveform)] {
        let v: Float = 0.10
        let b: Float = 0.08
        return [
            // Driving bass rhythm
            (165, 0.15, b, .square),  // E3
            (165, 0.15, b, .square),  // E3
            (196, 0.15, b, .square),  // G3
            (165, 0.15, b, .square),  // E3
            // Melody stab
            (330, 0.2, v, .square),   // E4
            (392, 0.2, v, .square),   // G4
            (440, 0.15, v, .square),  // A4
            (392, 0.15, v, .square),  // G4
            // Bass
            (147, 0.15, b, .square),  // D3
            (147, 0.15, b, .square),  // D3
            (165, 0.15, b, .square),  // E3
            (147, 0.15, b, .square),  // D3
            // Melody
            (294, 0.2, v, .square),   // D4
            (330, 0.2, v, .square),   // E4
            (392, 0.15, v, .square),  // G4
            (330, 0.15, v, .square),  // E4
            // Intense ascending
            (196, 0.15, b, .square),  // G3
            (196, 0.15, b, .square),  // G3
            (220, 0.15, b, .square),  // A3
            (247, 0.15, b, .square),  // B3
            // Top phrase
            (494, 0.2, v, .square),   // B4
            (440, 0.2, v, .square),   // A4
            (392, 0.2, v, .square),   // G4
            (330, 0.3, v, .square),   // E4
            (0, 0.1, 0, .sine),
        ]
    }
}

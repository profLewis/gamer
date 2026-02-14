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
            case .triangle:
                let phase = t * frequency
                let p = phase - floor(phase)
                sample = volume * Float(p < 0.5 ? (4.0 * p - 1.0) : (3.0 - 4.0 * p))
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
        case triangle
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

    // MARK: - Multi-Voice Buffer Generation

    /// A single step in the music: multiple voices sounding simultaneously
    private struct MusicStep {
        let voices: [(frequency: Double, volume: Float, waveform: Waveform)]
        let duration: Double
    }

    private func generateMixedBuffer(_ step: MusicStep) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * step.duration)
        guard frameCount > 0 else { return nil }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return nil }

        // Zero the buffer
        for i in 0..<Int(frameCount) { data[i] = 0 }

        // Mix each voice in
        for voice in step.voices {
            if voice.frequency == 0 { continue }
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                let sample: Float
                switch voice.waveform {
                case .square:
                    let phase = t * voice.frequency
                    sample = (phase - floor(phase)) < 0.5 ? voice.volume : -voice.volume
                case .sine:
                    sample = voice.volume * Float(sin(2.0 * .pi * voice.frequency * t))
                case .noise:
                    sample = voice.volume * Float.random(in: -1...1) * 0.5
                case .triangle:
                    let phase = t * voice.frequency
                    let p = phase - floor(phase)
                    sample = voice.volume * Float(p < 0.5 ? (4.0 * p - 1.0) : (3.0 - 4.0 * p))
                }
                data[i] += sample
            }
        }

        // Apply envelope
        let fadeFrames = min(Int(sampleRate * 0.015), Int(frameCount) / 4)
        for i in 0..<Int(frameCount) {
            let env: Float
            if i < fadeFrames {
                env = Float(i) / Float(fadeFrames)
            } else if i > Int(frameCount) - fadeFrames {
                env = Float(Int(frameCount) - i) / Float(fadeFrames)
            } else {
                env = 1.0
            }
            // Soft clip to avoid distortion from mixed voices
            let s = data[i] * env
            data[i] = s / (1.0 + abs(s) * 0.3)
        }

        return buffer
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
                let steps = self.melodyFor(type)
                for step in steps {
                    guard self.musicPlaying else { break }

                    if let buffer = self.generateMixedBuffer(step) {
                        self.musicNode.scheduleBuffer(buffer, completionHandler: nil)
                        if !self.musicNode.isPlaying {
                            self.musicNode.play()
                        }
                        Thread.sleep(forTimeInterval: step.duration)
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

    /// Lower music volume for speech, restore after
    func duckMusic() {
        musicNode.volume = 0.05
    }

    func unduckMusic() {
        musicNode.volume = 0.4
    }

    private func melodyFor(_ type: MusicType) -> [MusicStep] {
        switch type {
        case .menu:
            return menuMelody()
        case .exploration:
            return explorationMelody()
        case .combat:
            return combatMelody()
        }
    }

    // Helper to create a step with drone + melody
    private func step(_ dur: Double, drone: (Double, Float, Waveform)? = nil, melody: (Double, Float, Waveform)? = nil, extra: (Double, Float, Waveform)? = nil) -> MusicStep {
        var voices: [(frequency: Double, volume: Float, waveform: Waveform)] = []
        if let d = drone { voices.append(d) }
        if let m = melody { voices.append(m) }
        if let e = extra { voices.append(e) }
        return MusicStep(voices: voices, duration: dur)
    }

    // Shorthand for a rest
    private func rest(_ dur: Double) -> MusicStep {
        MusicStep(voices: [], duration: dur)
    }

    // MARK: - Menu Music — "The Dungeon Awaits"
    // Dark Phrygian mode (E F G A B C D), low drone, haunting medieval melody

    private func menuMelody() -> [MusicStep] {
        let drone: (Double, Float, Waveform) = (82.4, 0.07, .triangle)   // E2 drone
        let drone2: (Double, Float, Waveform) = (123.5, 0.05, .sine)     // B2 fifth
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.10, .sine) }
        let h = { (f: Double) -> (Double, Float, Waveform) in (f, 0.06, .triangle) }  // harmony

        return [
            // Phrase 1 — rising from darkness (E Phrygian)
            step(0.7, drone: drone, melody: m(330), extra: drone2),     // E4
            step(0.5, drone: drone, melody: m(349), extra: drone2),     // F4 (Phrygian b2)
            step(0.7, drone: drone, melody: m(392), extra: drone2),     // G4
            step(1.0, drone: drone, melody: m(440), extra: drone2),     // A4
            rest(0.3),
            // Phrase 2 — descend with tension
            step(0.5, drone: drone, melody: m(392), extra: h(330)),     // G4 + E4
            step(0.5, drone: drone, melody: m(349), extra: h(294)),     // F4 + D4
            step(0.7, drone: drone, melody: m(330)),                     // E4
            step(0.9, drone: drone, melody: m(294), extra: drone2),     // D4
            rest(0.4),
            // Phrase 3 — ominous low phrase
            step(0.6, drone: drone, melody: m(262), extra: h(196)),     // C4 + G3
            step(0.6, drone: drone, melody: m(247), extra: h(165)),     // B3 + E3
            step(0.8, drone: drone, melody: m(220)),                     // A3
            step(1.2, drone: drone, melody: m(165), extra: drone2),     // E3 (octave down)
            rest(0.5),
            // Phrase 4 — ghostly high echo
            step(0.5, drone: drone, melody: m(659), extra: drone2),     // E5
            step(0.4, drone: drone, melody: m(698)),                     // F5
            step(0.5, drone: drone, melody: m(659), extra: h(494)),     // E5 + B4
            step(1.0, drone: drone, melody: m(523), extra: h(392)),     // C5 + G4
            step(1.5, drone: drone, melody: m(330), extra: drone2),     // E4 resolve
            rest(0.8),
        ]
    }

    // MARK: - Exploration Music — "Into the Depths"
    // D Dorian mode, creeping tension, sparse notes over shifting drone

    private func explorationMelody() -> [MusicStep] {
        let d1: (Double, Float, Waveform) = (73.4, 0.06, .triangle)    // D2 low drone
        let d2: (Double, Float, Waveform) = (110, 0.04, .sine)         // A2 fifth
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.09, .triangle) }
        let g = { (f: Double) -> (Double, Float, Waveform) in (f, 0.05, .sine) }  // ghost note

        // Bass shifts for different sections
        let bF: (Double, Float, Waveform) = (87.3, 0.06, .triangle)    // F2
        let bC: (Double, Float, Waveform) = (65.4, 0.06, .triangle)    // C2
        let bA: (Double, Float, Waveform) = (55.0, 0.06, .triangle)    // A1

        return [
            // Phrase 1 — cautious steps (D Dorian)
            step(0.45, drone: d1, melody: m(294)),                       // D4
            step(0.35, drone: d1),                                        // drone only — silence
            step(0.45, drone: d1, melody: m(330), extra: d2),           // E4
            step(0.45, drone: d1, melody: m(349)),                       // F4
            step(0.6, drone: d1, melody: m(440), extra: d2),            // A4
            rest(0.3),
            step(0.45, drone: d1, melody: m(392), extra: g(294)),       // G4 + D4 ghost
            step(0.7, drone: d1, melody: m(349)),                        // F4
            rest(0.4),

            // Phrase 2 — deeper, bass shifts to F
            step(0.45, drone: bF, melody: m(349)),                       // F4
            step(0.35, drone: bF),                                        // drone only
            step(0.45, drone: bF, melody: m(392), extra: g(262)),       // G4 + C4
            step(0.55, drone: bF, melody: m(440)),                       // A4
            step(0.7, drone: bF, melody: m(523), extra: g(349)),        // C5 + F4
            rest(0.25),
            step(0.5, drone: bF, melody: m(440)),                        // A4
            step(0.6, drone: bF, melody: m(349)),                        // F4
            rest(0.35),

            // Phrase 3 — tension builds (bass to C)
            step(0.4, drone: bC, melody: m(330)),                        // E4
            step(0.4, drone: bC, melody: m(294), extra: g(196)),        // D4 + G3
            step(0.5, drone: bC, melody: m(262)),                        // C4
            step(0.8, drone: bC, melody: m(247), extra: g(165)),        // B3 + E3 (tritone)
            rest(0.3),

            // Phrase 4 — resolve back (bass to A, then D)
            step(0.5, drone: bA, melody: m(262), extra: g(220)),        // C4 + A3
            step(0.5, drone: bA, melody: m(294)),                        // D4
            step(0.7, drone: d1, melody: m(349), extra: d2),            // F4
            step(0.9, drone: d1, melody: m(294), extra: g(220)),        // D4 + A3
            rest(0.6),
        ]
    }

    // MARK: - Combat Music — "Blades of Fury"
    // E minor, 8-bar epic battle theme with A/B sections

    private func combatMelody() -> [MusicStep] {
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.10, .square) }
        let b = { (f: Double) -> (Double, Float, Waveform) in (f, 0.07, .square) }
        let h = { (f: Double) -> (Double, Float, Waveform) in (f, 0.05, .triangle) }
        let p = { (f: Double) -> (Double, Float, Waveform) in (f, 0.03, .noise) }
        // Louder melody for climax
        let M = { (f: Double) -> (Double, Float, Waveform) in (f, 0.13, .square) }
        let H = { (f: Double) -> (Double, Float, Waveform) in (f, 0.07, .triangle) }

        let t: Double = 0.13  // base tempo

        return [
            // === SECTION A: Aggressive approach ===

            // Bar 1 — pounding E minor bass + melody enters
            step(t, drone: b(82.4), extra: p(80)),                      // E2 + kick
            step(t, drone: b(82.4), melody: m(330)),                    // E2 + E4
            step(t, drone: b(82.4), extra: p(200)),                     // E2 + snare
            step(t, drone: b(82.4), melody: m(392)),                    // E2 + G4
            step(t, drone: b(82.4), extra: p(80)),                      // E2 + kick
            step(t, drone: b(82.4), melody: m(440), extra: h(330)),    // E2 + A4 + E4
            step(t, drone: b(82.4), extra: p(200)),                     // E2 + snare
            step(t, drone: b(82.4), melody: m(494)),                    // E2 + B4

            // Bar 2 — rising phrase over shifting bass
            step(t, drone: b(73.4), extra: p(80)),                      // D2 + kick
            step(t, drone: b(73.4), melody: m(494)),                    // D2 + B4
            step(t, drone: b(73.4), melody: m(523), extra: p(200)),    // D2 + C5 + snare
            step(t, drone: b(73.4), melody: m(587)),                    // D2 + D5
            step(t, drone: b(82.4), melody: m(659), extra: p(80)),     // E2 + E5 + kick
            step(t, drone: b(82.4), melody: m(587), extra: h(440)),    // E2 + D5 + A4
            step(t * 2, drone: b(82.4), melody: m(494), extra: p(200)), // E2 + B4 held

            // Bar 3 — dark G minor descent
            step(t, drone: b(98.0), extra: p(80)),                      // G2 + kick
            step(t, drone: b(98.0), melody: m(587), extra: h(494)),    // G2 + D5 + B4
            step(t, drone: b(98.0), extra: p(200)),                     // G2 + snare
            step(t, drone: b(98.0), melody: m(523)),                    // G2 + C5
            step(t, drone: b(110), melody: m(494), extra: p(80)),      // A2 + B4 + kick
            step(t, drone: b(110), melody: m(440), extra: h(330)),     // A2 + A4 + E4
            step(t, drone: b(110), extra: p(200)),                      // A2 + snare
            step(t, drone: b(110), melody: m(392)),                     // A2 + G4

            // Bar 4 — tension + resolve to E
            step(t, drone: b(123.5), melody: m(494), extra: p(80)),    // B2 + B4 + kick
            step(t, drone: b(123.5), melody: m(440)),                   // B2 + A4
            step(t, drone: b(123.5), melody: m(392), extra: p(200)),   // B2 + G4 + snare
            step(t, drone: b(123.5), melody: m(330), extra: h(247)),   // B2 + E4 + B3
            step(t * 2, drone: b(82.4), melody: m(330), extra: p(80)), // E2 + E4 resolve
            rest(t),
            step(t, extra: p(200)),                                      // snare fill

            // === SECTION B: Epic heroic theme ===

            // Bar 5 — triumphant melody, power chords
            step(t, drone: b(82.4), melody: M(659), extra: p(80)),     // E2 + E5 + kick
            step(t, drone: b(82.4), melody: M(659), extra: H(494)),   // E2 + E5 + B4
            step(t, drone: b(82.4), extra: p(200)),                     // E2 + snare
            step(t, drone: b(82.4), melody: M(587), extra: H(440)),   // E2 + D5 + A4
            step(t, drone: b(73.4), melody: M(587), extra: p(80)),     // D2 + D5 + kick
            step(t, drone: b(73.4), melody: M(523), extra: H(392)),   // D2 + C5 + G4
            step(t, drone: b(73.4), extra: p(200)),                     // D2 + snare
            step(t, drone: b(73.4), melody: M(494), extra: H(392)),   // D2 + B4 + G4

            // Bar 6 — ascending war cry
            step(t, drone: b(65.4), melody: M(523), extra: p(80)),     // C2 + C5 + kick
            step(t, drone: b(65.4), melody: M(587)),                    // C2 + D5
            step(t, drone: b(65.4), melody: M(659), extra: p(200)),    // C2 + E5 + snare
            step(t, drone: b(65.4), melody: M(784), extra: H(587)),   // C2 + G5 + D5
            step(t, drone: b(73.4), extra: p(80)),                      // D2 + kick
            step(t, drone: b(73.4), melody: M(784), extra: H(659)),   // D2 + G5 + E5
            step(t * 2, drone: b(82.4), melody: M(659), extra: p(200)), // E2 + E5 held

            // Bar 7 — frantic call and response
            step(t, drone: b(82.4), melody: m(330), extra: p(80)),     // E2 + E4
            step(t, drone: b(82.4), melody: m(494)),                    // E2 + B4
            step(t, drone: b(82.4), melody: m(659), extra: p(200)),    // E2 + E5
            step(t, drone: b(82.4)),                                     // E2 rest
            step(t, drone: b(98.0), melody: m(392), extra: p(80)),     // G2 + G4
            step(t, drone: b(98.0), melody: m(587)),                    // G2 + D5
            step(t, drone: b(98.0), melody: m(784), extra: p(200)),    // G2 + G5
            step(t, drone: b(98.0)),                                     // G2 rest

            // Bar 8 — final climax + turnaround
            step(t, drone: b(110), melody: M(659), extra: p(80)),      // A2 + E5 + kick
            step(t, drone: b(110), melody: M(587), extra: H(440)),    // A2 + D5 + A4
            step(t, drone: b(123.5), melody: M(587), extra: p(200)),   // B2 + D5 + snare
            step(t, drone: b(123.5), melody: M(494), extra: H(392)),  // B2 + B4 + G4
            step(t, drone: b(82.4), melody: M(440), extra: p(80)),     // E2 + A4 + kick
            step(t, drone: b(82.4), melody: M(392), extra: H(247)),   // E2 + G4 + B3
            step(t, drone: b(82.4), melody: M(330), extra: p(200)),    // E2 + E4 + snare
            step(t, drone: b(82.4), extra: p(80)),                      // E2 + kick (turnaround)
        ]
    }
}

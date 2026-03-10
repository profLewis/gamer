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

    // Settings
    var battleSoundsEnabled: Bool = true

    enum MusicType {
        case menu
        case exploration
        case combat
        case chat
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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            try engine.start()
        } catch {
            // Silent failure — sounds are optional
        }

        // Restart engine after audio interruptions (phone calls, Siri, etc.)
        #if os(iOS)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            if type == .ended {
                try? AVAudioSession.sharedInstance().setActive(true)
                try? self?.engine.start()
            }
        }
        #endif
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
        guard battleSoundsEnabled else { return }
        playSequence([
            (440, 0.05, 0.25, .square),
            (660, 0.05, 0.3, .square),
            (880, 0.08, 0.2, .square),
        ])
    }

    /// Critical hit — dramatic ascending with emphasis
    func playCrit() {
        guard battleSoundsEnabled else { return }
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
        guard battleSoundsEnabled else { return }
        playSequence([
            (400, 0.06, 0.15, .sine),
            (300, 0.06, 0.12, .sine),
            (200, 0.08, 0.08, .sine),
        ])
    }

    /// Monster attacks — low aggressive growl-strike
    func playMonsterAttack() {
        guard battleSoundsEnabled else { return }
        playSequence([
            (150, 0.06, 0.3, .square),
            (200, 0.04, 0.25, .square),
            (120, 0.08, 0.3, .square),
        ])
    }

    /// Battle start — alarm/fanfare
    func playBattleStart() {
        guard battleSoundsEnabled else { return }
        playSequence([
            (523, 0.1, 0.25, .square),  // C5
            (659, 0.1, 0.25, .square),  // E5
            (784, 0.1, 0.25, .square),  // G5
            (1047, 0.2, 0.3, .square),  // C6
        ])
    }

    /// Victory — triumphant ascending fanfare
    func playVictory() {
        guard battleSoundsEnabled else { return }
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
        guard battleSoundsEnabled else { return }
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

    /// Sword swing — whooshing slash
    func playSwordSwing() {
        guard battleSoundsEnabled else { return }
        playSequence([
            (300, 0.04, 0.2, .noise),
            (500, 0.05, 0.25, .noise),
            (700, 0.04, 0.2, .noise),
            (400, 0.03, 0.15, .noise),
        ])
    }

    /// Arrow shot — twang then whistle
    func playArrowShot() {
        guard battleSoundsEnabled else { return }
        playSequence([
            (880, 0.04, 0.2, .square),
            (1200, 0.03, 0.15, .sine),
            (1400, 0.04, 0.12, .sine),
            (1600, 0.05, 0.08, .sine),
        ])
    }

    /// Staff strike — deep thud
    func playStaffStrike() {
        guard battleSoundsEnabled else { return }
        playSequence([
            (120, 0.06, 0.3, .square),
            (100, 0.08, 0.25, .triangle),
            (80, 0.06, 0.2, .sine),
        ])
    }

    /// Shield block — metallic clang
    func playShieldBlock() {
        guard battleSoundsEnabled else { return }
        playSequence([
            (800, 0.03, 0.3, .square),
            (600, 0.04, 0.25, .square),
            (400, 0.06, 0.2, .triangle),
        ])
    }

    /// Spell cast — magical shimmer
    func playSpellCast() {
        guard battleSoundsEnabled else { return }
        playSequence([
            (523, 0.06, 0.15, .sine),
            (784, 0.06, 0.18, .sine),
            (1047, 0.06, 0.2, .sine),
            (1568, 0.08, 0.15, .sine),
            (1047, 0.06, 0.12, .sine),
        ])
    }

    /// Death — grim descending tone
    func playDeath() {
        guard battleSoundsEnabled else { return }
        playSequence([
            (300, 0.15, 0.25, .square),
            (200, 0.15, 0.2, .square),
            (150, 0.2, 0.18, .triangle),
            (100, 0.3, 0.15, .sine),
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

    /// Multiplayer notification — medieval horn call (D&D style)
    func playMultiplayerNotification() {
        playSequence([
            (294, 0.15, 0.3, .triangle),   // D4 — horn onset
            (440, 0.12, 0.3, .triangle),   // A4 — fifth leap
            (587, 0.15, 0.35, .triangle),  // D5 — octave
            (440, 0.08, 0.25, .triangle),  // A4 — dip
            (587, 0.12, 0.3, .sine),       // D5 — return
            (784, 0.25, 0.3, .sine),       // G5 — heroic peak
            (587, 0.3, 0.2, .sine),        // D5 — resolve, fade
        ])
    }

    // MARK: - Listen Foley Sounds

    /// Ear press — low thud of pressing ear against stone
    func playListenStart() {
        // Ear pressed to door — dull thud then silence
        playSequence([
            (250, 0.08, 0.4, .square),
            (200, 0.1, 0.3, .noise),
        ])
    }

    /// Growling monster heard through a door — muffled, distant
    func playListenGrowl() {
        // Square waves have harmonics that speakers can reproduce even at lower fundamentals
        playSequence([
            (280, 0.15, 0.35, .square),
            (250, 0.12, 0.4, .square),
            (220, 0.18, 0.35, .square),
            (300, 0.1, 0.3, .square),
            (240, 0.2, 0.25, .square),   // distant tail
            (200, 0.25, 0.15, .square),  // echo fade
        ])
    }

    /// Scraping claws heard through a door — muffled scratching
    func playListenScraping() {
        playSequence([
            (1800, 0.06, 0.35, .noise),
            (0, 0.06, 0, .sine),
            (1400, 0.07, 0.3, .noise),
            (2200, 0.05, 0.35, .noise),
            (0, 0.08, 0, .sine),
            (1600, 0.06, 0.25, .noise),
            (1000, 0.1, 0.15, .noise),   // distant fade
        ])
    }

    /// Heavy breathing heard through a door — slow, muffled
    func playListenBreathing() {
        // Use noise filtered through higher freqs to simulate breath
        playSequence([
            (350, 0.2, 0.3, .noise),    // inhale
            (300, 0.25, 0.35, .noise),
            (0, 0.15, 0, .sine),
            (400, 0.2, 0.3, .noise),    // exhale
            (280, 0.25, 0.25, .noise),
            (250, 0.2, 0.15, .noise),   // trailing fade
        ])
    }

    /// Coins clinking — faint, distant metallic
    func playListenCoins() {
        playSequence([
            (2800, 0.04, 0.35, .sine),
            (0, 0.1, 0, .sine),
            (3200, 0.04, 0.3, .sine),
            (2600, 0.05, 0.3, .sine),
            (0, 0.12, 0, .sine),
            (3400, 0.04, 0.25, .sine),
            (2400, 0.06, 0.15, .sine),   // distant echo
        ])
    }

    /// Humming voice — muffled through stone, distant melody
    func playListenHumming() {
        playSequence([
            (310, 0.18, 0.35, .sine),
            (330, 0.15, 0.35, .sine),
            (310, 0.18, 0.3, .sine),
            (278, 0.22, 0.3, .sine),
            (262, 0.25, 0.2, .sine),     // trailing echo
            (248, 0.2, 0.12, .sine),     // distant fade
        ])
    }

    /// Faint clicking — trap mechanism, echoing
    func playListenClicking() {
        playSequence([
            (1400, 0.03, 0.4, .square),
            (0, 0.12, 0, .sine),
            (1400, 0.03, 0.3, .square),  // echo repeat
            (0, 0.15, 0, .sine),
            (1400, 0.03, 0.2, .square),  // fainter still
        ])
    }

    /// Something massive stirring — deep rumble, distant and ominous
    func playListenBoss() {
        // Use square waves at audible range — harmonics give the "big" feel
        playSequence([
            (220, 0.2, 0.45, .square),
            (250, 0.15, 0.4, .square),
            (200, 0.25, 0.45, .square),
            (280, 0.1, 0.35, .square),
            (190, 0.3, 0.35, .square),   // sustained rumble
            (180, 0.35, 0.2, .square),   // distant fade
        ])
    }

    /// Distant dungeon ambience — dripping water, far-off wind
    func playListenSilence() {
        playSequence([
            (800, 0.15, 0.1, .noise),    // faint air movement
            (0, 0.15, 0, .sine),
            (3500, 0.03, 0.3, .sine),    // water drip
            (0, 0.25, 0, .sine),
            (3200, 0.03, 0.2, .sine),    // second drip (echo)
            (0, 0.2, 0, .sine),
            (600, 0.25, 0.08, .noise),   // distant wind
            (3600, 0.02, 0.15, .sine),   // faint third drip
            (0, 0.15, 0, .sine),
            (500, 0.3, 0.05, .noise),    // trailing silence
        ])
    }

    /// Heartbeat — lub-dub pulse in the quiet
    func playListenHeartbeat() {
        // Realistic heartbeat: low-freq "lub" (S1) followed quickly by higher "dub" (S2)
        playSequence([
            // Beat 1: lub-dub
            (55, 0.08, 0.5, .sine),      // lub — deep bass thump
            (40, 0.06, 0.35, .sine),      // lub tail
            (0, 0.06, 0, .sine),          // tiny gap
            (80, 0.06, 0.4, .sine),       // dub — slightly higher
            (60, 0.04, 0.25, .sine),      // dub tail
            (0, 0.55, 0, .sine),          // pause between beats
            // Beat 2: lub-dub (slightly quieter)
            (55, 0.08, 0.45, .sine),
            (40, 0.06, 0.3, .sine),
            (0, 0.06, 0, .sine),
            (80, 0.06, 0.35, .sine),
            (60, 0.04, 0.2, .sine),
            (0, 0.55, 0, .sine),
            // Beat 3: lub-dub (fading)
            (55, 0.08, 0.35, .sine),
            (40, 0.06, 0.2, .sine),
            (0, 0.06, 0, .sine),
            (80, 0.06, 0.25, .sine),
            (60, 0.04, 0.15, .sine),
        ])
    }

    /// Quit / farewell — gentle descending melody
    func playQuit() {
        playSequence([
            (523, 0.2, 0.2, .sine),     // C5
            (494, 0.2, 0.18, .sine),    // B4
            (440, 0.2, 0.16, .sine),    // A4
            (392, 0.2, 0.14, .sine),    // G4
            (330, 0.3, 0.12, .sine),    // E4
            (262, 0.5, 0.1, .sine),     // C4 (long fade)
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

    func startMusic(_ type: MusicType, preference: Int = 0) {
        if currentMusic == type && musicPlaying { return }
        stopMusic()

        if !engine.isRunning {
            try? engine.start()
        }
        guard engine.isRunning else { return }

        currentMusic = type
        musicPlaying = true

        // Combat music louder, chat music quieter
        musicNode.volume = type == .combat ? 0.7 : type == .chat ? 0.3 : 0.4

        musicQueue.async { [weak self] in
            guard let self = self else { return }

            while self.musicPlaying {
                let steps = self.melodyFor(type, preference: preference)
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

    private func melodyFor(_ type: MusicType, preference: Int = 0) -> [MusicStep] {
        let melodies: [() -> [MusicStep]]
        switch type {
        case .menu:
            melodies = [menuMelody, menuMelody2, menuMelody3]
        case .exploration:
            melodies = [explorationMelody, explorationMelody2, explorationMelody3, explorationMelody4]
        case .combat:
            melodies = [combatMelody, combatMelody2, combatMelody3]
        case .chat:
            melodies = [chatMelody, chatMelody2, chatMelody3]
        }
        if preference >= 1 && preference <= melodies.count {
            return melodies[preference - 1]()
        }
        return melodies.randomElement()!()
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

    // MARK: - Menu Music 2 — "Forgotten Throne"
    // A minor arpeggiated, harp-like with gentle echoes

    private func menuMelody2() -> [MusicStep] {
        let drone: (Double, Float, Waveform) = (110, 0.06, .triangle)     // A2 drone
        let drone2: (Double, Float, Waveform) = (165, 0.04, .sine)        // E3 fifth
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.09, .sine) }
        let h = { (f: Double) -> (Double, Float, Waveform) in (f, 0.05, .triangle) }

        return [
            // Phrase 1 — arpeggiated Am (A C E)
            step(0.4, drone: drone, melody: m(220), extra: drone2),        // A3
            step(0.4, drone: drone, melody: m(262)),                        // C4
            step(0.4, drone: drone, melody: m(330), extra: drone2),        // E4
            step(0.6, drone: drone, melody: m(440), extra: h(262)),        // A4 + C4
            rest(0.3),
            // Phrase 2 — Dm arpeggio (D F A)
            step(0.4, drone: drone, melody: m(294)),                        // D4
            step(0.4, drone: drone, melody: m(349), extra: h(220)),        // F4 + A3
            step(0.5, drone: drone, melody: m(440)),                        // A4
            step(0.8, drone: drone, melody: m(349), extra: drone2),        // F4
            rest(0.3),
            // Phrase 3 — Em descent (E G B)
            step(0.4, drone: drone, melody: m(494), extra: h(392)),        // B4 + G4
            step(0.4, drone: drone, melody: m(392)),                        // G4
            step(0.5, drone: drone, melody: m(330), extra: h(247)),        // E4 + B3
            step(0.9, drone: drone, melody: m(262)),                        // C4
            rest(0.4),
            // Phrase 4 — resolve to Am
            step(0.5, drone: drone, melody: m(523), extra: drone2),        // C5
            step(0.4, drone: drone, melody: m(494)),                        // B4
            step(0.5, drone: drone, melody: m(440), extra: h(330)),        // A4 + E4
            step(0.7, drone: drone, melody: m(330)),                        // E4
            step(1.2, drone: drone, melody: m(220), extra: drone2),        // A3 resolve
            rest(0.7),
        ]
    }

    // MARK: - Menu Music 3 — "Cathedral of Bones"
    // C minor, organ-like with sustained chords and deep bass

    private func menuMelody3() -> [MusicStep] {
        let drone: (Double, Float, Waveform) = (65.4, 0.07, .triangle)    // C2 deep drone
        let drone2: (Double, Float, Waveform) = (98.0, 0.05, .sine)       // G2 fifth
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.10, .triangle) }
        let h = { (f: Double) -> (Double, Float, Waveform) in (f, 0.06, .sine) }

        return [
            // Phrase 1 — solemn Cm chord tones
            step(0.9, drone: drone, melody: m(262), extra: drone2),        // C4
            step(0.7, drone: drone, melody: m(311), extra: h(262)),        // Eb4 + C4
            step(0.9, drone: drone, melody: m(392), extra: drone2),        // G4
            rest(0.4),
            // Phrase 2 — Ab chord (relative major glow)
            step(0.7, drone: drone, melody: m(415), extra: h(330)),        // Ab4 + E4(~)
            step(0.6, drone: drone, melody: m(523), extra: drone2),        // C5
            step(0.8, drone: drone, melody: m(415)),                        // Ab4
            rest(0.3),
            // Phrase 3 — Fm to G (tension)
            step(0.6, drone: drone, melody: m(349), extra: h(262)),        // F4 + C4
            step(0.5, drone: drone, melody: m(311)),                        // Eb4
            step(0.7, drone: drone, melody: m(294), extra: h(247)),        // D4 + B3
            step(1.0, drone: drone, melody: m(392), extra: drone2),        // G4 (dominant)
            rest(0.4),
            // Phrase 4 — descend to Cm resolve
            step(0.5, drone: drone, melody: m(523), extra: h(392)),        // C5 + G4
            step(0.5, drone: drone, melody: m(466)),                        // Bb4
            step(0.6, drone: drone, melody: m(392), extra: h(311)),        // G4 + Eb4
            step(0.7, drone: drone, melody: m(311)),                        // Eb4
            step(1.3, drone: drone, melody: m(262), extra: drone2),        // C4 resolve
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

    // MARK: - Exploration Music 2 — "Whispering Corridors"
    // E minor, minimalist with echoing single notes and long silences

    private func explorationMelody2() -> [MusicStep] {
        let d1: (Double, Float, Waveform) = (82.4, 0.05, .triangle)      // E2 drone
        let d2: (Double, Float, Waveform) = (123.5, 0.03, .sine)         // B2 fifth
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.08, .sine) }
        let g = { (f: Double) -> (Double, Float, Waveform) in (f, 0.04, .triangle) }

        let bG: (Double, Float, Waveform) = (98.0, 0.05, .triangle)     // G2
        let bD: (Double, Float, Waveform) = (73.4, 0.05, .triangle)     // D2

        return [
            // Phrase 1 — single drops in E minor
            step(0.5, drone: d1, melody: m(330)),                          // E4
            rest(0.4),
            step(0.5, drone: d1, melody: m(494), extra: d2),              // B4
            rest(0.3),
            step(0.6, drone: d1, melody: m(392), extra: g(330)),          // G4 + E4
            step(0.8, drone: d1, melody: m(330)),                          // E4
            rest(0.5),

            // Phrase 2 — bass shifts to G, higher melody
            step(0.4, drone: bG, melody: m(587)),                          // D5
            step(0.4, drone: bG, melody: m(494)),                          // B4
            rest(0.3),
            step(0.6, drone: bG, melody: m(523), extra: g(392)),          // C5 + G4
            step(0.7, drone: bG, melody: m(494)),                          // B4
            rest(0.4),

            // Phrase 3 — descending over D bass
            step(0.45, drone: bD, melody: m(440)),                         // A4
            step(0.45, drone: bD, melody: m(392), extra: g(294)),         // G4 + D4
            step(0.5, drone: bD, melody: m(330)),                          // E4
            step(0.7, drone: bD, melody: m(294)),                          // D4
            rest(0.35),

            // Phrase 4 — resolve to E
            step(0.5, drone: d1, melody: m(392), extra: d2),              // G4
            step(0.5, drone: d1, melody: m(349)),                          // F#4
            step(0.8, drone: d1, melody: m(330), extra: g(247)),          // E4 + B3
            rest(0.7),
        ]
    }

    // MARK: - Exploration Music 3 — "The Descent"
    // Bb minor, unsettling with chromatic movement and dissonance

    private func explorationMelody3() -> [MusicStep] {
        let d1: (Double, Float, Waveform) = (58.3, 0.06, .triangle)      // Bb1 low drone
        let d2: (Double, Float, Waveform) = (87.3, 0.04, .sine)          // F2 fifth
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.08, .triangle) }
        let g = { (f: Double) -> (Double, Float, Waveform) in (f, 0.04, .sine) }

        let bDb: (Double, Float, Waveform) = (69.3, 0.06, .triangle)    // Db2
        let bGb: (Double, Float, Waveform) = (92.5, 0.06, .triangle)    // Gb2

        return [
            // Phrase 1 — creeping Bb minor
            step(0.5, drone: d1, melody: m(233)),                          // Bb3
            step(0.4, drone: d1),                                           // drone only
            step(0.5, drone: d1, melody: m(277), extra: d2),              // Db4
            step(0.5, drone: d1, melody: m(349)),                          // F4
            step(0.7, drone: d1, melody: m(311), extra: g(233)),          // Eb4 + Bb3
            rest(0.3),

            // Phrase 2 — chromatic tension over Db bass
            step(0.4, drone: bDb, melody: m(349)),                         // F4
            step(0.4, drone: bDb, melody: m(330)),                         // E4 (chromatic!)
            step(0.5, drone: bDb, melody: m(311), extra: g(277)),         // Eb4 + Db4
            step(0.6, drone: bDb, melody: m(277)),                         // Db4
            rest(0.35),

            // Phrase 3 — Gb bass, tritone dissonance
            step(0.45, drone: bGb, melody: m(370), extra: g(277)),        // Gb4 + Db4
            step(0.45, drone: bGb, melody: m(349)),                        // F4
            step(0.5, drone: bGb, melody: m(311)),                         // Eb4
            step(0.8, drone: bGb, melody: m(277), extra: g(207)),         // Db4 + Ab3
            rest(0.3),

            // Phrase 4 — resolve to Bb
            step(0.5, drone: d1, melody: m(349), extra: d2),              // F4
            step(0.5, drone: d1, melody: m(311)),                          // Eb4
            step(0.7, drone: d1, melody: m(277), extra: g(233)),          // Db4 + Bb3
            step(0.9, drone: d1, melody: m(233), extra: d2),              // Bb3 resolve
            rest(0.6),
        ]
    }

    // MARK: - Exploration Music 4 — "Forgotten Halls"
    // A minor pentatonic, square wave plucks with sparse rhythm — very different feel

    private func explorationMelody4() -> [MusicStep] {
        let d1: (Double, Float, Waveform) = (55.0, 0.05, .sine)           // A1 deep drone
        let d2: (Double, Float, Waveform) = (82.4, 0.03, .triangle)       // E2 fifth
        let p = { (f: Double) -> (Double, Float, Waveform) in (f, 0.10, .square) }   // pluck
        let g = { (f: Double) -> (Double, Float, Waveform) in (f, 0.04, .sine) }     // ghost

        let bC: (Double, Float, Waveform) = (65.4, 0.05, .sine)          // C2
        let bE: (Double, Float, Waveform) = (82.4, 0.05, .sine)          // E2
        let bG: (Double, Float, Waveform) = (98.0, 0.05, .sine)          // G2

        return [
            // Phrase 1 — staccato A minor pentatonic plucks
            step(0.25, drone: d1, melody: p(440)),                          // A4 pluck
            rest(0.35),
            step(0.2, drone: d1, melody: p(523)),                           // C5
            step(0.2, drone: d1, melody: p(587)),                           // D5
            rest(0.5),
            step(0.3, drone: d1, melody: p(659), extra: d2),               // E5
            rest(0.6),
            step(0.2, drone: d1, melody: p(523), extra: g(440)),           // C5 + A4
            rest(0.3),

            // Phrase 2 — descending over C bass, wider spacing
            step(0.3, drone: bC, melody: p(784)),                           // G5
            rest(0.4),
            step(0.25, drone: bC, melody: p(659)),                          // E5
            rest(0.5),
            step(0.3, drone: bC, melody: p(523), extra: g(392)),           // C5 + G4
            rest(0.7),

            // Phrase 3 — rhythmic pattern over E bass
            step(0.15, drone: bE, melody: p(330)),                          // E4
            step(0.15, drone: bE, melody: p(440)),                          // A4
            rest(0.2),
            step(0.15, drone: bE, melody: p(330)),                          // E4
            step(0.15, drone: bE, melody: p(523)),                          // C5
            rest(0.3),
            step(0.4, drone: bE, melody: p(494), extra: g(330)),           // B4 + E4
            rest(0.5),

            // Phrase 4 — resolve with G bass, slower
            step(0.4, drone: bG, melody: p(392)),                           // G4
            step(0.5, drone: bG, melody: p(440), extra: d2),               // A4
            rest(0.3),
            step(0.3, drone: d1, melody: p(330)),                           // E4
            step(0.7, drone: d1, melody: p(220), extra: g(330)),           // A3 + E4
            rest(0.8),
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

    // MARK: - Combat Music 2 — "Shields and Steel"
    // G minor, march-like with strong downbeats and militaristic feel

    private func combatMelody2() -> [MusicStep] {
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.10, .square) }
        let b = { (f: Double) -> (Double, Float, Waveform) in (f, 0.07, .square) }
        let h = { (f: Double) -> (Double, Float, Waveform) in (f, 0.05, .triangle) }
        let p = { (f: Double) -> (Double, Float, Waveform) in (f, 0.03, .noise) }
        let M = { (f: Double) -> (Double, Float, Waveform) in (f, 0.13, .square) }
        let H = { (f: Double) -> (Double, Float, Waveform) in (f, 0.07, .triangle) }

        let t: Double = 0.14  // slightly slower march tempo

        return [
            // === SECTION A: War march ===

            // Bar 1 — G minor march, heavy downbeats
            step(t, drone: b(98.0), melody: m(392), extra: p(80)),        // G2 + G4 + kick
            step(t, drone: b(98.0), extra: p(200)),                        // G2 + snare
            step(t, drone: b(98.0), melody: m(466), extra: h(392)),       // G2 + Bb4 + G4
            step(t, drone: b(98.0), extra: p(200)),                        // G2 + snare
            step(t, drone: b(98.0), melody: m(523), extra: p(80)),        // G2 + C5 + kick
            step(t, drone: b(98.0), extra: p(200)),                        // G2 + snare
            step(t, drone: b(98.0), melody: m(587), extra: h(466)),       // G2 + D5 + Bb4
            step(t, drone: b(98.0), extra: p(200)),                        // snare

            // Bar 2 — bass walks Bb-C
            step(t, drone: b(116.5), melody: m(587), extra: p(80)),       // Bb2 + D5 + kick
            step(t, drone: b(116.5), melody: m(523)),                      // Bb2 + C5
            step(t, drone: b(116.5), melody: m(466), extra: p(200)),      // Bb2 + Bb4 + snare
            step(t, drone: b(116.5), melody: m(392)),                      // Bb2 + G4
            step(t, drone: b(130.8), melody: m(523), extra: p(80)),       // C3 + C5 + kick
            step(t, drone: b(130.8), melody: m(466), extra: h(392)),      // C3 + Bb4 + G4
            step(t * 2, drone: b(130.8), melody: m(392), extra: p(200)), // C3 + G4 held

            // Bar 3 — Eb chord, darker
            step(t, drone: b(77.8), melody: m(466), extra: p(80)),        // Eb2 + Bb4 + kick
            step(t, drone: b(77.8), melody: m(523), extra: h(392)),       // Eb2 + C5 + G4
            step(t, drone: b(77.8), extra: p(200)),                        // Eb2 + snare
            step(t, drone: b(77.8), melody: m(587)),                       // Eb2 + D5
            step(t, drone: b(87.3), melody: m(523), extra: p(80)),        // F2 + C5 + kick
            step(t, drone: b(87.3), melody: m(466), extra: h(349)),       // F2 + Bb4 + F4
            step(t, drone: b(87.3), extra: p(200)),                        // F2 + snare
            step(t, drone: b(87.3), melody: m(392)),                       // F2 + G4

            // Bar 4 — D dominant resolve
            step(t, drone: b(73.4), melody: m(587), extra: p(80)),        // D2 + D5 + kick
            step(t, drone: b(73.4), melody: m(523)),                       // D2 + C5
            step(t, drone: b(73.4), melody: m(466), extra: p(200)),       // D2 + Bb4 + snare
            step(t, drone: b(73.4), melody: m(440), extra: h(294)),       // D2 + A4 + D4
            step(t * 2, drone: b(98.0), melody: m(392), extra: p(80)),   // G2 + G4 resolve
            rest(t),
            step(t, extra: p(200)),                                         // snare fill

            // === SECTION B: Battle cry ===

            // Bar 5 — heroic G minor ascent
            step(t, drone: b(98.0), melody: M(392), extra: p(80)),        // G2 + G4
            step(t, drone: b(98.0), melody: M(466), extra: H(392)),      // G2 + Bb4 + G4
            step(t, drone: b(98.0), extra: p(200)),                        // snare
            step(t, drone: b(98.0), melody: M(523)),                       // G2 + C5
            step(t, drone: b(116.5), melody: M(587), extra: p(80)),       // Bb2 + D5
            step(t, drone: b(116.5), melody: M(659), extra: H(466)),     // Bb2 + E5(!) + Bb4
            step(t, drone: b(116.5), extra: p(200)),                       // snare
            step(t, drone: b(116.5), melody: M(587)),                      // Bb2 + D5

            // Bar 6 — peak and descent
            step(t, drone: b(130.8), melody: M(784), extra: p(80)),       // C3 + G5
            step(t, drone: b(130.8), melody: M(698)),                      // C3 + F5
            step(t, drone: b(130.8), melody: M(659), extra: p(200)),      // C3 + E5(!)
            step(t, drone: b(130.8), melody: M(587), extra: H(466)),     // C3 + D5 + Bb4
            step(t, drone: b(73.4), extra: p(80)),                         // D2 kick
            step(t, drone: b(73.4), melody: M(587), extra: H(440)),      // D2 + D5 + A4
            step(t * 2, drone: b(98.0), melody: M(466), extra: p(200)),  // G2 + Bb4 held

            // Bar 7 — call and response
            step(t, drone: b(98.0), melody: m(392), extra: p(80)),        // G4
            step(t, drone: b(98.0), melody: m(466)),                       // Bb4
            step(t, drone: b(98.0), melody: m(587), extra: p(200)),       // D5
            step(t, drone: b(98.0)),                                        // rest
            step(t, drone: b(77.8), melody: m(311), extra: p(80)),        // Eb4
            step(t, drone: b(77.8), melody: m(466)),                       // Bb4
            step(t, drone: b(77.8), melody: m(587), extra: p(200)),       // D5
            step(t, drone: b(77.8)),                                        // rest

            // Bar 8 — climax + turnaround
            step(t, drone: b(87.3), melody: M(523), extra: p(80)),        // F2 + C5
            step(t, drone: b(87.3), melody: M(466), extra: H(349)),      // F2 + Bb4 + F4
            step(t, drone: b(73.4), melody: M(440), extra: p(200)),       // D2 + A4
            step(t, drone: b(73.4), melody: M(466), extra: H(294)),      // D2 + Bb4 + D4
            step(t, drone: b(98.0), melody: M(392), extra: p(80)),        // G2 + G4
            step(t, drone: b(98.0), melody: M(466), extra: H(294)),      // G2 + Bb4 + D4
            step(t, drone: b(98.0), melody: M(392), extra: p(200)),       // G2 + G4
            step(t, drone: b(98.0), extra: p(80)),                         // kick turnaround
        ]
    }

    // MARK: - Combat Music 3 — "Dragon's Wrath"
    // D minor, fast and chaotic with tremolo bass and chromatic runs

    private func combatMelody3() -> [MusicStep] {
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.10, .square) }
        let b = { (f: Double) -> (Double, Float, Waveform) in (f, 0.07, .square) }
        let h = { (f: Double) -> (Double, Float, Waveform) in (f, 0.05, .triangle) }
        let p = { (f: Double) -> (Double, Float, Waveform) in (f, 0.03, .noise) }
        let M = { (f: Double) -> (Double, Float, Waveform) in (f, 0.13, .square) }
        let H = { (f: Double) -> (Double, Float, Waveform) in (f, 0.07, .triangle) }

        let t: Double = 0.12  // faster tempo for urgency

        return [
            // === SECTION A: Furious assault ===

            // Bar 1 — tremolo D minor bass with rapid melody
            step(t, drone: b(73.4), melody: m(294), extra: p(80)),        // D2 + D4 + kick
            step(t, drone: b(73.4), melody: m(349)),                       // D2 + F4
            step(t, drone: b(73.4), melody: m(440), extra: p(200)),       // D2 + A4 + snare
            step(t, drone: b(73.4), melody: m(523), extra: h(349)),       // D2 + C5 + F4
            step(t, drone: b(73.4), melody: m(587), extra: p(80)),        // D2 + D5 + kick
            step(t, drone: b(73.4), melody: m(523)),                       // D2 + C5
            step(t, drone: b(73.4), melody: m(440), extra: p(200)),       // D2 + A4 + snare
            step(t, drone: b(73.4), melody: m(349)),                       // D2 + F4

            // Bar 2 — chromatic descent over A bass
            step(t, drone: b(55.0), melody: m(523), extra: p(80)),        // A1 + C5 + kick
            step(t, drone: b(55.0), melody: m(494)),                       // A1 + B4
            step(t, drone: b(55.0), melody: m(466), extra: p(200)),       // A1 + Bb4 + snare
            step(t, drone: b(55.0), melody: m(440), extra: h(330)),       // A1 + A4 + E4
            step(t, drone: b(65.4), melody: m(392), extra: p(80)),        // C2 + G4 + kick
            step(t, drone: b(65.4), melody: m(349), extra: h(262)),       // C2 + F4 + C4
            step(t * 2, drone: b(65.4), melody: m(330), extra: p(200)),  // C2 + E4 held

            // Bar 3 — Bb power chord section
            step(t, drone: b(58.3), melody: m(466), extra: p(80)),        // Bb1 + Bb4 + kick
            step(t, drone: b(58.3), melody: m(523), extra: h(349)),       // Bb1 + C5 + F4
            step(t, drone: b(58.3), extra: p(200)),                        // Bb1 + snare
            step(t, drone: b(58.3), melody: m(587)),                       // Bb1 + D5
            step(t, drone: b(65.4), melody: m(523), extra: p(80)),        // C2 + C5 + kick
            step(t, drone: b(65.4), melody: m(466)),                       // C2 + Bb4
            step(t, drone: b(65.4), melody: m(440), extra: p(200)),       // C2 + A4 + snare
            step(t, drone: b(65.4), melody: m(392)),                       // C2 + G4

            // Bar 4 — A dominant resolve
            step(t, drone: b(55.0), melody: m(440), extra: p(80)),        // A1 + A4 + kick
            step(t, drone: b(55.0), melody: m(466), extra: h(349)),       // A1 + Bb4 + F4
            step(t, drone: b(55.0), melody: m(440), extra: p(200)),       // A1 + A4 + snare
            step(t, drone: b(55.0), melody: m(349), extra: h(277)),       // A1 + F4 + Db4
            step(t * 2, drone: b(73.4), melody: m(294), extra: p(80)),   // D2 + D4 resolve
            rest(t),
            step(t, extra: p(200)),                                         // snare fill

            // === SECTION B: Dragon fire ===

            // Bar 5 — blazing ascent
            step(t, drone: b(73.4), melody: M(587), extra: p(80)),        // D2 + D5
            step(t, drone: b(73.4), melody: M(587), extra: H(440)),      // D2 + D5 + A4
            step(t, drone: b(73.4), extra: p(200)),                        // snare
            step(t, drone: b(73.4), melody: M(659), extra: H(440)),      // D2 + E5(!) + A4
            step(t, drone: b(58.3), melody: M(698), extra: p(80)),        // Bb1 + F5
            step(t, drone: b(58.3), melody: M(784), extra: H(587)),      // Bb1 + G5 + D5
            step(t, drone: b(58.3), extra: p(200)),                        // snare
            step(t, drone: b(58.3), melody: M(698)),                       // Bb1 + F5

            // Bar 6 — peak fury
            step(t, drone: b(65.4), melody: M(880), extra: p(80)),        // C2 + A5
            step(t, drone: b(65.4), melody: M(784)),                       // C2 + G5
            step(t, drone: b(65.4), melody: M(698), extra: p(200)),       // C2 + F5
            step(t, drone: b(65.4), melody: M(659), extra: H(523)),      // C2 + E5 + C5
            step(t, drone: b(55.0), extra: p(80)),                         // A1 kick
            step(t, drone: b(55.0), melody: M(659), extra: H(440)),      // A1 + E5 + A4
            step(t * 2, drone: b(73.4), melody: M(587), extra: p(200)),  // D2 + D5 held

            // Bar 7 — frantic alternation
            step(t, drone: b(73.4), melody: m(294), extra: p(80)),        // D4
            step(t, drone: b(73.4), melody: m(440)),                       // A4
            step(t, drone: b(73.4), melody: m(587), extra: p(200)),       // D5
            step(t, drone: b(73.4)),                                        // rest
            step(t, drone: b(58.3), melody: m(349), extra: p(80)),        // F4
            step(t, drone: b(58.3), melody: m(523)),                       // C5
            step(t, drone: b(58.3), melody: m(698), extra: p(200)),       // F5
            step(t, drone: b(58.3)),                                        // rest

            // Bar 8 — final blaze + turnaround
            step(t, drone: b(65.4), melody: M(659), extra: p(80)),        // C2 + E5
            step(t, drone: b(65.4), melody: M(587), extra: H(440)),      // C2 + D5 + A4
            step(t, drone: b(55.0), melody: M(523), extra: p(200)),       // A1 + C5
            step(t, drone: b(55.0), melody: M(440), extra: H(349)),      // A1 + A4 + F4
            step(t, drone: b(73.4), melody: M(349), extra: p(80)),        // D2 + F4
            step(t, drone: b(73.4), melody: M(330), extra: H(294)),      // D2 + E4 + D4
            step(t, drone: b(73.4), melody: M(294), extra: p(200)),       // D2 + D4
            step(t, drone: b(73.4), extra: p(80)),                         // kick turnaround
        ]
    }

    // MARK: - Chat Melodies
    // Intimate, ambient mood — hushed conversation in a dungeon

    // Chat Melody 1: "Whispered Council" — A minor, soft sine drones with sparse high notes
    private func chatMelody() -> [MusicStep] {
        let d: (Double, Float, Waveform) = (110, 0.04, .sine)          // A2 drone
        let d2: (Double, Float, Waveform) = (165, 0.025, .sine)        // E3 fifth
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.06, .sine) }
        let g = { (f: Double) -> (Double, Float, Waveform) in (f, 0.03, .sine) }  // ghost

        return [
            // Phrase 1 — gentle opening
            step(0.8, drone: d, melody: m(440)),                          // A4
            rest(0.4),
            step(0.6, drone: d, melody: m(523), extra: d2),             // C5
            step(0.9, drone: d, melody: m(494)),                          // B4
            rest(0.5),
            step(0.7, drone: d, melody: m(440), extra: g(330)),         // A4 + E4
            rest(0.6),

            // Phrase 2 — contemplative
            step(0.8, drone: d, melody: m(392), extra: d2),             // G4
            rest(0.3),
            step(0.6, drone: d, melody: m(440)),                          // A4
            step(1.0, drone: d, melody: m(523), extra: g(392)),         // C5 + G4
            rest(0.7),

            // Phrase 3 — deeper
            step(0.7, drone: d, melody: m(330), extra: d2),             // E4
            step(0.8, drone: d, melody: m(349)),                          // F4
            rest(0.4),
            step(0.9, drone: d, melody: m(392), extra: g(262)),         // G4 + C4
            step(1.1, drone: d, melody: m(330)),                          // E4
            rest(0.8),

            // Phrase 4 — resolve
            step(0.6, drone: d, melody: m(349), extra: d2),             // F4
            step(0.7, drone: d, melody: m(330)),                          // E4
            step(1.2, drone: d, melody: m(440), extra: g(330)),         // A4 + E4
            rest(1.0),
        ]
    }

    // Chat Melody 2: "Flickering Shadows" — E minor, triangle waves, more movement
    private func chatMelody2() -> [MusicStep] {
        let d: (Double, Float, Waveform) = (82.4, 0.04, .triangle)     // E2 drone
        let d2: (Double, Float, Waveform) = (123.5, 0.025, .sine)      // B2 fifth
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.06, .triangle) }
        let g = { (f: Double) -> (Double, Float, Waveform) in (f, 0.03, .sine) }

        return [
            // Phrase 1 — tentative
            step(0.5, drone: d, melody: m(330)),                          // E4
            step(0.6, drone: d, melody: m(392), extra: d2),             // G4
            rest(0.3),
            step(0.7, drone: d, melody: m(370)),                          // F#4
            step(0.9, drone: d, melody: m(330), extra: g(247)),         // E4 + B3
            rest(0.6),

            // Phrase 2 — rising
            step(0.5, drone: d, melody: m(440), extra: d2),             // A4
            step(0.6, drone: d, melody: m(494)),                          // B4
            step(0.8, drone: d, melody: m(523), extra: g(330)),         // C5 + E4
            rest(0.4),
            step(0.7, drone: d, melody: m(494)),                          // B4
            step(0.9, drone: d, melody: m(392)),                          // G4
            rest(0.5),

            // Phrase 3 — descending
            step(0.6, drone: d, melody: m(440), extra: d2),             // A4
            step(0.7, drone: d, melody: m(370)),                          // F#4
            rest(0.3),
            step(0.8, drone: d, melody: m(330), extra: g(247)),         // E4 + B3
            step(1.0, drone: d, melody: m(294)),                          // D4
            rest(0.4),
            step(1.1, drone: d, melody: m(330), extra: d2),             // E4
            rest(0.9),
        ]
    }

    // Chat Melody 3: "Candlelit Murmurs" — C minor, warm sine, slow and sparse
    private func chatMelody3() -> [MusicStep] {
        let d: (Double, Float, Waveform) = (65.4, 0.04, .sine)         // C2 drone
        let d2: (Double, Float, Waveform) = (98.0, 0.025, .sine)       // G2 fifth
        let m = { (f: Double) -> (Double, Float, Waveform) in (f, 0.055, .sine) }
        let g = { (f: Double) -> (Double, Float, Waveform) in (f, 0.03, .sine) }

        return [
            // Phrase 1 — slow opening
            step(1.0, drone: d, melody: m(311), extra: d2),             // Eb4
            rest(0.6),
            step(0.8, drone: d, melody: m(349)),                          // F4
            step(1.2, drone: d, melody: m(392), extra: g(311)),         // G4 + Eb4
            rest(0.8),

            // Phrase 2 — sparse
            step(0.9, drone: d, melody: m(466), extra: d2),             // Bb4
            rest(0.5),
            step(0.7, drone: d, melody: m(392)),                          // G4
            rest(0.4),
            step(1.0, drone: d, melody: m(349), extra: g(262)),         // F4 + C4
            rest(0.7),

            // Phrase 3 — gentle tension
            step(0.8, drone: d, melody: m(311), extra: d2),             // Eb4
            step(0.9, drone: d, melody: m(294)),                          // D4
            rest(0.5),
            step(1.1, drone: d, melody: m(262), extra: g(196)),         // C4 + G3
            rest(0.9),

            // Phrase 4 — resolve into silence
            step(0.7, drone: d, melody: m(311), extra: d2),             // Eb4
            step(1.3, drone: d, melody: m(262)),                          // C4
            rest(1.2),
        ]
    }
}

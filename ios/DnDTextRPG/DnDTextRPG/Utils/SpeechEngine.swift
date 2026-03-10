//
//  SpeechEngine.swift
//  DnDTextRPG
//
//  Text-to-speech for DM narration using AVSpeechSynthesizer
//

import AVFoundation

class SpeechEngine: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechEngine()

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Settings

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "speech_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "speech_enabled") }
    }

    /// Speech rate: 0.0 (slowest) to 1.0 (fastest). Default 0.45
    var rate: Float {
        get {
            if UserDefaults.standard.object(forKey: "speech_rate") == nil {
                return 0.45
            }
            return UserDefaults.standard.float(forKey: "speech_rate")
        }
        set { UserDefaults.standard.set(newValue, forKey: "speech_rate") }
    }

    /// Pitch: 0.5 (low) to 2.0 (high). Default 0.9 for a deeper DM voice
    var pitch: Float {
        get {
            if UserDefaults.standard.object(forKey: "speech_pitch") == nil {
                return 0.9
            }
            return UserDefaults.standard.float(forKey: "speech_pitch")
        }
        set { UserDefaults.standard.set(newValue, forKey: "speech_pitch") }
    }

    /// Voice identifier (nil = system default)
    var voiceIdentifier: String? {
        get { UserDefaults.standard.string(forKey: "speech_voice_id") }
        set { UserDefaults.standard.set(newValue, forKey: "speech_voice_id") }
    }

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    /// Completion callback — called on main queue when an utterance finishes
    var onFinish: (() -> Void)?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        #if os(iOS)
        do {
            // Use .playback to override silent switch
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Silent failure
        }
        #endif
    }

    private func restoreAudioSession() {
        #if os(iOS)
        do {
            // Restore to ambient for game music
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Silent failure
        }
        #endif
    }

    // MARK: - Delegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        SoundManager.shared.unduckMusic()
        restoreAudioSession()
        if let handler = onFinish {
            onFinish = nil
            DispatchQueue.main.async { handler() }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        SoundManager.shared.unduckMusic()
        restoreAudioSession()
    }

    // MARK: - Speak

    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
        speakDirect(text)
    }

    /// Speak using DM voice regardless of isEnabled — used for read-aloud button
    func speakAloud(_ text: String) {
        speakDirect(text)
    }

    /// Speak without checking isEnabled — used for previews
    private func speakDirect(_ text: String) {
        guard !text.isEmpty else { return }

        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        configureAudioSession()
        SoundManager.shared.duckMusic()

        // Clean text — remove markdown-style formatting
        let cleaned = text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.preUtteranceDelay = 0.1

        if let voiceId = voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            // Default to a good English voice
            utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        }

        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        SoundManager.shared.unduckMusic()
    }

    var isPaused: Bool {
        synthesizer.isPaused
    }

    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
    }

    func resume() {
        if synthesizer.isPaused {
            SoundManager.shared.duckMusic()
            synthesizer.continueSpeaking()
        }
    }

    // MARK: - Available Voices

    struct VoiceOption {
        let identifier: String
        let name: String
        let language: String
        let quality: String
        let label: String  // Friendly display label
    }

    /// Check if text-to-speech is available on this device
    var isAvailable: Bool {
        return !AVSpeechSynthesisVoice.speechVoices().isEmpty
    }

    /// Whether any high-quality (enhanced/premium) voices are installed
    var hasHighQualityVoices: Bool {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .contains { $0.quality.rawValue >= AVSpeechSynthesisVoiceQuality.enhanced.rawValue }
    }

    /// Returns curated English voices — best quality per name, with friendly labels
    /// Novelty/unclear voices excluded from companion use
    private static let excludedVoiceNames: Set<String> = [
        "Bells", "Bubbles", "Bad News", "Bahh", "Boing",
        "Cellos", "Good News", "Jester", "Organ", "Superstar",
        "Trinoids", "Whisper", "Wobble", "Zarvox", "Albert",
        "Fred", "Hysterical", "Junior", "Kathy", "Princess",
        "Ralph", "Eddy", "Reed", "Rocko", "Sandy", "Shelley",
    ]

    func availableVoices() -> [VoiceOption] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && !Self.excludedVoiceNames.contains($0.name) }

        // Deduplicate: keep only the highest quality version of each voice name
        var bestByName: [String: AVSpeechSynthesisVoice] = [:]
        for voice in allVoices {
            if let existing = bestByName[voice.name] {
                if voice.quality.rawValue > existing.quality.rawValue {
                    bestByName[voice.name] = voice
                }
            } else {
                bestByName[voice.name] = voice
            }
        }

        let deduped = Array(bestByName.values).sorted { v1, v2 in
            // Premium first, then enhanced, then standard
            if v1.quality.rawValue != v2.quality.rawValue {
                return v1.quality.rawValue > v2.quality.rawValue
            }
            return v1.name < v2.name
        }

        return deduped.map { voice in
            let qualityLabel: String
            switch voice.quality {
            case .premium: qualityLabel = "Premium"
            case .enhanced: qualityLabel = "Enhanced"
            default: qualityLabel = "Standard"
            }

            let langCode = String(voice.language.suffix(2)).uppercased()
            let accent = langCode == "GB" ? "British" : (langCode == "AU" ? "Australian" : (langCode == "IE" ? "Irish" : (langCode == "ZA" ? "South African" : (langCode == "IN" ? "Indian" : "American"))))

            // Gender indicator
            let genderTag: String
            if #available(iOS 16.0, macOS 13.0, *) {
                switch voice.gender {
                case .female: genderTag = "F"
                case .male: genderTag = "M"
                default: genderTag = "U"
                }
            } else {
                genderTag = "U"
            }

            // Friendly label
            let label = "\(voice.name) — \(accent), \(genderTag)"

            return VoiceOption(
                identifier: voice.identifier,
                name: voice.name,
                language: langCode,
                quality: qualityLabel,
                label: label
            )
        }
    }

    /// Preview a voice with a sample DM line
    func preview() {
        let samples = [
            "You enter a dimly lit chamber. The air smells of ancient dust and forgotten magic.",
            "Roll for initiative, adventurer. Danger lurks in the shadows ahead.",
            "A mysterious door stands before you, covered in glowing runes.",
        ]
        speakDirect(samples.randomElement()!)
    }

    /// Preview a specific voice by identifier
    func previewVoice(_ identifier: String) {
        let samples = [
            "At your service. Lead on, adventurer.",
            "I've got your back. Let's press on.",
            "Something stirs ahead. Stay alert.",
        ]
        speakWithVoice(samples.randomElement()!, voiceId: identifier, pitch: 1.0)
    }

    // MARK: - Companion Voice Mode

    enum CompanionVoiceMode: String {
        case random = "random"
        case characterAppropriate = "character"
    }

    var companionVoiceMode: CompanionVoiceMode {
        get {
            let raw = UserDefaults.standard.string(forKey: "companion_voice_mode") ?? "character"
            return CompanionVoiceMode(rawValue: raw) ?? .characterAppropriate
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "companion_voice_mode") }
    }

    // MARK: - Per-Character Voice Overrides

    /// Manual voice overrides keyed by character name
    private var voiceOverrides: [String: String] {
        get { (UserDefaults.standard.dictionary(forKey: "character_voice_overrides") as? [String: String]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "character_voice_overrides") }
    }

    func voiceOverride(forCharacter name: String) -> String? {
        return voiceOverrides[name]
    }

    func setVoiceOverride(forCharacter name: String, voiceId: String?) {
        var overrides = voiceOverrides
        overrides[name] = voiceId
        voiceOverrides = overrides
    }

    // MARK: - Adventurer Voice Pool

    /// Voice identifiers enabled for companions (stored as JSON array)
    var adventurerVoicePool: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "adventurer_voice_pool"),
                  let pool = try? JSONDecoder().decode([String].self, from: data),
                  !pool.isEmpty else {
                return defaultAdventurerPool()
            }
            return pool
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "adventurer_voice_pool")
            }
        }
    }

    /// Default pool — all available English voices for maximum variety
    func defaultAdventurerPool() -> [String] {
        let voices = availableVoices()
        return voices.map { $0.identifier }
    }

    /// Speak as a companion character — picks a voice based on mode setting
    func speakAsCharacter(_ text: String, characterName: String, race: String? = nil, characterClass: String? = nil) {
        guard isEnabled, !text.isEmpty else { return }
        let pool = adventurerVoicePool
        guard !pool.isEmpty else {
            speakDirect(text)
            return
        }

        // Check for manual override first
        if let overrideId = voiceOverride(forCharacter: characterName), pool.contains(overrideId) {
            speakWithVoice(text, voiceId: overrideId, pitch: 1.0)
            return
        }

        if let race = race, let charClass = characterClass {
            let profile = characterVoiceProfile(name: characterName, race: race, characterClass: charClass)
            let voiceId = bestVoiceForProfile(profile, pool: pool, name: characterName)
            speakWithVoice(text, voiceId: voiceId, pitch: profile.pitch, rateOverride: profile.rate)
        } else {
            // Fallback — consistent voice per name
            let index = abs(characterName.hashValue) % pool.count
            speakWithVoice(text, voiceId: pool[index], pitch: 1.0)
        }
    }

    /// Get the display name of the voice assigned to a character
    func voiceNameForCharacter(name: String, race: String, characterClass: String) -> String? {
        let pool = adventurerVoicePool
        guard !pool.isEmpty else { return nil }
        let voiceId: String
        if let overrideId = voiceOverride(forCharacter: name), pool.contains(overrideId) {
            voiceId = overrideId
        } else {
            let profile = characterVoiceProfile(name: name, race: race, characterClass: characterClass)
            voiceId = bestVoiceForProfile(profile, pool: pool, name: name)
        }
        return AVSpeechSynthesisVoice(identifier: voiceId)?.name
    }

    // MARK: - Character Voice Profiles

    enum VoiceGenderPref { case male, female, any }

    struct CharacterVoiceProfile {
        let pitch: Float           // 0.7 (deep) to 1.3 (high)
        let rate: Float?           // nil = use global rate setting
        let preferredAccents: [String]  // ordered preference: "British", "American", "Australian", "Irish"
        var preferredGender: VoiceGenderPref = .any
    }

    /// Build a voice profile based on race, class, and name characteristics
    private func characterVoiceProfile(name: String, race: String, characterClass: String) -> CharacterVoiceProfile {
        let raceLower = race.lowercased()
        let classLower = characterClass.lowercased()

        // Base pitch from race
        var pitch: Float = 1.0
        var preferredAccents: [String] = ["British", "American", "Australian", "Irish"]
        var rateMod: Float = 0.0

        // Race-based pitch & accent
        if raceLower.contains("dwarf") {
            pitch = 0.75               // deep, gruff
            preferredAccents = ["Irish", "British", "Australian", "American"]
            rateMod = -0.03            // slightly slower, deliberate
        } else if raceLower.contains("elf") {
            pitch = 1.1                // clear, melodic
            preferredAccents = ["British", "Australian", "Irish", "American"]
            rateMod = 0.02             // slightly quicker, fluid
        } else if raceLower.contains("halfling") || raceLower.contains("gnome") {
            pitch = 1.2                // light, cheerful
            preferredAccents = ["British", "Irish", "Australian", "American"]
            rateMod = 0.03             // perky
        } else if raceLower.contains("orc") {
            pitch = 0.72               // very deep, rumbling
            preferredAccents = ["American", "Australian", "British", "Irish"]
            rateMod = -0.04            // slow, menacing
        } else if raceLower.contains("dragonborn") {
            pitch = 0.78               // deep, resonant
            preferredAccents = ["American", "British", "Australian", "Irish"]
            rateMod = -0.02
        } else if raceLower.contains("tiefling") {
            pitch = 0.95               // slightly dusky
            preferredAccents = ["British", "American", "Irish", "Australian"]
            rateMod = 0.01
        }
        // Human stays at 1.0 baseline

        // Class-based adjustments
        if classLower == "barbarian" {
            pitch -= 0.08              // deeper
            rateMod -= 0.03            // slower, forceful
        } else if classLower == "wizard" {
            pitch += 0.05              // slightly higher, scholarly
            rateMod += 0.02            // measured, precise
        } else if classLower == "rogue" {
            rateMod += 0.03            // quick, sly
        } else if classLower == "cleric" {
            pitch += 0.03              // calm, warm
            rateMod -= 0.01            // measured
        } else if classLower == "ranger" {
            rateMod += 0.01            // quiet, steady
        }
        // Fighter stays neutral

        // Name-based micro-adjustments for uniqueness
        let nameHash = abs(name.hashValue)
        let namePitchTweak = Float(nameHash % 7) * 0.02 - 0.06  // -0.06 to +0.06
        pitch += namePitchTweak

        // Names with hard consonants (K, G, D, B) → slightly deeper
        let hardConsonants = "kgdbzx"
        let firstChar = name.lowercased().prefix(1)
        if hardConsonants.contains(firstChar) {
            pitch -= 0.03
        }
        // Names starting with soft sounds → slightly lighter
        let softStarts = "lsfwv"
        if softStarts.contains(firstChar) {
            pitch += 0.03
        }

        // Clamp pitch to safe range
        pitch = max(0.65, min(1.35, pitch))

        let finalRate: Float? = rateMod != 0 ? max(0.3, min(0.65, rate + rateMod)) : nil

        // Gender heuristic from name endings and pitch
        let nameLower = name.lowercased()
        let femaleEndings = ["a", "ia", "na", "ra", "la", "elle", "ette", "ine", "lyn", "wen", "iel"]
        let femaleNames: Set<String> = ["alice", "aria", "bella", "elena", "elara", "luna", "lyra", "mira", "nora", "rose", "sage", "thea", "willow", "ivy", "fern", "dawn", "eve", "mae", "joy", "hope", "faith", "grace", "ruby", "pearl", "jade", "gwen", "lux"]
        var gender: VoiceGenderPref = .any
        if femaleNames.contains(nameLower) || femaleEndings.contains(where: { nameLower.hasSuffix($0) }) {
            gender = .female
        } else if pitch < 0.85 {
            gender = .male  // deep voice → likely male character
        } else if pitch > 1.15 {
            gender = .female  // high pitch → likely female character
        }

        return CharacterVoiceProfile(pitch: pitch, rate: finalRate, preferredAccents: preferredAccents, preferredGender: gender)
    }

    /// Pick the best voice from pool for a character profile
    private func bestVoiceForProfile(_ profile: CharacterVoiceProfile, pool: [String], name: String) -> String {
        let poolVoiceObjects = pool.compactMap { AVSpeechSynthesisVoice(identifier: $0) }
        guard !poolVoiceObjects.isEmpty else {
            let index = abs(name.hashValue) % max(1, pool.count)
            return pool.isEmpty ? "" : pool[index]
        }

        // Score each pool voice by accent preference and gender match
        var scored: [(String, Int)] = []
        for voice in poolVoiceObjects {
            var score = 0

            // Accent scoring
            let langCode = String(voice.language.suffix(2)).uppercased()
            let accent = langCode == "GB" ? "British" : (langCode == "AU" ? "Australian" : (langCode == "IE" ? "Irish" : (langCode == "ZA" ? "South African" : (langCode == "IN" ? "Indian" : "American"))))
            for (i, pref) in profile.preferredAccents.enumerated() {
                if accent == pref {
                    score += (profile.preferredAccents.count - i) * 10
                    break
                }
            }

            // Gender scoring (strong preference)
            if #available(iOS 16.0, macOS 13.0, *) {
                if profile.preferredGender != .any {
                    let isMatch = (profile.preferredGender == .female && voice.gender == .female) ||
                                  (profile.preferredGender == .male && voice.gender == .male)
                    score += isMatch ? 50 : 0
                }
            }

            // Use name hash to break ties consistently
            score += abs(name.hashValue ^ voice.identifier.hashValue) % 5
            scored.append((voice.identifier, score))
        }

        // Sort by score descending, pick first
        scored.sort { $0.1 > $1.1 }

        if let best = scored.first {
            return best.0
        }

        let index = abs(name.hashValue) % pool.count
        return pool[index]
    }

    /// Speak with a specific voice, pitch, and optional rate override
    private func speakWithVoice(_ text: String, voiceId: String, pitch overridePitch: Float, rateOverride: Float? = nil) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        configureAudioSession()
        SoundManager.shared.duckMusic()

        let cleaned = text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = rateOverride ?? rate
        utterance.pitchMultiplier = overridePitch
        utterance.preUtteranceDelay = 0.1

        if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        }

        synthesizer.speak(utterance)
    }

    /// Speak text as an NPC using a specific voice identifier
    func speakAsNPC(_ text: String, voiceId: String) {
        guard !text.isEmpty else { return }
        // NPC voices use a slightly varied pitch for character
        speakWithVoice(text, voiceId: voiceId, pitch: 1.0)
    }

    /// Pick a random voice for an NPC, excluding DM voice and player character voices
    func pickNPCVoice(excludingCharacterNames: [String] = []) -> String? {
        let allVoices = availableVoices()
        guard !allVoices.isEmpty else { return nil }

        // Collect voices to exclude
        var excludedIds: Set<String> = []
        // Exclude DM voice
        if let dmVoice = voiceIdentifier {
            excludedIds.insert(dmVoice)
        }
        // Exclude player character voices
        for name in excludingCharacterNames {
            if let overrideId = voiceOverride(forCharacter: name) {
                excludedIds.insert(overrideId)
            }
        }

        let candidates = allVoices.filter { !excludedIds.contains($0.identifier) }
        return candidates.randomElement()?.identifier ?? allVoices.randomElement()?.identifier
    }

    // MARK: - Accessibility Help

    var accessibilityHelpEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "accessibility_help") }
        set { UserDefaults.standard.set(newValue, forKey: "accessibility_help") }
    }

    /// Speak accessibility help text (instructions, navigation) in a distinct voice
    func speakAccessibility(_ text: String) {
        guard accessibilityHelpEnabled, isEnabled, !text.isEmpty else { return }
        // Use a higher pitch and slightly faster rate for accessibility narration
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        configureAudioSession()
        SoundManager.shared.duckMusic()

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = min(rate + 0.05, 0.6)
        utterance.pitchMultiplier = 1.15  // Higher than DM, distinct
        utterance.preUtteranceDelay = 0.05
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        synthesizer.speak(utterance)
    }
}

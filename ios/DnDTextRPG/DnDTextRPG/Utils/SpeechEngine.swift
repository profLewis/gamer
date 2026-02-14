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
        restoreAudioSession()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        restoreAudioSession()
    }

    // MARK: - Speak

    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
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
    func availableVoices() -> [VoiceOption] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }

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

            // Friendly label
            let label = "\(voice.name) — \(accent), \(qualityLabel)"

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
}

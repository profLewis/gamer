//
//  VoiceInputManager.swift
//  DnDTextRPG
//
//  Speech recognition for voice input in chat
//

import AVFoundation
#if !os(tvOS)
import Speech

class VoiceInputManager: ObservableObject {
    static let shared = VoiceInputManager()

    @Published var isListening = false
    @Published var transcript = ""
    /// Why listening didn't start, in plain words -- shown on screen. Every
    /// failure here used to be silent, so a microphone that never listened
    /// looked exactly like one that heard nothing.
    @Published var lastError: String?
    /// True while the microphone is open -- the speech engine then leaves
    /// the audio session alone (switching it to playback-only cut the mic off
    /// every time the DM spoke).
    static var micOpen = false
    /// True while the game is speaking, and a moment after: the mic passes
    /// no sound at all to the recogniser, so the DM can never be heard as a
    /// command and the game can never play itself.
    static var gameSpeaking = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    private let audioEngine = AVAudioEngine()  // Separate from SoundManager's engine
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?

    // MARK: Continuous mode
    /// Keep listening after each command (Settings > Accessibility): press
    /// the mic once, speak a command, pause (or say the enter word) and it is
    /// sent; speak the next. Press the mic again to stop. On by default.
    static var continuous: Bool {
        UserDefaults.standard.object(forKey: "voiceContinuous") == nil ? true : UserDefaults.standard.bool(forKey: "voiceContinuous")
    }
    static let enterWords = ["enter", "go", "done", "over"]
    /// Said at the end of a command, it sends it at once.
    static var enterWord: String { UserDefaults.standard.string(forKey: "voiceEnterWord") ?? "enter" }

    /// While the game itself is talking, and a moment after, what the mic
    /// hears is the game -- not the player. It used to be sent as a command,
    /// the DM answered it aloud, the mic heard that... a loop.
    private var quietUntil = Date.distantPast
    private var ttsWatch: Timer?
    private var wasSpeaking = false

    private var onComplete: ((String) -> Void)?

    private init() {}

    // MARK: - Availability

    var isAvailable: Bool {
        guard let recognizer = speechRecognizer else { return false }
        return recognizer.isAvailable
    }

    var isAuthorised: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized && micGranted
    }

    /// Microphone permission, separate from speech recognition -- only the
    /// latter used to be asked for, so the first attempt could fail before
    /// the system had ever asked about the microphone.
    private var micGranted: Bool {
        #if os(iOS) || os(visionOS)
        if #available(iOS 17.0, *) { return AVAudioApplication.shared.recordPermission == .granted }
        return AVAudioSession.sharedInstance().recordPermission == .granted
        #elseif os(macOS)
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        #else
        return false
        #endif
    }

    private func requestMic(_ done: @escaping (Bool) -> Void) {
        #if os(iOS) || os(visionOS)
        if #available(iOS 17.0, *) { AVAudioApplication.requestRecordPermission { done($0) } }
        else { AVAudioSession.sharedInstance().requestRecordPermission { done($0) } }
        #elseif os(macOS)
        AVCaptureDevice.requestAccess(for: .audio) { done($0) }
        #else
        done(false)
        #endif
    }

    func requestAuthorisation(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.lastError = "Speech recognition is switched off for this game — turn it on in Settings > Privacy & Security > Speech Recognition."
                    completion(false)
                }
                return
            }
            self.requestMic { granted in
                DispatchQueue.main.async {
                    if !granted { self.lastError = "The microphone is switched off for this game — turn it on in Settings > Privacy & Security > Microphone." }
                    completion(granted)
                }
            }
        }
    }

    // MARK: - Start / Stop

    func startListening(onTranscript: @escaping (String) -> Void, onComplete: @escaping (String) -> Void) {
        guard !isListening else { return }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            lastError = "Speech recognition isn't available just now — it may need Dictation turned on, or a network connection."
            return
        }
        lastError = nil

        self.onComplete = onComplete

        // Taking turns: the game stops talking when you start to (the mic
        // otherwise hears the game reading the screen and takes it for you).
        // Continuous mode is always listening, and filters the game's voice out.
        if !Self.continuous { SpeechEngine.shared.stop() }

        // Stop game music during voice input
        SoundManager.shared.duckMusic()

        do {
            // Configure audio session for recording
            #if os(iOS) || os(visionOS)
            let audioSession = AVAudioSession.sharedInstance()
            // Play-and-record, so the narrator is still heard while the mic is
            // open (continuous mode keeps it open); the game's own voice is
            // filtered out of what's recognised (see quietUntil).
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let request = recognitionRequest else { return }
            request.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard !VoiceInputManager.gameSpeaking else { return }
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            Self.micOpen = true
            DispatchQueue.main.async {
                self.isListening = true
                self.transcript = ""
            }

            self.onTranscript = onTranscript
            startTask(recognizer)
            startTTSWatch()
        } catch {
            lastError = "Couldn't start the microphone (\(error.localizedDescription))."
            finishListening(with: "")
        }
    }

    private var onTranscript: ((String) -> Void)?

    /// One recognition pass. In continuous mode a new one starts after each
    /// command, and whenever the game has just finished speaking, so nothing
    /// it heard is carried into the next command.
    private func startTask(_ recognizer: SFSpeechRecognizer) {
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self, self.recognitionRequest === request else { return }
            if let result = result {
                // The game's own voice: ignore it entirely.
                if SpeechEngine.shared.isSpeaking || Date() < self.quietUntil {
                    DispatchQueue.main.async { self.transcript = ""; self.onTranscript?("") }
                    return
                }
                var text = result.bestTranscription.formattedString
                // "…north enter" -> send "north" now.
                let word = Self.enterWord.lowercased()
                let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                if lower == word || lower.hasSuffix(" " + word) {
                    text = String(lower.dropLast(word.count)).trimmingCharacters(in: .whitespaces)
                    self.submit(text)
                    return
                }
                DispatchQueue.main.async {
                    self.transcript = text
                    self.onTranscript?(text)
                }
                // Pause to send: two seconds of quiet.
                self.resetSilenceTimer()
                if result.isFinal { self.submit(text) }
            }
            if error != nil, self.isListening, !Self.continuous {
                self.finishListening(with: self.transcript)
            }
        }
    }

    /// A command is ready. One-shot mode stops here; continuous mode hands
    /// it over and listens for the next.
    private func submit(_ text: String) {
        silenceTimer?.invalidate()
        guard Self.continuous else { finishListening(with: text); return }
        let finalText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async {
            self.transcript = ""
            self.onTranscript?("")
            if !finalText.isEmpty { self.onComplete?(finalText) }
            // What the game says in reply must not be heard as the next command.
            self.quietUntil = Date().addingTimeInterval(0.8)
            if let r = self.speechRecognizer, self.isListening { self.startTask(r) }
        }
    }

    /// Watches the game's voice: while it speaks the mic is deaf, and when it
    /// stops, recognition starts afresh a moment later.
    private func startTTSWatch() {
        ttsWatch?.invalidate()
        ttsWatch = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, self.isListening else { return }
            let speaking = SpeechEngine.shared.isSpeaking
            if speaking {
                self.quietUntil = Date().addingTimeInterval(0.8)
                self.silenceTimer?.invalidate()
            } else if self.wasSpeaking, let r = self.speechRecognizer {
                self.startTask(r)
            }
            self.wasSpeaking = speaking
        }
    }

    func stopListening() {
        finishListening(with: Self.continuous ? "" : transcript)
    }

    private func finishListening(with text: String) {
        silenceTimer?.invalidate()
        silenceTimer = nil
        ttsWatch?.invalidate()
        ttsWatch = nil
        wasSpeaking = false
        Self.micOpen = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        // Restore audio session for game music
        #if os(iOS) || os(visionOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        #endif

        SoundManager.shared.unduckMusic()

        let finalText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.main.async {
            self.isListening = false
            if !finalText.isEmpty {
                self.onComplete?(finalText)
            }
            self.onComplete = nil
            self.transcript = ""
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self, self.isListening, !self.transcript.isEmpty else { return }
            self.submit(self.transcript)
        }
    }
}

#else

/// tvOS has no Speech framework / dictation model like this — the remote
/// has no microphone-driven text input in this form. Same public surface
/// as the real manager, permanently unavailable, so call sites don't need
/// their own platform checks.
class VoiceInputManager: ObservableObject {
    static let shared = VoiceInputManager()

    @Published var isListening = false
    @Published var transcript = ""
    /// Why listening didn't start, in plain words -- shown on screen. Every
    /// failure here used to be silent, so a microphone that never listened
    /// looked exactly like one that heard nothing.
    @Published var lastError: String?
    /// True while the microphone is open -- the speech engine then leaves
    /// the audio session alone (switching it to playback-only cut the mic off
    /// every time the DM spoke).
    static var micOpen = false
    /// True while the game is speaking, and a moment after: the mic passes
    /// no sound at all to the recogniser, so the DM can never be heard as a
    /// command and the game can never play itself.
    static var gameSpeaking = false

    private init() {}

    var isAvailable: Bool { false }
    var isAuthorised: Bool { false }

    func requestAuthorisation(completion: @escaping (Bool) -> Void) {
        completion(false)
    }

    func startListening(onTranscript: @escaping (String) -> Void, onComplete: @escaping (String) -> Void) {
        onComplete("")
    }

    func stopListening() {}
}

#endif

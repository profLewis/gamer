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

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    private let audioEngine = AVAudioEngine()  // Separate from SoundManager's engine
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?

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
        #if os(iOS)
        if #available(iOS 17.0, *) { return AVAudioApplication.shared.recordPermission == .granted }
        return AVAudioSession.sharedInstance().recordPermission == .granted
        #elseif os(macOS)
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        #else
        return false
        #endif
    }

    private func requestMic(_ done: @escaping (Bool) -> Void) {
        #if os(iOS)
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

        // Stop game music during voice input
        SoundManager.shared.duckMusic()

        do {
            // Configure audio session for recording
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let request = recognitionRequest else { return }
            request.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            DispatchQueue.main.async {
                self.isListening = true
                self.transcript = ""
            }

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.transcript = text
                        onTranscript(text)
                    }

                    // Reset silence timer — auto-submit after 2 seconds of silence
                    self.resetSilenceTimer()

                    if result.isFinal {
                        self.finishListening(with: text)
                    }
                }

                if error != nil {
                    self.finishListening(with: self.transcript)
                }
            }
        } catch {
            lastError = "Couldn't start the microphone (\(error.localizedDescription))."
            finishListening(with: "")
        }
    }

    func stopListening() {
        finishListening(with: transcript)
    }

    private func finishListening(with text: String) {
        silenceTimer?.invalidate()
        silenceTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        // Restore audio session for game music
        #if os(iOS)
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
            guard let self = self, self.isListening else { return }
            self.finishListening(with: self.transcript)
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

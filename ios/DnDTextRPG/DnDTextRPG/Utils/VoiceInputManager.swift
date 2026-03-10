//
//  VoiceInputManager.swift
//  DnDTextRPG
//
//  Speech recognition for voice input in chat
//

import Speech
import AVFoundation

class VoiceInputManager: ObservableObject {
    static let shared = VoiceInputManager()

    @Published var isListening = false
    @Published var transcript = ""

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
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    func requestAuthorisation(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    // MARK: - Start / Stop

    func startListening(onTranscript: @escaping (String) -> Void, onComplete: @escaping (String) -> Void) {
        guard !isListening, let recognizer = speechRecognizer, recognizer.isAvailable else { return }

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

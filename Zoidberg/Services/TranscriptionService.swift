// Zoidberg/Services/TranscriptionService.swift
import Speech
import AVFoundation

protocol TranscriptionDelegate: AnyObject {
    func transcriptionDidUpdate(text: String)
    func transcriptionDidFinish(finalText: String)
    func transcriptionDidFail(error: Error)
}

protocol TranscriptionProvider {
    var isListening: Bool { get }
    var delegate: TranscriptionDelegate? { get set }
    func startListening() throws
    func stopListening()
}

final class MacOSDictationService: NSObject, TranscriptionProvider {
    weak var delegate: TranscriptionDelegate?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private(set) var isListening = false

    func startListening() throws {
        guard Permissions.checkSpeechRecognition() == .granted else {
            throw TranscriptionError.permissionDenied
        }

        // Clean up any previous session without triggering cancel errors
        if isListening {
            cleanupAudio()
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        let inputNode = audioEngine.inputNode

        // Use the native format from the input node — avoids sample rate mismatches
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw TranscriptionError.setupFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    self.delegate?.transcriptionDidFinish(finalText: text)
                    self.cleanupAudio()
                } else {
                    self.delegate?.transcriptionDidUpdate(text: text)
                }
            }

            if let error = error as? NSError {
                // Code 301 = user canceled, not a real error
                if error.domain == "kLSRErrorDomain" && error.code == 301 {
                    return
                }
                self.delegate?.transcriptionDidFail(error: error)
                self.cleanupAudio()
            }
        }
    }

    func stopListening() {
        // End the audio stream gracefully so the recognizer can finalize
        recognitionRequest?.endAudio()

        // Give the recognizer a moment to produce a final result,
        // then clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.cleanupAudio()
        }
    }

    private func cleanupAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }
}

enum TranscriptionError: Error {
    case permissionDenied
    case setupFailed
}

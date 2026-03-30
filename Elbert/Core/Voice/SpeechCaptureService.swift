//
//  SpeechCaptureService.swift
//  Elbert
//

import Foundation
import Speech
import AVFoundation

enum SpeechCaptureError: Error, LocalizedError {
    case recognizerUnavailable
    case recognizerUnavailableForLocale
    case onDeviceRecognitionUnsupported
    case speechServiceUnavailable
    case captureAlreadyRunning
    case captureNotRunning
    case noTranscription

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is unavailable."
        case .recognizerUnavailableForLocale:
            return "Speech recognizer is unavailable for this locale."
        case .onDeviceRecognitionUnsupported:
            return "On-device speech recognition is unavailable."
        case .speechServiceUnavailable:
            return "Speech service is currently unavailable."
        case .captureAlreadyRunning:
            return "Voice capture is already running."
        case .captureNotRunning:
            return "Voice capture is not running."
        case .noTranscription:
            return "No speech detected."
        }
    }
}

actor SpeechCaptureService: SpeechCapturing {
    private let audioEngine = AVAudioEngine()
    private var localeIdentifier: String

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastTranscript: String = ""
    private var lastConfidence: Double?
    private var captureError: Error?
    private var isCapturing = false
    private var smoothedLevel: Double = 0
    private var levelHandler: (@Sendable (Double) -> Void)?

    init(localeIdentifier: String = Locale.current.identifier) {
        self.localeIdentifier = localeIdentifier
    }

    func updateLocaleIdentifier(_ identifier: String) async {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        localeIdentifier = trimmed
    }

    func setLevelHandler(_ handler: (@Sendable (Double) -> Void)?) async {
        levelHandler = handler
        handler?(smoothedLevel)
    }

    func startCapture() async throws {
        guard !isCapturing else { throw SpeechCaptureError.captureAlreadyRunning }

        let locale = Locale(identifier: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw SpeechCaptureError.recognizerUnavailableForLocale
        }

        guard recognizer.isAvailable else {
            throw SpeechCaptureError.speechServiceUnavailable
        }

        guard recognizer.supportsOnDeviceRecognition else {
            throw SpeechCaptureError.onDeviceRecognitionUnsupported
        }

        self.recognizer = recognizer
        lastTranscript = ""
        lastConfidence = nil
        captureError = nil
        smoothedLevel = 0
        emitLevel(0)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .search
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task {
                await self?.handleRecognitionUpdate(result: result, error: error)
            }
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            Task {
                await self?.appendAudioBuffer(buffer)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isCapturing = true
    }

    func stopCapture() async throws -> SpeechCaptureOutput {
        guard isCapturing else { throw SpeechCaptureError.captureNotRunning }

        endAudioPipeline(cancelTask: false)

        // Give the recognizer a short moment to flush the final tokens.
        try? await Task.sleep(for: .milliseconds(220))

        let transcript = lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

        if transcript.isEmpty {
            if let captureError {
                throw captureError
            }
            throw SpeechCaptureError.noTranscription
        }

        return SpeechCaptureOutput(transcript: transcript, confidence: lastConfidence)
    }

    func cancelCapture() async {
        guard isCapturing else { return }
        endAudioPipeline(cancelTask: true)
        lastTranscript = ""
        lastConfidence = nil
        captureError = nil
        smoothedLevel = 0
        emitLevel(0)
    }

    private func handleRecognitionUpdate(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error {
            captureError = error
        }

        guard let result else { return }

        lastTranscript = result.bestTranscription.formattedString
        if let segment = result.bestTranscription.segments.last {
            lastConfidence = Double(segment.confidence)
        }
    }

    private func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)

        let currentLevel = normalizedLevel(from: buffer)
        if currentLevel >= smoothedLevel {
            smoothedLevel = smoothedLevel * 0.58 + currentLevel * 0.42
        } else {
            smoothedLevel = smoothedLevel * 0.88 + currentLevel * 0.12
        }
        emitLevel(smoothedLevel)
    }

    private func endAudioPipeline(cancelTask: Bool) {
        guard isCapturing else { return }
        isCapturing = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        if cancelTask {
            recognitionTask?.cancel()
        } else {
            recognitionTask?.finish()
        }

        recognitionRequest = nil
        recognitionTask = nil
        emitLevel(0)
    }

    private func emitLevel(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        levelHandler?(clamped)
    }

    private func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        let samples = UnsafeBufferPointer(start: channelData[0], count: frameCount)
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameCount))
        let decibels = 20 * log10(max(rms, 0.000_000_1))
        let minDB: Float = -55
        let clamped = min(max(decibels, minDB), 0)
        return Double((clamped - minDB) / -minDB)
    }
}

//
//  VoiceModeService.swift
//  Elbert
//

import Foundation

enum VoiceModeError: Error, LocalizedError {
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .emptyTranscript:
            return "No speech captured."
        }
    }
}

actor VoiceModeService {
    private let speechCapturer: SpeechCapturing
    private let transcriptRefiner: TranscriptRefining
    private let capabilityChecker: VoiceCapabilityChecking

    init(
        speechCapturer: SpeechCapturing,
        transcriptRefiner: TranscriptRefining,
        capabilityChecker: VoiceCapabilityChecking
    ) {
        self.speechCapturer = speechCapturer
        self.transcriptRefiner = transcriptRefiner
        self.capabilityChecker = capabilityChecker
    }

    func capabilityStatus() async -> VoiceCapabilityStatus {
        await capabilityChecker.capabilityStatus()
    }

    func updateLocaleIdentifier(_ identifier: String) async {
        await capabilityChecker.updateLocaleIdentifier(identifier)
        await speechCapturer.updateLocaleIdentifier(identifier)
    }

    func setLevelHandler(_ handler: (@Sendable (Double) -> Void)?) async {
        await speechCapturer.setLevelHandler(handler)
    }

    func prepareForCapture() async -> VoiceCapabilityStatus {
        _ = await capabilityChecker.requestAuthorizationsIfNeeded()
        return await capabilityChecker.capabilityStatus()
    }

    func startCapture() async throws {
        try await speechCapturer.startCapture()
    }

    func stopCaptureAndProcess() async throws -> VoiceProcessingResult {
        let captureOutput = try await speechCapturer.stopCapture()
        let transcript = captureOutput.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            throw VoiceModeError.emptyTranscript
        }
        return try await transcriptRefiner.refine(transcript: transcript, confidence: captureOutput.confidence)
    }

    func cancelCapture() async {
        await speechCapturer.cancelCapture()
    }
}

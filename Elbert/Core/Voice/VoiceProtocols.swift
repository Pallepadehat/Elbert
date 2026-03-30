//
//  VoiceProtocols.swift
//  Elbert
//

import Foundation

protocol SpeechCapturing: Sendable {
    func updateLocaleIdentifier(_ identifier: String) async
    func setLevelHandler(_ handler: (@Sendable (Double) -> Void)?) async
    func startCapture() async throws
    func stopCapture() async throws -> SpeechCaptureOutput
    func cancelCapture() async
}

protocol TranscriptRefining: Sendable {
    func refine(transcript: String, confidence: Double?) async throws -> VoiceProcessingResult
}

protocol VoiceCapabilityChecking: Sendable {
    func updateLocaleIdentifier(_ identifier: String) async
    func capabilityStatus() async -> VoiceCapabilityStatus
    func requestAuthorizationsIfNeeded() async -> VoiceAuthorizationSnapshot
}

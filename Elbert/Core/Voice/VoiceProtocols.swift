//
//  VoiceProtocols.swift
//  Elbert
//

import Foundation

protocol SpeechCapturing: Sendable {
    func startCapture() async throws
    func stopCapture() async throws -> SpeechCaptureOutput
    func cancelCapture() async
}

protocol TranscriptRefining: Sendable {
    func refine(transcript: String, confidence: Double?) async throws -> VoiceProcessingResult
}

protocol VoiceCapabilityChecking: Sendable {
    func capabilityStatus() async -> VoiceCapabilityStatus
    func requestAuthorizationsIfNeeded() async -> VoiceAuthorizationSnapshot
}

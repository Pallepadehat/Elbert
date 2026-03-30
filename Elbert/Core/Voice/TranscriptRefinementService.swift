//
//  TranscriptRefinementService.swift
//  Elbert
//

import Foundation
import FoundationModels

enum TranscriptRefinementError: Error, LocalizedError {
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Voice unavailable on this Mac."
        }
    }
}

struct TranscriptRefinementService: TranscriptRefining {
    private let capabilityChecker: VoiceCapabilityChecking

    init(capabilityChecker: VoiceCapabilityChecking) {
        self.capabilityChecker = capabilityChecker
    }

    func refine(transcript: String, confidence: Double?) async throws -> VoiceProcessingResult {
        let availability = await capabilityChecker.capabilityStatus()
        guard availability.isFoundationModelAvailable else {
            throw TranscriptRefinementError.modelUnavailable
        }

        let model = SystemLanguageModel.default
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You normalize voice transcripts into concise launcher query text.
            Keep output short and literal. Do not explain.
            If user self-corrects (like 'no wait'), keep only the final intent.
            Preserve calculator expressions and app names.
            Output only the query string.
            """
        )

        let response = try await session.respond(to: "Transcript: \(transcript)")
        let refined = sanitize(response.content)

        let finalQuery = refined.isEmpty ? transcript.trimmingCharacters(in: .whitespacesAndNewlines) : refined
        return VoiceProcessingResult(finalQuery: finalQuery, rawTranscript: transcript, confidence: confidence)
    }

    private func sanitize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
    }
}

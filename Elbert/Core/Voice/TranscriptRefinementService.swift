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

@Generable(description: "Normalized launcher command text")
private struct VoiceCommandNormalization {
    @Guide(
        description: "Final concise launcher query. Keep only final user intent. No explanations."
    )
    var query: String
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
            Normalize speech transcripts into launcher queries.
            Keep output short, literal, and executable as a search query.
            If user self-corrects (for example "no wait"), keep only final intent.
            Preserve app names, file names, and calculator expressions exactly.
            """
        )

        let prompt = """
        Transcript: \(transcript)
        Return the final launcher query.
        """

        let refined: String
        do {
            // Constrained generation avoids malformed or chatty free-form output.
            let response = try await session.respond(
                to: prompt,
                generating: VoiceCommandNormalization.self
            )
            refined = sanitize(response.content.query)
        } catch {
            // Fallback keeps voice usable if constrained decoding fails for any reason.
            let fallback = try await session.respond(to: prompt)
            refined = sanitize(fallback.content)
        }

        let finalQuery = refined.isEmpty ? transcript.trimmingCharacters(in: .whitespacesAndNewlines) : refined
        return VoiceProcessingResult(finalQuery: finalQuery, rawTranscript: transcript, confidence: confidence)
    }

    private func sanitize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
    }
}

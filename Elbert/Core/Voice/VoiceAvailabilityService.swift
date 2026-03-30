//
//  VoiceAvailabilityService.swift
//  Elbert
//

import Foundation
import Speech
import AVFoundation
import FoundationModels

struct VoiceAvailabilityService: VoiceCapabilityChecking {
    func capabilityStatus() async -> VoiceCapabilityStatus {
        let authorization = await currentAuthorizations()
        let model = SystemLanguageModel.default
        let modelAvailability = model.availability
        let modelIsAvailable = model.isAvailable

        let recognizer = SFSpeechRecognizer(locale: .current)
        let speechOnDevice = recognizer?.supportsOnDeviceRecognition ?? false

        return VoiceCapabilityStatus(
            isFoundationModelAvailable: modelIsAvailable,
            foundationModelDescription: describe(modelAvailability),
            isOnDeviceSpeechAvailable: speechOnDevice,
            authorization: authorization
        )
    }

    func requestAuthorizationsIfNeeded() async -> VoiceAuthorizationSnapshot {
        let current = await currentAuthorizations()

        if current.microphone == .notDetermined {
            _ = await requestMicrophoneAuthorization()
        }

        if current.speechRecognition == .notDetermined {
            _ = await requestSpeechAuthorization()
        }

        return await currentAuthorizations()
    }

    private func currentAuthorizations() async -> VoiceAuthorizationSnapshot {
        let microphone = mapMicrophoneStatus(AVCaptureDevice.authorizationStatus(for: .audio))
        let speech = mapSpeechStatus(SFSpeechRecognizer.authorizationStatus())
        return VoiceAuthorizationSnapshot(microphone: microphone, speechRecognition: speech)
    }

    private func requestMicrophoneAuthorization() async -> VoiceAuthorizationStatus {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted ? .authorized : .denied)
            }
        }
    }

    private func requestSpeechAuthorization() async -> VoiceAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: mapSpeechStatus(status))
            }
        }
    }

    private func mapMicrophoneStatus(_ status: AVAuthorizationStatus) -> VoiceAuthorizationStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .restricted
        }
    }

    private func mapSpeechStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> VoiceAuthorizationStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .restricted
        }
    }

    private func describe(_ availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            return "available"
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "device not eligible"
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence not enabled"
            case .modelNotReady:
                return "model not ready"
            @unknown default:
                return "model unavailable"
            }
        @unknown default:
            return "unknown"
        }
    }
}

//
//  VoiceTypes.swift
//  Elbert
//

import Foundation

enum VoiceCaptureState: Equatable {
    case idle
    case listening
    case processing
    case unavailable(String)
    case error(String)
}

enum VoiceAuthorizationStatus: String, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined

    var title: String {
        switch self {
        case .authorized: "Authorized"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not determined"
        }
    }
}

struct VoiceAuthorizationSnapshot: Sendable, Equatable {
    let microphone: VoiceAuthorizationStatus
    let speechRecognition: VoiceAuthorizationStatus

    var isFullyAuthorized: Bool {
        microphone == .authorized && speechRecognition == .authorized
    }
}

struct VoiceCapabilityStatus: Sendable, Equatable {
    let isFoundationModelAvailable: Bool
    let foundationModelDescription: String
    let isOnDeviceSpeechAvailable: Bool
    let authorization: VoiceAuthorizationSnapshot

    var isVoiceModeSupported: Bool {
        isFoundationModelAvailable && isOnDeviceSpeechAvailable
    }

    var isReadyToCapture: Bool {
        isVoiceModeSupported && authorization.isFullyAuthorized
    }

    var availabilityText: String {
        if !isFoundationModelAvailable {
            return "Unsupported: \(foundationModelDescription)"
        }
        if !isOnDeviceSpeechAvailable {
            return "Unsupported: on-device speech is unavailable"
        }
        return "Supported"
    }

    var permissionText: String {
        "Mic: \(authorization.microphone.title) · Speech: \(authorization.speechRecognition.title)"
    }

    var hasDeniedPermission: Bool {
        authorization.microphone == .denied || authorization.speechRecognition == .denied
    }
}

struct SpeechCaptureOutput: Sendable {
    let transcript: String
    let confidence: Double?
}

struct VoiceProcessingResult: Sendable {
    let finalQuery: String
    let rawTranscript: String
    let confidence: Double?
}

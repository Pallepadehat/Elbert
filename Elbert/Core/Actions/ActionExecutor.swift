//
//  ActionExecutor.swift
//  Elbert
//

import Foundation
import AppKit

enum ActionExecutionError: Error, LocalizedError {
    case failedToOpenApplication(URL)
    case failedToOpenURL(URL)
    case shellCommandFailed

    var errorDescription: String? {
        switch self {
        case .failedToOpenApplication(let url):
            return "Could not open app at \(url.path)."
        case .failedToOpenURL(let url):
            return "Could not open URL \(url.absoluteString)."
        case .shellCommandFailed:
            return "Could not run shell command."
        }
    }
}

actor ActionExecutor {
    func execute(_ action: LauncherAction) async throws {
        switch action {
        case .openApplication(let url):
            let ok = NSWorkspace.shared.open(url)
            if !ok {
                throw ActionExecutionError.failedToOpenApplication(url)
            }
        case .openURL(let url):
            let ok = NSWorkspace.shared.open(url)
            if !ok {
                throw ActionExecutionError.failedToOpenURL(url)
            }
        case .runShellCommand(let command):
            try await runShell(command)
        }
    }

    private func runShell(_ command: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]

            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ActionExecutionError.shellCommandFailed)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

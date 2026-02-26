//
//  HotKeyRecorder.swift
//  Elbert
//

import SwiftUI
import Carbon

struct HotKeyRecorder: View {
    let current: HotkeyShortcut
    let onRecord: (HotkeyShortcut) -> Void

    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isRecording.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text(isRecording ? "Press keys…" : current.displayString)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(isRecording ? .secondary : .primary)

                    if isRecording {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isRecording
                              ? Color.accentColor.opacity(0.08)
                              : Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isRecording ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor),
                                    lineWidth: 1
                                )
                        )
                )
                .animation(.easeInOut(duration: 0.15), value: isRecording)
            }
            .buttonStyle(.plain)

            if isRecording {
                Label("Press your shortcut · Esc to cancel", systemImage: "keyboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.18), value: isRecording)
        .onChange(of: isRecording) { _, recording in
            recording ? startMonitoring() : stopMonitoring()
        }
        .onDisappear {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        error = nil
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isRecording else { return event }

            if Int(event.keyCode) == kVK_Escape {
                isRecording = false
                return nil
            }

            guard let shortcut = HotkeyShortcut.from(event: event) else {
                error = "Include at least one modifier key (⌘ ⌥ ⌃ ⇧)."
                return nil
            }

            onRecord(shortcut)
            isRecording = false
            return nil
        }
    }

    private func stopMonitoring() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}

//
//  SettingsView.swift
//  Elbert
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 10) {
                    SettingsSection("Global Shortcut") {
                        HotKeyRecorder(
                            current: coordinator.hotkeyShortcut,
                            onRecord: { coordinator.updateShortcut($0) }
                        )
                        Text("Click to start recording. Press Esc to cancel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SettingsSection("Plugins & Indexing") {
                        settingsRow("Plugin folder") {
                            Button("Open") {
                                coordinator.openPluginsFolder()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Text(coordinator.pluginDirectoryPath)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .fixedSize(horizontal: false, vertical: true)

                        settingsRow(
                            "Search index",
                            subtitle: coordinator.isRebuildingIndex ? "Rebuilding…" : "Up to date"
                        ) {
                            Button {
                                coordinator.reloadPluginsAndIndexFromSettings()
                            } label: {
                                if coordinator.isRebuildingIndex {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Rebuild")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(coordinator.isRebuildingIndex)
                        }
                    }

                    #if DEBUG
                    SettingsSection("Debug") {
                        settingsRow("Onboarding", subtitle: "Test the first-launch flow") {
                            HStack(spacing: 6) {
                                Button("Open") {
                                    coordinator.showOnboardingForDebug(resetCompletion: false)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button("Reset") {
                                    coordinator.showOnboardingForDebug(resetCompletion: true)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }
                    #endif
                }
                .padding(16)
            }
        }
        .frame(width: 420, height: 480)
        .background(backgroundView)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    Image("AppImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Elbert")
                        .font(.headline)
                    Text("Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
        }
    }

    private var backgroundView: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Color(nsColor: .controlBackgroundColor).opacity(0.4)
        }
    }

    private func settingsRow<Content: View>(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 2)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
                )
        )
    }
}

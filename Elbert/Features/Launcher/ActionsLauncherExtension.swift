//
//  ActionsLauncherExtension.swift
//  Elbert
//

import SwiftUI

enum ActionsLauncherExtension {
    static func make() -> AnyLauncherExtension {
        AnyLauncherExtension(
            id: "com.elbert.extension.actions",
            name: "Actions",
            summary: "Floating command cluster with quick launcher controls.",
            author: "Elbert Team",
            version: "1.0.0",
            defaultEnabled: true,
            placement: .floatingBottomTrailing,
            order: 10
        ) { context in
            ActionsFloatingControl(context: context)
        }
    }
}

private struct ActionsFloatingControl: View {
    let context: LauncherExtensionContext
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if isExpanded {
                actionButton(
                    title: "Run",
                    icon: "play.fill",
                    tint: Color.green.opacity(0.28),
                    action: context.actions.runSelectedResult
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))

                actionButton(
                    title: "Clear",
                    icon: "xmark",
                    tint: Color.orange.opacity(0.25),
                    action: context.actions.clearQuery
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))

                actionButton(
                    title: "Reindex",
                    icon: "arrow.triangle.2.circlepath",
                    tint: Color.blue.opacity(0.25),
                    action: context.actions.rebuildIndex
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))

                actionButton(
                    title: "Settings",
                    icon: "gearshape.fill",
                    tint: Color.pink.opacity(0.24),
                    action: context.actions.openSettings
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    if isExpanded {
                        Text("Actions")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }

                    Image(systemName: isExpanded ? "xmark" : "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(isExpanded ? 0 : -12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.95),
                                    Color.accentColor.opacity(0.62)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 7)
                )
            }
            .buttonStyle(.plain)
            .help("Extension Action Hub")
        }
    }

    private func actionButton(
        title: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                isExpanded = false
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(tint)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

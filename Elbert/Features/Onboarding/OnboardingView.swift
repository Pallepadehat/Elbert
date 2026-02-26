//
//  OnboardingView.swift
//  Elbert
//

import SwiftUI

// MARK: - Multi-step onboarding flow

struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case welcome, hotkey, plugins, finish
    }

    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var step: Step = .welcome

    var body: some View {
        OnBoardingView(foregroundColor: .white, tint: .blue) { isAnimating in
            Image("AppImage")
                .resizable()
                .scaledToFit()
                .frame(width: 550)
                .blendMode(.softLight)
                .scaleEffect(isAnimating ? 0.5 : 1)
        } content: { _ in
            VStack(spacing: 18) {
                stepHeader
                stepContent
                stepFooter
            }
            .padding(.top, 10)
            .animation(.snappy(duration: 0.25), value: step)
        } onClose: {
            coordinator.dismissOnboarding()
        }
        .onEscapeKey {
            coordinator.dismissOnboarding()
        }
    }

    // MARK: Header

    private var stepHeader: some View {
        VStack(spacing: 6) {
            Text(titleText)
                .font(step == .welcome ? .largeTitle.weight(.bold) : .title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(subtitleText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:  welcomeStep
        case .hotkey:   hotkeyStep
        case .plugins:  pluginsStep
        case .finish:   finishStep
        }
    }

    private var welcomeStep: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "bolt.fill",                 title: "Fast launcher",    subtitle: "Open Elbert and jump to the right app in a few keystrokes.")
                FeatureRow(icon: "command",                   title: "Global shortcut",  subtitle: "Bring it up anytime with your preferred key combination.")
                FeatureRow(icon: "puzzlepiece.extension.fill",title: "Plugin commands",  subtitle: "Drop plugin manifests into your folder and rebuild when needed.")
            }
        }
    }

    private var hotkeyStep: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Global Shortcut").font(.headline)
                HotKeyRecorder(
                    current: coordinator.hotkeyShortcut,
                    onRecord: { coordinator.updateShortcut($0) }
                )
            }
        }
    }

    private var pluginsStep: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Plugin Folder").font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Location")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(coordinator.pluginDirectoryPath)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )

                HStack(spacing: 8) {
                    Button { coordinator.openPluginsFolder() } label: {
                        Label("Open Folder", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button { coordinator.reloadPluginsAndIndexFromSettings() } label: {
                        Label(
                            coordinator.isRebuildingIndex ? "Rebuilding…" : "Rebuild Index",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(coordinator.isRebuildingIndex)
                }

                Text("Drop JSON plugin manifests into the folder above, then tap Rebuild.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var finishStep: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ready to launch").font(.headline)
                Text("Hotkey and indexing can be changed anytime in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Footer

    private var stepFooter: some View {
        HStack(spacing: 12) {
            if step != .welcome {
                Button("Back") {
                    withAnimation(.snappy(duration: 0.25)) {
                        step = Step(rawValue: step.rawValue - 1) ?? .welcome
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(step == .finish ? "Finish" : "Continue") {
                handlePrimaryAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 4)
    }

    // MARK: Helpers

    private var titleText: String {
        switch step {
        case .welcome: "Welcome to Elbert"
        case .hotkey:  "Set your shortcut"
        case .plugins: "Plugins and indexing"
        case .finish:  "All set"
        }
    }

    private var subtitleText: String {
        switch step {
        case .welcome: "A clean launcher built for speed. Find, run, and move."
        case .hotkey:  "Pick a shortcut you can trigger from anywhere."
        case .plugins: "Open your plugin folder and refresh your index in one click."
        case .finish:  "You're ready to launch apps and plugin commands instantly."
        }
    }

    private func handlePrimaryAction() {
        if step == .finish {
            coordinator.completeOnboarding()
        } else {
            withAnimation(.snappy(duration: 0.25)) {
                step = Step(rawValue: step.rawValue + 1) ?? .finish
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 320)
            .padding(.horizontal, 24)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Animated intro container

struct OnBoardingView<Logo: View, Content: View>: View {
    var foregroundColor: Color
    var tint: Color
    var useLiquidGlass: Bool = false
    @ViewBuilder var logo: (_ isAnimating: Bool) -> Logo
    @ViewBuilder var content: (_ isAnimating: Bool) -> Content
    var onClose: () -> Void = {}

    @State private var p = AnimationProperties()

    var body: some View {
        let layout = p.convertToLogo
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(ZStackLayout(alignment: .bottom))

        layout {
            ZStack {
                Circle()
                    .fill(tint.gradient)
                    .scaleEffect(p.animateMainCircle ? 2 : 0)

                gridLines
                circlesView
                circleStrokesView
                diagonalLines

                logo(p.convertToLogo)
                    .compositingGroup()
                    .blur(radius: p.convertToLogo ? 0 : 50)
                    .opacity(p.convertToLogo ? 1 : 0)
            }
            .frame(
                width:  p.convertToLogo ? 180 : 400,
                height: p.convertToLogo ? 180 : 500
            )
            .clipShape(.rect(cornerRadius: p.convertToLogo ? 50 : 30))
            .contentShape(.rect)

            let isAnimating = p.convertToLogo
            content(isAnimating)
                .visualEffect { view, proxy in
                    view.offset(y: isAnimating ? 0 : proxy.size.height)
                }
                .opacity(isAnimating ? 1 : 0)
        }
        .frame(width: 420, height: 520)
        .overlay(alignment: .topLeading) { closeButton }
        .background {
            if useLiquidGlass {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(useLiquidGlass ? 0.18 : 0.08), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 30))
        .onAppear(perform: runIntroSequence)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var circlesView: some View {
        ZStack {
            ForEach(1...4, id: \.self) { i in
                let rotation = (CGFloat(i) / 4) * 360
                let extraRotation: CGFloat = p.positionCircles ? 20 : 0
                let extraOffset: CGFloat = i % 2 != 0 ? 40 : -20
                Circle()
                    .fill(foregroundColor)
                    .frame(width: p.circleSize, height: p.circleSize)
                    .animation(.easeInOut(duration: 0.05).delay(0.35)) {
                        $0.scaleEffect(p.positionCircles ? 0 : 1)
                    }
                    .offset(x: p.positionCircles ? (120 + extraOffset) : p.circleOffset)
                    .rotationEffect(.degrees(rotation + extraRotation))
                    .animation(.easeInOut(duration: 0.2).delay(0.2)) {
                        $0.rotationEffect(.degrees(p.positionCircles ? 12 : 0))
                    }
            }
        }
        .compositingGroup()
        .scaleEffect(p.circleScale)
    }

    @ViewBuilder
    private var circleStrokesView: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: p.animateStrokes ? 1 : 0)
                .stroke(foregroundColor, lineWidth: 1)
                .frame(width: 70, height: 70)
                .scaleEffect(p.convertToLogo ? 2.5 : 1)

            ForEach(1...4, id: \.self) { i in
                let isFaded = i == 3 || i == 4
                let extraOffset: CGFloat = i % 2 != 0 ? 120 : 0
                Circle()
                    .trim(from: 0, to: p.animateStrokes ? 1 : 0)
                    .stroke(foregroundColor.opacity(isFaded ? 0.3 : 1), lineWidth: 1)
                    .frame(width: 200 + extraOffset, height: 200 + extraOffset)
                    .rotationEffect(.degrees((CGFloat(i) / CGFloat(4)) * 360.0 + 32.0))
            }
        }
        .compositingGroup()
        .scaleEffect(p.convertToLogo ? 1.5 : 1)
        .opacity(p.convertToLogo ? 0 : 1)
    }

    @ViewBuilder
    private var gridLines: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { i in
                    Rectangle()
                        .fill(foregroundColor.opacity(0.3))
                        .frame(width: 1, height: p.animateGridLines ? nil : 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .scaleEffect(y: i == 2 || i == 4 ? -1 : 1)
                }
            }
            VStack(spacing: 0) {
                ForEach(1...5, id: \.self) { i in
                    Rectangle()
                        .fill(foregroundColor.opacity(0.3))
                        .frame(width: p.animateGridLines ? nil : 0, height: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .scaleEffect(x: i == 2 || i == 4 ? -1 : 1)
                }
            }
        }
        .compositingGroup()
        .opacity(p.convertToLogo ? 0 : 1)
    }

    @ViewBuilder
    private var diagonalLines: some View {
        ZStack {
            ForEach([-39.0, 39.0], id: \.self) { angle in
                Rectangle()
                    .fill(foregroundColor.opacity(0.3))
                    .frame(width: 1, height: p.animateDiagonalLines ? nil : 0)
                    .padding(.vertical, -100)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .rotationEffect(.degrees(angle))
            }
        }
        .compositingGroup()
        .opacity(p.convertToLogo ? 0 : 1)
    }

    @ViewBuilder
    private var closeButton: some View {
        Button { onClose() } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(foregroundColor.opacity(0.3))
                .padding(15)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(p.convertToLogo ? 1 : 0)
    }

    // MARK: - Animation sequence

    private func runIntroSequence() {
        guard !p.animateMainCircle else { return }
        Task {
            await delay(0.10, .easeInOut(duration: 0.50))  { p.animateMainCircle = true }
            await delay(0.15, .bouncy(duration: 0.35, extraBounce: 0.2)) { p.circleScale = 1 }
            await delay(0.30, .bouncy(duration: 0.50))     { p.circleOffset = 50 }
            await delay(0.10, .bouncy(duration: 0.40))     { p.circleSize = 5 }
            await delay(0.25, .linear(duration: 0.40))     { p.positionCircles = true }
            await delay(0.35, .linear(duration: 1.00))     { p.animateStrokes = true }
            await delay(0.30, .linear(duration: 0.60))     { p.animateGridLines = true }
            await delay(0.15, .linear(duration: 0.50))     { p.animateDiagonalLines = true }
            await delay(0.50, .bouncy(duration: 0.50))     { p.convertToLogo = true }
        }
    }

    private func delay(_ seconds: Double, _ animation: Animation, perform: @escaping () -> Void) async {
        try? await Task.sleep(for: .seconds(seconds))
        withAnimation(animation) { perform() }
    }

    // MARK: - State

    struct AnimationProperties {
        var animateMainCircle = false
        var circleSize: CGFloat = 50
        var circleOffset: CGFloat = 0
        var circleScale: CGFloat = 0
        var positionCircles = false
        var animateStrokes = false
        var animateGridLines = false
        var animateDiagonalLines = false
        var convertToLogo = false
    }
}

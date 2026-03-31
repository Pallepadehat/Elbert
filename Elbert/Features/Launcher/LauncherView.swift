//
//  LauncherView.swift
//  Elbert
//

import SwiftUI
import AppKit

struct LauncherView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @FocusState private var isSearchFocused: Bool
    @State private var keyMonitor: Any?
    @State private var isHoldingPushToTalk = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            searchField
            Divider()
            resultsPane
            statusBar
        }
        .background(
            RoundedRectangle(cornerRadius: AppStyle.panelCornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.panelCornerRadius, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
        )
        .overlay(alignment: .bottom) {
            if shouldShowFloatingVisualizer {
                FloatingAudioVisualizer(
                    inputLevel: coordinator.voiceInputLevel,
                    isListening: coordinator.voiceCaptureState == .listening,
                    isProcessing: coordinator.voiceCaptureState == .processing
                )
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: shouldShowFloatingVisualizer)
        .onAppear {
            focusSearchField()
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
            if isHoldingPushToTalk {
                isHoldingPushToTalk = false
                coordinator.cancelVoiceCapture()
            }
        }
        .onChange(of: coordinator.state.isLauncherVisible) { _, isVisible in
            if isVisible { focusSearchField() }
        }
        .onEscapeKey {
            coordinator.dismissLauncher()
        }
    }

    // MARK: - Sections

    private var headerBar: some View {
        HStack {
            Text("Elbert")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            voiceStateBadge
            Spacer()
            Text("Hold \(coordinator.voicePushToTalkModifier.hintGlyph) talk · ↑↓ navigate · ↩ run · ⌘R reveal · ⌘C copy+close · ⇧⌘C copy path · ⎋ close")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var voiceStateBadge: some View {
        switch coordinator.voiceCaptureState {
        case .idle:
            EmptyView()
        case .listening:
            Label("Listening", systemImage: "mic.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.red)
        case .processing:
            Label("Processing", systemImage: "waveform")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        case .unavailable:
            Label("Voice unavailable", systemImage: "exclamationmark.triangle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        case .error:
            Label("Voice error", systemImage: "xmark.octagon")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search files, apps, commands…", text: queryBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .regular))
                .focused($isSearchFocused)
                .onSubmit { coordinator.runSelectedResult() }

            if !coordinator.state.query.isEmpty {
                Button {
                    coordinator.updateQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var resultsPane: some View {
        Group {
            if coordinator.state.isClipboardMode {
                ClipboardHistoryPane(
                    results: coordinator.state.results,
                    query: coordinator.state.query,
                    isFuzzyModeEnabled: coordinator.isFuzzyModeEnabled,
                    selectedID: coordinator.state.selectedResultID,
                    onRun: { coordinator.run(result: $0) }
                )
            } else if coordinator.state.results.isEmpty {
                emptyState
            } else if let item = calculatorItem {
                CalculatorResultPane(
                    expression: coordinator.state.query,
                    result: item.title,
                    onRun: { coordinator.run(result: item) }
                )
            } else {
                ResultsList(
                    results: coordinator.state.results,
                    query: coordinator.state.query,
                    isFuzzyModeEnabled: coordinator.isFuzzyModeEnabled,
                    selectedID: coordinator.state.selectedResultID,
                    onRun: { coordinator.run(result: $0) },
                    onRevealInFinder: { coordinator.revealFileInFinder(for: $0) },
                    onCopyPath: { coordinator.copyPath(for: $0) }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)
            Text("No results")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 48)
    }

    @ViewBuilder
    private var statusBar: some View {
        if let msg = coordinator.state.statusMessage {
            Text(msg)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
        }
        Spacer().frame(height: 20)
    }

    // MARK: - Helpers

    private var queryBinding: Binding<String> {
        Binding(
            get: { coordinator.state.query },
            set: { coordinator.updateQuery($0) }
        )
    }

    private var calculatorItem: SearchResultItem? {
        guard coordinator.state.results.count == 1,
              let item = coordinator.state.results.first else {
            return nil
        }
        guard case .copyToClipboard = item.action, item.source == "Calc" else {
            return nil
        }
        return item
    }

    private var selectedResult: SearchResultItem? {
        guard let selectedID = coordinator.state.selectedResultID else {
            return coordinator.state.results.first
        }
        return coordinator.state.results.first(where: { $0.id == selectedID }) ?? coordinator.state.results.first
    }

    private var shouldShowFloatingVisualizer: Bool {
        switch coordinator.voiceCaptureState {
        case .listening, .processing:
            return true
        case .idle, .unavailable, .error:
            return false
        }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            guard coordinator.state.isLauncherVisible else { return event }

            if event.type == .flagsChanged {
                handlePushToTalkModifierChange(event)
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let significantModifiers = modifiers
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.numericPad, .function, .capsLock])

            if significantModifiers == .command {
                if Int(event.keyCode) == KeyboardKeyCode.c {
                    if let selected = selectedResult {
                        coordinator.copySelectedValueAndClose(for: selected)
                        return nil
                    }
                } else if Int(event.keyCode) == KeyboardKeyCode.r {
                    if let selected = selectedResult, case .openFile = selected.action {
                        coordinator.revealFileInFinder(for: selected)
                        return nil
                    }
                }
            } else if significantModifiers == [.command, .shift] {
                if Int(event.keyCode) == KeyboardKeyCode.c {
                    if let selected = selectedResult, case .openFile = selected.action {
                        coordinator.copyPath(for: selected)
                        return nil
                    }
                }
            }

            // Arrow keys always carry .numericPad and .function flags — strip them
            // before checking whether any significant modifier is held.
            let significant = modifiers
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.numericPad, .function, .capsLock])
            guard significant.isEmpty else { return event }

            switch Int(event.keyCode) {
            case KeyboardKeyCode.upArrow:
                moveSelection(by: -1)
                return nil
            case KeyboardKeyCode.downArrow:
                moveSelection(by: 1)
                return nil
            default:
                return event
            }
        }
    }

    private func handlePushToTalkModifierChange(_ event: NSEvent) {
        let optionOnly = isOptionOnlyModifier(event.modifierFlags)

        if optionOnly, !isHoldingPushToTalk {
            isHoldingPushToTalk = true
            coordinator.startVoiceCapture()
            return
        }

        if !optionOnly, isHoldingPushToTalk {
            isHoldingPushToTalk = false
            coordinator.stopVoiceCaptureAndProcess()
        }
    }

    private func isOptionOnlyModifier(_ flags: NSEvent.ModifierFlags) -> Bool {
        let significant = flags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])

        return significant == coordinator.voicePushToTalkModifier.eventFlag
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func moveSelection(by offset: Int) {
        let ids = coordinator.state.results.map(\.id)
        guard !ids.isEmpty else { return }

        guard let current = coordinator.state.selectedResultID,
              let idx = ids.firstIndex(of: current) else {
            coordinator.state.selectedResultID = ids.first
            return
        }

        let next = (idx + offset + ids.count) % ids.count
        coordinator.state.selectedResultID = ids[next]
    }

    private func focusSearchField() {
        isSearchFocused = true
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }
}

private struct FloatingAudioVisualizer: View {
    let inputLevel: Double
    let isListening: Bool
    let isProcessing: Bool

    private let totalHeight: CGFloat = 24
    private let barWidth: CGFloat = 5
    private let barCount = 7

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !(isListening || isProcessing))) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<barCount, id: \.self) { index in
                    bar(heightFraction: barHeightFraction(index: index, time: t))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        }
    }

    private func bar(heightFraction: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2.2, style: .continuous)
            .fill(.black.gradient)
            .frame(width: barWidth, height: heightFraction * totalHeight)
            .frame(height: totalHeight, alignment: .bottom)
    }

    private func barHeightFraction(index: Int, time: TimeInterval) -> CGFloat {
        let level = min(max(inputLevel, 0), 1)
        let wave = 0.5 + 0.5 * sin((time * 6.2) + (Double(index) * 1.12))
        let pulse = 0.5 + 0.5 * sin((time * 3.1) + (Double(index) * 0.63))

        if isListening {
            let energy = 0.18 + (level * 0.82)
            let floor = 0.10 + (Double(index % 2) * 0.03)
            let dynamic = floor + (wave * energy)
            return CGFloat(min(max(dynamic, 0.08), 1.0))
        }

        if isProcessing {
            let dynamic = 0.22 + (pulse * 0.44)
            return CGFloat(min(max(dynamic, 0.12), 0.88))
        }

        return 0.08
    }
}

// MARK: - Calculator Result

private struct CalculatorResultPane: View {
    let expression: String
    let result: String
    let onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calculator")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.top, 8)

            Button(action: onRun) {
                HStack(spacing: 0) {
                    calculatorColumn(value: cleanExpression, footer: "Input")

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 30, height: 30)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .frame(width: 64)

                    calculatorColumn(value: result, footer: "Copied on Enter")
                }
                .padding(.horizontal, 10)
                .frame(height: 122)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.26),
                                    Color.accentColor.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)

            Text("Press Enter to copy result and close")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var cleanExpression: String {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("=") {
            return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    @ViewBuilder
    private func calculatorColumn(value: String, footer: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            Text(footer)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.74))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }
}

// MARK: - Results List

private struct ClipboardHistoryPane: View {
    let results: [SearchResultItem]
    let query: String
    let isFuzzyModeEnabled: Bool
    let selectedID: SearchResultItem.ID?
    let onRun: (SearchResultItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Clipboard History")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Enter pastes into previous app")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 6)

            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No clipboard items yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 20)
            } else {
                ResultsList(
                    results: results,
                    query: query,
                    isFuzzyModeEnabled: isFuzzyModeEnabled,
                    selectedID: selectedID,
                    onRun: onRun,
                    onRevealInFinder: { _ in },
                    onCopyPath: { _ in }
                )
            }
        }
    }
}

private struct ResultsList: View {
    let results: [SearchResultItem]
    let query: String
    let isFuzzyModeEnabled: Bool
    let selectedID: SearchResultItem.ID?
    let onRun: (SearchResultItem) -> Void
    let onRevealInFinder: (SearchResultItem) -> Void
    let onCopyPath: (SearchResultItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(results) { item in
                        ResultRow(
                            item: item,
                            query: query,
                            isFuzzyModeEnabled: isFuzzyModeEnabled,
                            isSelected: selectedID == item.id,
                            action: { onRun(item) },
                            onRevealInFinder: { onRevealInFinder(item) },
                            onCopyPath: { onCopyPath(item) }
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.never)
            .onChange(of: selectedID) { _, newID in
                guard let newID else { return }
                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(newID)
                        }
            }
        }
    }
}

// MARK: - Result Row

private struct ResultRow: View {
    let item: SearchResultItem
    let query: String
    let isFuzzyModeEnabled: Bool
    let isSelected: Bool
    let action: () -> Void
    let onRevealInFinder: () -> Void
    let onCopyPath: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ResultIconView(item: item)

                VStack(alignment: .leading, spacing: 2) {
                    highlightedTitleText
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(item.source)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .secondary : .tertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isSelected
                                  ? Color.primary.opacity(0.1)
                                  : Color.secondary.opacity(0.07))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.35) : Color.clear,
                                lineWidth: 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if case .openFile = item.action {
                Button("Open File", action: action)
                Button("Reveal in Finder", action: onRevealInFinder)
                Button("Copy Path", action: onCopyPath)
            }
        }
    }

    private var highlightedTitleText: Text {
        guard isFuzzyModeEnabled else {
            return Text(item.title).foregroundStyle(.primary)
        }

        let positions = matchedTitlePositions()
        guard !positions.isEmpty else {
            return Text(item.title).foregroundStyle(.primary)
        }

        var attributed = AttributedString(item.title)
        let characterCount = attributed.characters.count
        for position in positions.sorted() {
            guard position >= 0, position < characterCount else {
                continue
            }
            let start = attributed.index(attributed.startIndex, offsetByCharacters: position)
            let end = attributed.index(start, offsetByCharacters: 1)

            attributed[start..<end].underlineStyle = .single
            attributed[start..<end].foregroundColor = .accentColor
        }

        return Text(attributed).foregroundStyle(.primary)
    }

    private func matchedTitlePositions() -> Set<Int> {
        let normalizedTitle = normalizeForMatching(item.title)
        guard !normalizedTitle.isEmpty else { return [] }

        let tokens = queryTokens(from: query)
        guard !tokens.isEmpty else { return [] }

        var matched = Set<Int>()
        for token in tokens {
            if let range = normalizedTitle.range(of: token) {
                let start = normalizedTitle.distance(from: normalizedTitle.startIndex, to: range.lowerBound)
                let length = normalizedTitle.distance(from: range.lowerBound, to: range.upperBound)
                for index in start..<(start + length) {
                    matched.insert(index)
                }
                continue
            }

            let titleChars = Array(normalizedTitle)
            let tokenChars = Array(token)
            var tokenIndex = 0
            var positions: [Int] = []

            for (titleIndex, titleChar) in titleChars.enumerated() {
                guard tokenIndex < tokenChars.count else { break }
                if titleChar == tokenChars[tokenIndex] {
                    positions.append(titleIndex)
                    tokenIndex += 1
                }
            }

            if tokenIndex == tokenChars.count {
                for position in positions {
                    matched.insert(position)
                }
            }
        }

        return matched
    }

    private func queryTokens(from query: String) -> [String] {
        let normalized = normalizeForMatching(query)
        return normalized
            .split(separator: " ")
            .compactMap { part in
                let token = String(part)
                if token.hasPrefix("ext:") || token.hasPrefix("in:") {
                    return nil
                }
                return token.isEmpty ? nil : token
            }
    }

    private func normalizeForMatching(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Icon

private struct ResultIconView: View {
    let item: SearchResultItem

    var body: some View {
        switch item.action {
        case .openApplication(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: 32, height: 32)
        case .openFile(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: 32, height: 32)
        case .revealInFinder:
            iconShell(systemName: "folder")
        case .openURL:
            iconShell(systemName: "globe")
        case .runShellCommand:
            iconShell(systemName: "terminal")
        case .copyToClipboard:
            iconShell(systemName: "function")
        case .pasteClipboardEntry:
            iconShell(systemName: "clipboard")
        }
    }

    private func iconShell(systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 32, height: 32)
    }
}

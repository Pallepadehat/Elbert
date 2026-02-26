//
//  LauncherView.swift
//  Elbert
//

import SwiftUI
import AppKit
import Carbon

struct LauncherView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @FocusState private var isSearchFocused: Bool
    @State private var keyMonitor: Any?

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
        .onAppear {
            isSearchFocused = true
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .onChange(of: coordinator.state.isLauncherVisible) { _, isVisible in
            if isVisible { isSearchFocused = true }
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
            Spacer()
            Text("↑↓  navigate  ·  ↩  run  ·  ⎋  close")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search apps, commands, plugins…", text: queryBinding)
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
            if coordinator.state.results.isEmpty {
                emptyState
            } else {
                ResultsList(
                    results: coordinator.state.results,
                    selectedID: coordinator.state.selectedResultID,
                    onRun: { coordinator.run(result: $0) }
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

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard coordinator.state.isLauncherVisible else { return event }

            // Arrow keys always carry .numericPad and .function flags — strip them
            // before checking whether any significant modifier is held.
            let significant = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.numericPad, .function])
            guard significant.isEmpty else { return event }

            switch Int(event.keyCode) {
            case kVK_UpArrow:
                moveSelection(by: -1)
                return nil
            case kVK_DownArrow:
                moveSelection(by: 1)
                return nil
            default:
                return event
            }
        }
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
}

// MARK: - Results List

private struct ResultsList: View {
    let results: [SearchResultItem]
    let selectedID: SearchResultItem.ID?
    let onRun: (SearchResultItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(results) { item in
                        ResultRow(
                            item: item,
                            isSelected: selectedID == item.id,
                            action: { onRun(item) }
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ResultIconView(item: item)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
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
        case .openURL:
            iconShell(systemName: "globe")
        case .runShellCommand:
            iconShell(systemName: "terminal")
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

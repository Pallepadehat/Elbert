import SwiftUI
import AppKit

private struct EscapeKeyHandler: ViewModifier {
    let isEnabled: Bool
    let perform: () -> Void

    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard isEnabled else { return event }
                    guard Int(event.keyCode) == KeyboardKeyCode.escape else { return event }
                    perform()
                    return nil
                }
            }
            .onDisappear {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                    self.monitor = nil
                }
            }
    }
}

extension View {
    func onEscapeKey(enabled: Bool = true, perform: @escaping () -> Void) -> some View {
        modifier(EscapeKeyHandler(isEnabled: enabled, perform: perform))
    }
}

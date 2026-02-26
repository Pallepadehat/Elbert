import SwiftUI

enum AppStyle {
    static let windowPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 18
    static let cardCornerRadius: CGFloat = 14
    static let panelCornerRadius: CGFloat = 20
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppStyle.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.cardCornerRadius, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }
}

struct AppPanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppStyle.panelCornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppStyle.panelCornerRadius, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardModifier())
    }

    func appPanelBackground() -> some View {
        modifier(AppPanelBackground())
    }
}

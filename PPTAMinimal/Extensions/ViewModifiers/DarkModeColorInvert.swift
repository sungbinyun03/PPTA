import SwiftUI

struct DarkModeColorInvert: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.colorInvert()
        } else {
            content
        }
    }
}

extension View {
    func invertedForDarkMode() -> some View {
        modifier(DarkModeColorInvert())
    }
}

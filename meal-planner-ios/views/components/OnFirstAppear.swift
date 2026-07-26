//
//  OnFirstAppear.swift
//  meal-planner-ios
//

import SwiftUI

private struct FirstAppearModifier: ViewModifier {
    @State private var hasAppeared = false
    let action: () -> Void
    let loading: Binding<Bool>

    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            loading.wrappedValue = true
            defer { loading.wrappedValue = false }
            action()
        }
    }
}

extension View {
    /// Runs `action` exactly once for the lifetime of this view's identity.
    ///
    /// Unlike `onAppear` or `task`, the action is not repeated when the view
    /// reappears — for example, when returning from a pushed destination in a
    /// `NavigationStack`. This makes it suitable for one-time draft loading that
    /// must not clobber in-progress edits.
    func onFirstAppear(perform action: @escaping () -> Void, loading: Binding<Bool>) -> some View {
        modifier(FirstAppearModifier(action: action, loading: loading))
    }
}

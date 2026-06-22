//
//  WithEditContext.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 21/06/2026.
//

import SwiftUI
import SwiftData

struct WithEditContext<Content: View>: View {
    @State private var editContext: ModelContext
    private let content: () -> Content

    init(
        from parentContext: ModelContext,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._editContext = State(initialValue: parentContext.editContext())
        self.content = content
    }

    var body: some View {
        content()
            .modelContext(editContext)
    }
}

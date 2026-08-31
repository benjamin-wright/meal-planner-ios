//
//  FlowContainer.swift
//  meal-planner-ios
//

import SwiftUI

struct FlowContainer<Content: View>: View {
    @State private var router = FlowRouter()
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            AppGlassBackground {
                content()
                    .navigationDestination(for: FlowRouter.Route.self) { route in
                        AppGlassBackground {
                            FlowDestination(route: route)
                        }
                    }
            }
        }
        .environment(router)
    }
}

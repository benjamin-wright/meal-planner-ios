---
name: swiftui-app-flows
description: Guide SwiftUI screen, navigation, picker, and visual changes in this iOS meal planner. Use when editing views, tab flows, forms, or UI accessibility.
---

# SwiftUI app flows

Use the existing app structure before introducing new navigation or styling abstractions.

1. Trace the affected tab from `meal-planner-ios/views/MealPlannerView.swift` through its `*FlowView` and `FlowContainer.swift`. Each flow owns a `FlowRouter` path; destinations are dispatched by `FlowDestination.swift`. Extend those routes for nested editors and pickers rather than creating a separate navigation stack inside a flow.
2. Keep editing state in the relevant draft and preserve it when navigating to a picker and back. Check the existing `FlowRouter` selection callbacks and the `views/data` editor/picker pairs before changing their behavior.
3. Follow the existing glass treatment in `views/components/GlassTheme.swift`: use `AppGlassBackground`, `GlassList`, `GlassForm`, and the shared glass modifiers where appropriate. Preserve readable contrast, Reduce Transparency behavior, and the transparent navigation/tab chrome configured by `GlassChrome` and `TransparentContainerConfigurator`.
4. Views query SwiftData with `@Query` and access the context through the environment; put validation and persistence in the existing model stores rather than in view bodies. Use `.modelContainer(Models.testing.modelContainer)` for previews that need sample data.
5. For changed user journeys, check both the behavior and accessibility of controls in light/dark appearance, including picker return paths. Add or update UI coverage under `meal-planner-iosUITests/` when a user-facing flow changes. Use the `xcode-validation` skill for build/test verification.

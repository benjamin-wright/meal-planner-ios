---
name: swiftdata-meal-domain
description: Guide SwiftData model, draft, store, meal planning, and shopping-list changes in this app. Use for persistence, relationships, unit conversion, or list regeneration work.
---

# SwiftData meal domain

1. Start at the relevant `meal-planner-ios/models/` type and its store. Persisted types use `@Model`; edits are staged in draft values and validated by stores such as `RecipieStore`, `MealStore`, and `ItemStore`. Resolve referenced IDs before saving and preserve explicit `ModelContext` saves and error handling.
2. If adding a persisted model, update the schema in `Models.swift` and consider its seeded/testing container and reset behavior. Check relationships and deletion semantics for existing data; do not assume that a fresh in-memory container catches migration issues.
3. Keep catalogue meals/recipes distinct from `PlannedMeal` snapshots. Trace edits through the planner and `ShoppingListStore.regenerate()` before changing quantities: recipe servings scale ingredients, ready meals use count units, weight/volume convert to preferred units, and dissimilar count units remain separate.
4. Protect failed multi-entity saves from partial persistence. The imported-recipe path in `RecipieStore.swift` uses a separate context with autosave disabled for this reason; follow its transaction boundary when changing that path.
5. Cover validation, missing references, conversion and persistence with Swift Testing tests in `meal-planner-iosTests/meal_planner_iosTests.swift` or a focused test file. See `xcode-validation` for the project's test scheme and platform constraints.

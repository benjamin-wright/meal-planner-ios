import SwiftUI

/// Owns the scroll surface required by the iOS 26 cross-course drag interaction.
/// Saved and planned meal editors provide their details and save actions only.
struct MealComponentsForm<Details: View, Actions: View>: View {
    @Binding var components: [MealComponentDraft]
    let isEditing: Bool
    let recipies: [Recipie]
    let items: [Item]
    let units: [Unit]
    let onAdd: (CourseType) -> Void
    let onEditPortion: (MealComponentDraft) -> Void
    var allowsRecipeEditing = false
    let details: () -> Details
    let actions: () -> Actions

    @State private var isReordering = false
    @State private var scrollController = MealComponentScrollController()

    var body: some View {
        GeometryReader { geometry in
            GlassForm {
                details()
                MealComponentsEditor(
                    components: $components, isEditing: isEditing,
                    recipies: recipies, items: items, units: units,
                    onAdd: onAdd, onEditPortion: onEditPortion,
                    allowsRecipeEditing: allowsRecipeEditing,
                    onReorderingChanged: { isReordering = $0 },
                    viewport: geometry.frame(in: .global),
                    scrollController: scrollController
                )
                actions().disabled(isEditing)
            }
            .scrollDisabled(isReordering)
        }
    }
}

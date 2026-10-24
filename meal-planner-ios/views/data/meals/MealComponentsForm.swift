import SwiftUI

/// Shared dish list with the details and save actions for each kind of meal.
struct MealComponentsForm<Details: View, Actions: View>: View {
    @Binding var components: [MealComponentDraft]
    let recipies: [Recipie]
    let items: [Item]
    let units: [Unit]
    let onAdd: () -> Void
    let onEdit: (MealComponentDraft) -> Void
    var allowsRecipeEditing = false
    var onReplace: ((MealComponentDraft) -> Void)? = nil
    let details: () -> Details
    let actions: () -> Actions

    var body: some View {
        GlassForm {
            details()
            MealComponentsEditor(
                components: $components,
                recipies: recipies, items: items, units: units,
                onAdd: onAdd, onEdit: onEdit,
                allowsRecipeEditing: allowsRecipeEditing, onReplace: onReplace
            )
            actions()
        }
    }
}

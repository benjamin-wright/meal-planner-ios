import SwiftUI

struct PlannedRecipeEdit: View {
    @Environment(FlowRouter.self) private var router
    @State private var component: MealComponentDraft
    let recipe: Recipie
    let items: [Item]
    let units: [Unit]
    let onSave: (MealComponentDraft) -> Void

    init(component: MealComponentDraft, recipe: Recipie, items: [Item], units: [Unit], onSave: @escaping (MealComponentDraft) -> Void) {
        self._component = State(initialValue: component)
        self.recipe = recipe
        self.items = items
        self.units = units
        self.onSave = onSave
    }

    private func edit(_ ingredient: RecipieIngredientDraft) {
        router.showRecipieIngredient(ingredient, isEditing: true) { updated in
            component.updateIngredient(updated, in: recipe)
        }
    }

    private var isValid: Bool {
        component.hasValidPortion && recipe.serves > 0 &&
            (try? IngredientResolver(items: items, units: units).resolve(component.ingredients(for: recipe))) != nil
    }

    var body: some View {
        GlassForm {
            Section {
                Text(recipe.name + (component.ingredientOverrides.isEmpty ? "" : "*"))
            } header: {
                GlassSectionHeader(title: "Recipe")
            } footer: {
                Text("Changes apply only to this dish, not the original recipe. * indicates a modified recipe.")
            }
            Section {
                ForEach(component.ingredients(for: recipe)) { ingredient in
                    Button { edit(ingredient) } label: {
                        ItemQuantityRow(
                            name: items.first { $0.id == ingredient.itemID }?.name ?? "Missing ingredient",
                            quantity: units.first { $0.id == ingredient.unitID }?.toString(forValue: ingredient.quantity) ?? "Missing unit"
                        )
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("plannedRecipeIngredient-\(ingredient.id)")
                }
            } header: {
                GlassSectionHeader(title: "Ingredients")
            } footer: {
                Text("Quantities are for \(recipe.serves) recipe servings. The planner scales these to the planned meal’s servings. Tap an ingredient to change its quantity, item, or unit.")
            }
            if !component.ingredientOverrides.isEmpty {
                Button("Reset to Original Recipe", role: .destructive) {
                    component.ingredientOverrides = []
                }
            }
            Button("Save Changes") {
                onSave(component)
            }
            .disabled(!isValid)
            .accessibilityIdentifier("savePlannedRecipe")
        }
        .navigationTitle("Planned Recipe")
    }
}

import SwiftUI

/// A read-only preview, including any substitutions made for this occurrence.
struct RecipePreview: View {
    let recipe: Recipie
    let component: MealComponentDraft?
    let servings: Int?
    let items: [Item]
    let units: [Unit]

    init(
        recipe: Recipie, component: MealComponentDraft? = nil, servings: Int? = nil,
        items: [Item], units: [Unit]
    ) {
        self.recipe = recipe
        self.component = component
        self.servings = servings
        self.items = items
        self.units = units
    }

    private var display: RecipeDisplayData {
        RecipeDisplayData(recipe: recipe, component: component, servings: servings, items: items, units: units)
    }

    var body: some View {
        let display = self.display
        GlassForm {
            Section {
                if !display.summary.isEmpty {
                    Text(display.summary)
                }
                LabeledContent("Cooking time", value: display.time >= 0 ? "\(display.time) minutes" : "Not recorded")
                LabeledContent("Servings", value: "\(display.servings)")
                if display.hasSubstitutions {
                    Label("Includes your ingredient substitutions", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(display.ingredients) { ingredient in
                    ItemQuantityRow(
                        name: ingredient.name,
                        quantity: ingredient.quantity
                    )
                    .accessibilityIdentifier("recipePreviewIngredient-\(ingredient.id)")
                }
                if display.ingredients.isEmpty {
                    Text("No ingredients recorded.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                GlassSectionHeader(title: "Ingredients")
            } footer: {
                Text("Quantities are for \(display.servings) servings.")
            }

            Section {
                ForEach(Array(display.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(step)
                    }
                    .accessibilityElement(children: .combine)
                }
                if display.steps.isEmpty {
                    Text("No method has been recorded for this recipe.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                GlassSectionHeader(title: "Method")
            }
        }
        .navigationTitle(display.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

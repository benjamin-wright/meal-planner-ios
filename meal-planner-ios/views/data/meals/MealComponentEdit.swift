import SwiftUI

struct MealComponentEdit: View {
    @Environment(FlowRouter.self) private var router

    @State private var value: MealComponentDraft
    private let isEditing: Bool
    private let recipies: [Recipie]
    private let items: [Item]
    private let units: [Unit]
    private let onSave: (MealComponentDraft) -> Void

    init(
        value: MealComponentDraft,
        isEditing: Bool,
        recipies: [Recipie],
        items: [Item],
        units: [Unit],
        onSave: @escaping (MealComponentDraft) -> Void
    ) {
        self._value = State(initialValue: value)
        self.isEditing = isEditing
        self.recipies = recipies
        self.items = items
        self.units = units
        self.onSave = onSave
    }

    private var isIngredient: Bool {
        if case .ingredient = value.source { return true }
        return false
    }

    private var sourceName: String? {
        switch value.source {
        case .recipe(let id): recipies.first { $0.id == id }?.name
        case .readymeal(let id): items.first { $0.id == id && $0.itemKind == .readymeal }?.name
        case .ingredient(let id): items.first { $0.id == id && $0.itemKind == .ingredient }?.name
        }
    }

    private var unit: Unit? {
        units.first { $0.id == value.unitID }
    }

    private var quantity: Binding<Double> {
        Binding(get: { value.quantity ?? 1 }, set: { value.quantity = $0 })
    }

    private var validationMessage: String? {
        if sourceName == nil { return "The selected dish no longer exists." }
        if isIngredient {
            if unit == nil { return "Choose a unit for this portion." }
            guard let quantity = value.quantity, quantity > 0, quantity.isFinite else {
                return "Quantity must be greater than zero."
            }
        }
        return nil
    }

    var body: some View {
        GlassForm {
            Section("Dish") {
                LabeledContent("Name", value: sourceName ?? "Missing dish")
            }
            if isIngredient {
                Section {
                    Button {
                        router.showUnitPicker(selectedID: value.unitID ?? UUID()) { id in
                            value.unitID = id
                        }
                    } label: {
                        Text("Unit").badge(unit?.name ?? "Choose")
                    }
                    if let unit {
                        UnitInput(label: "Quantity", unit: .constant(unit), value: quantity)
                            .accessibilityIdentifier("mealComponentQuantity")
                    }
                } header: {
                    Text("Portion per person")
                } footer: {
                    Text("This amount is for one person. The planner scales it by the meal’s servings.")
                }
            }
            if let validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
            }
            Button(isEditing ? "Save" : "Add") {
                onSave(value)
            }
            .disabled(validationMessage != nil)
            .accessibilityIdentifier("saveMealComponent")
        }
        .navigationTitle("Ingredient Portion")
    }
}

struct MealComponentRow: View {
    let component: MealComponentDraft
    let recipies: [Recipie]
    let items: [Item]
    let units: [Unit]
    var isEditing: Bool = false

    private var name: String {
        switch component.source {
        case .recipe(let id): recipies.first { $0.id == id }?.name ?? "Missing recipe"
        case .readymeal(let id): items.first { $0.id == id }?.name ?? "Missing ready meal"
        case .ingredient(let id): items.first { $0.id == id }?.name ?? "Missing ingredient"
        }
    }

    private var detail: String? {
        switch component.source {
        case .recipe, .readymeal: return nil
        case .ingredient:
            if let quantity = component.quantity {
                let amount = units.first { $0.id == component.unitID }?.toString(forValue: quantity)
                    ?? String(format: "%g", quantity)
                return "\(amount) per person"
            }
            return "Missing portion"
        }
    }

    var body: some View {
        if isEditing {
            // Keep delete and reorder controls as separate accessibility elements.
            Text(detail.map { "\(name): \($0)" } ?? name)
                .lineLimit(2)
                .accessibilityValue(component.course.label)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(component.course.label)
        }
    }
}

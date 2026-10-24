import SwiftUI

/// Shared controls for quantities that have already been resolved to a unit.
struct QuantityFields: View {
    let unit: Unit?
    @Binding var quantity: Double
    var unitPlaceholder = "Choose unit"
    var quantityIdentifier = "quantity"
    let onChooseUnit: () -> Void

    var body: some View {
        Button {
            onChooseUnit()
        } label: {
            Text("Unit").badge(unit?.name ?? unitPlaceholder)
        }
        if let unit {
            UnitInput(label: "Quantity", unit: .constant(unit), value: $quantity)
                .accessibilityIdentifier(quantityIdentifier)
        }
    }
}

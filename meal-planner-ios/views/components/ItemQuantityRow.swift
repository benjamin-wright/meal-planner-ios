import SwiftUI

/// A display-only row for an item and its already-formatted quantity.
/// Callers own selection, editing, completion state and unit conversion.
struct ItemQuantityRow: View {
    let name: String
    let quantity: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent {
                Text(quantity)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            } label: {
                Text(name)
            }
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Item quantities") {
    GlassForm {
        ItemQuantityRow(name: "Carrots", quantity: "250g")
        ItemQuantityRow(name: "Extra virgin olive oil", quantity: "2 tablespoons")
        ItemQuantityRow(name: "Chopped tomatoes", quantity: "400g", detail: "1 tin, including the juice")
        ItemQuantityRow(name: "A long ingredient name that wraps onto another line", quantity: "1.5kg")
    }
}

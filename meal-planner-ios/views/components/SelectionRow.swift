import SwiftUI

struct SelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SelectionRowPreview: View {
    @State private var selection = "Vegetables"

    var body: some View {
        GlassList {
            ForEach(["Vegetables", "Fruit", "Herbs and seasonings"], id: \.self) { title in
                SelectionRow(title: title, isSelected: selection == title) {
                    selection = title
                }
            }
        }
    }
}

#Preview("Light") {
    SelectionRowPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    SelectionRowPreview().preferredColorScheme(.dark)
}

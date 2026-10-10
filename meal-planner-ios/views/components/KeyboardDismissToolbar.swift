import SwiftUI
import UIKit

/// One dismissal control for text, multiline, numeric and search inputs.
struct KeyboardDismissToolbar: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Hide Keyboard", systemImage: "keyboard.chevron.compact.down") {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
            .labelStyle(.titleAndIcon)
            .accessibilityIdentifier("hideKeyboard")
        }
    }
}

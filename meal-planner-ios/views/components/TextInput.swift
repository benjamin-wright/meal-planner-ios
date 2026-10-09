//
//  TextInput.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import Foundation
import SwiftUI

struct TextInput: View {
    @Binding var text: String
    @State var label: String?
    @State var placeholder: String
    @State var alignment: TextAlignment = .leading
    @State var multiline: Bool = false
    
    var TextView: some View {
        TextField(placeholder, text: $text, axis: multiline ? .vertical : .horizontal)
            .textInputAutocapitalization(.never)
            .onChange(of: text) {
                text = text.lowercased()
            }.multilineTextAlignment(alignment)
            .lineLimit(multiline ? 3...10 : 1...1)
            .fixedSize(horizontal: false, vertical: multiline)
            .submitLabel(multiline ? .return : .done)
    }
    
    var body: some View {
        if let label {
            if multiline {
                VStack(alignment: .leading, spacing: 8) {
                    Text(label + ":")
                    self.TextView
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(label)
                }
            } else {
                LabeledContent(label + ":") {
                    self.TextView
                }
            }
        } else {
            self.TextView
        }
    }
}

#Preview {
    GlassForm {
        Section("Single line") {
            TextInput(text: .constant("things"), label: "Name", placeholder: "placeholder")
            TextInput(text: .constant("unlabeled"), placeholder: "placeholder", alignment: .center)
        }
        Section("Multiline") {
            TextInput(text: .constant(""), label: "Empty", placeholder: "A basic description", multiline: true)
            TextInput(text: .constant("A quick weekday dinner."), label: "Short", placeholder: "A basic description", multiline: true)
            TextInput(text: .constant("A warming vegetable stew with beans, tomatoes and herbs, simmered until tender. Serve with crusty bread for an easy family dinner.\nLeftovers keep well for lunch the next day."), label: "Summary", placeholder: "A basic description", multiline: true)
        }
    }
}

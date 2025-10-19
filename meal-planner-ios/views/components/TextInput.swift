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
            .lineLimit(multiline ? 10 : 1)
            .submitLabel(multiline ? .return : .done)
    }
    
    var body: some View {
        if label != nil {
            LabeledContent(label! + ":") {
                self.TextView
            }
        } else {
            self.TextView
        }
    }
}

#Preview {
    TextInput(text: .constant("things"), label: "Name", placeholder: "placeholder").padding()
    TextInput(text: .constant("unlabeled"), placeholder: "placeholder", alignment: .center).padding()
    TextInput(text: .constant("A line that is far too long to fit on a single line even though this screen is really really big and only needs three lines to show this."), placeholder: "fill me", multiline: true)
}

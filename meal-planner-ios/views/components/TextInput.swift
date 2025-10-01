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
    
    var TextView: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(.never)
            .onChange(of: text) {
                text = text.lowercased()
            }.multilineTextAlignment(alignment)
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
}

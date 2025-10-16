//
//  NumberInput.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import Foundation
import SwiftUI

let numberInputFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.allowsFloats = true
    formatter.usesGroupingSeparator = false
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 10
    return formatter
}()

struct NumberInput: View {
    @Binding var number: Double
    @State var label: String?
    @State var placeholder: String
    @State var alignment: TextAlignment
    
    init(number: Binding<Double>, label: String? = nil, placeholder: String, alignment: TextAlignment = .leading) {
        self._number = number
        self.label = label
        self.placeholder = placeholder
        self.alignment = alignment
    }
    
    var NumberView: some View {
        TextField(placeholder, value: $number, formatter: numberInputFormatter)
            .multilineTextAlignment(alignment)
            .keyboardType(.decimalPad)
    }
    
    var body: some View {
        if label != nil {
            LabeledContent(label! + ":") {
                self.NumberView
            }
        } else {
            self.NumberView
        }
    }
}

#Preview {
    struct Preview: View {
        @State var input: Double = 12345678.5432
        
        var body: some View {
            NumberInput(number: $input, label: "Name", placeholder: "placeholder")
            NumberInput(number: $input, placeholder: "placeholder", alignment: .center)
        }
    }
    
    return Preview()
}

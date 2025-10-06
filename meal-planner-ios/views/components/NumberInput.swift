//
//  NumberInput.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import Foundation
import SwiftUI

struct NumberInput: View {
    @Binding var number: Double
    @State var label: String?
    @State var placeholder: String
    @State private var text: String
    @State var alignment: TextAlignment
    
    init(number: Binding<Double>, label: String? = nil, placeholder: String, alignment: TextAlignment = .leading) {
        self._number = number
        self.label = label
        self.placeholder = placeholder
        self.text = String(format: "%g", number.wrappedValue)
        self.alignment = alignment
    }
    
    func filter(input: String) -> String {
        var filtered = ""
        var hasPeriod = false
        input.forEach { c in
            if !"0123456789.".contains(c) {
                return
            }
            
            if c == "." && hasPeriod {
                return
            }
            
            if c == "." {
                hasPeriod = true
            }
            
            filtered.append(c)
        }
        
        return filtered
    }
    
    var NumberView: some View {
        TextField(placeholder, text: $text)
            .multilineTextAlignment(alignment)
            .keyboardType(.decimalPad)
            .onChange(of: text) {
                let filtered = self.filter(input: text)
                
                if text != filtered {
                    text = filtered
                }
                
                let converted = Double(text)
                if converted != nil {
                    number = converted!
                }
            }
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
    NumberInput(number: .constant(6), label: "Name", placeholder: "placeholder")
    NumberInput(number: .constant(12.57), placeholder: "placeholder", alignment: .center)
}

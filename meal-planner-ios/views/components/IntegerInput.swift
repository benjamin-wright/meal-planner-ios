//
//  IntegerInput.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 06/10/2025.
//

import Foundation
import SwiftUI

struct IntegerInput: View {
    @Binding var number: Int
    @State var label: String?
    @State var placeholder: String
    
    init(number: Binding<Int>, label: String? = nil, placeholder: String) {
        self._number = number
        self.label = label
        self.placeholder = placeholder
    }
    
    var NumberView: some View {
        Stepper {
            Text(self.number.formatted())
        } onIncrement: {
            self.number += 1
        } onDecrement: {
            self.number -= 1
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
    struct Preview: View {
        @State var number = 10
        var body: some View {
            IntegerInput(number: $number, label: "units", placeholder: "placeholder")
        }
    }
    return Preview()
}

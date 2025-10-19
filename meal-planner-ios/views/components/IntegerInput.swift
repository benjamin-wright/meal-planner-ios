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
    var step: Int
    
    init(number: Binding<Int>, label: String? = nil, placeholder: String, step: Int = 1) {
        self._number = number
        self.label = label
        self.placeholder = placeholder
        self.step = step
    }
    
    var NumberView: some View {
        HStack {
            Text(number.formatted())
            
            HStack {
                Button {
                    if number > step {
                        number -= step
                    }
                } label: {
                    Image(systemName: "minus.circle.fill").scaledToFit()
                }.disabled(number <= step)
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.leading, 10)
                    .padding(.vertical, 10)
                    .tint(.primary)
                Button {
                    number += step
                } label: {
                    Image(systemName: "plus.circle.fill")
                }.buttonStyle(BorderlessButtonStyle())
                    .padding(10)
                    .padding(.leading, 5)
                    .tint(.primary)
            }.background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(15)
                .padding(.leading, 10)
        }.frame(height: .leastNormalMagnitude)
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
            Form {
                IntegerInput(number: $number, label: "units", placeholder: "placeholder")
            }
        }
    }
    return Preview()
}

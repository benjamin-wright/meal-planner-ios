//
//  EnumPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 26/07/2026.
//

import Foundation
import SwiftUI

protocol LabeledEnum: Hashable, CaseIterable, Identifiable {
    var label: String { get }
}

struct EnumPicker<T: LabeledEnum>: View
    where T.AllCases: RandomAccessCollection {
    
    @State var label: String = ""
    @Binding var selection: T
    
    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(T.allCases, id: \.id) { value in
                Text(value.label).tag(value)
            }
        }
    }
}

#Preview {
    @Previewable @State var meal: MealType = .dinner
    @Previewable @State var course: CourseType = .main
    
    GlassForm {
        EnumPicker(label: "Meal", selection: $meal)
        EnumPicker(label: "Course", selection: $course).pickerStyle(.segmented)
    }
}


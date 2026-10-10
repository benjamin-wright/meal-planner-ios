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
    enum Presentation {
        case capsule
        case automatic
    }

    @State var label: String = ""
    @Binding var selection: T
    var presentation: Presentation = .capsule

    var body: some View {
        switch presentation {
        case .capsule:
            picker
                .pickerStyle(.segmented)
                .glassControl(in: Capsule())
        case .automatic:
            picker
                .pickerStyle(.automatic)
        }
    }

    private var picker: some View {
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
        EnumPicker(label: "Meal", selection: $meal, presentation: .automatic)
        EnumPicker(label: "Course", selection: $course)
    }
}

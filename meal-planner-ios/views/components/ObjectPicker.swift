//
//  ObjectPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 01/10/2025.
//

import Foundation
import SwiftUI

struct ObjectPicker: View {
    @Binding var text: String
    @State var label: String?
    @State var placeholder: String
    
    var body: some View {
        
    }
}

#Preview {
    ObjectPicker(text: .constant("things"), label: "Name", placeholder: "placeholder")
}

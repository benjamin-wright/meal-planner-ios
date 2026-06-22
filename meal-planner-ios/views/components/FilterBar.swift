//
//  FilterBar.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 21/06/2026.
//

import SwiftUI

struct SelectableButtonStyle: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        if selected {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

struct ImageButton: View {
    @State var image: String
    @Binding var selected: Bool
    
    init(image: String, selected: Binding<Bool>) {
        self.image = image
        self._selected = selected
    }
    
    var body: some View {
        Button(action: {
            
        }) {
            Image(systemName: image)
                .resizable()
                .frame(width: 20, height: 20)
                .padding(.all, 6)
        }
        .modifier(SelectableButtonStyle(selected: selected))
        .buttonBorderShape(.circle)
    }
}

struct FilterBar: View {
    var body: some View {
        HStack {
            ImageButton(image: "carrot.fill", selected: .constant(false))
            ImageButton(image: "microwave.fill", selected: .constant(true))
            ImageButton(image: "toilet.fill", selected: .constant(false))
        }
    }
}

#Preview {
    FilterBar()
}

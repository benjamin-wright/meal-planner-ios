//
//  FilterButton.swift
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

struct FilterButton: View {
    @State var image: String
    @Binding var selected: Bool
    
    init(image: String, selected: Binding<Bool>) {
        self.image = image
        self._selected = selected
    }
    
    var body: some View {
        Button(action: {
            selected = !selected
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

#Preview {
    @Previewable @State var forkSelected: Bool = false
    @Previewable @State var leafSelected: Bool = false
    @Previewable @State var flameSelected: Bool = false
    
    HStack {
        FilterButton(image: "fork.knife", selected: $forkSelected)
        FilterButton(image: "leaf", selected: $leafSelected)
        FilterButton(image: "flame", selected: $flameSelected)
    }
}

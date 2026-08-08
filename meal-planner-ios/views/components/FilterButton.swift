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

enum ImageType {
    case system(_ name: String)
    case asset(_ name: String)
}

struct FilterButton: View {
    @State var image: ImageType
    @State var aspect: CGFloat
    @Binding var selected: Bool
    
    init(image: ImageType, aspect: CGFloat = 1, selected: Binding<Bool>) {
        self.image = image
        self._selected = selected
        self.aspect = aspect
    }
    
    func pickImage() -> Image {
        switch self.image {
        case .system(let name):
            return Image(systemName: name)
        case .asset(let name):
            return Image(name)
        }
    }
    
    var body: some View {
        Button(action: {
            selected = !selected
        }) {
            pickImage()
                .resizable()
                .frame(width: 20 * aspect, height: 20)
                .padding(.all, 10)
        }
        .frame(width: 70, height: 50)
        .modifier(SelectableButtonStyle(selected: selected))
        .buttonBorderShape(.circle)
    }
}

#Preview {
    @Previewable @State var forkSelected: Bool = false
    @Previewable @State var leafSelected: Bool = false
    @Previewable @State var flameSelected: Bool = false
    
    HStack {
        FilterButton(image: .system("fork.knife"), selected: $forkSelected)
        FilterButton(image: .system("leaf"), selected: $leafSelected)
        FilterButton(image: .asset("milk"), aspect: 0.7, selected: $flameSelected)
    }
}

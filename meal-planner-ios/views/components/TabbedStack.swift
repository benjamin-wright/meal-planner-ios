//
//  TabbedStack.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 06/06/2026.
//

import SwiftUI

struct TabPage {
    var title: String
    var content: () -> AnyView
}

struct TabbedStack: View {
    var pages: [TabPage] = []
    @State var selectedPage: Int = 0

    init(pages: [TabPage]) {
        self.pages = pages
    }
    
    var body: some View {
        VStack {
            Picker("Type", selection: $selectedPage) {
                ForEach(0..<pages.count, id: \.self) {
                    Text(self.pages[$0].title)
                }
            }
            .frame(maxWidth: .infinity).padding(.top, 16)
            .pickerStyle(.segmented)
            pages[selectedPage].content().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    TabbedStack(pages: [
        TabPage(title: "First", content: { AnyView(Text("First Content")) }),
        TabPage(title: "Second", content: { AnyView(Text("Second Content")) }),
    ])
}

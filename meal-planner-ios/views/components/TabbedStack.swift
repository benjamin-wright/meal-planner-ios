//
//  TabbedStack.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 20/09/2025.
//

import SwiftUI

struct TabPage {
    var title: String
    var content: AnyView
}

struct TabbedStack: View {
    var pages: [TabPage] = []
    @State var selectedPage: Int = 0

    init(pages: [TabPage]) {
        self.pages = pages
    }
    
    var body: some View {
        VStack {
            HStack {
                ForEach(pages, id: \.self.title) { page in
                    Button() {
                        selectedPage = pages.firstIndex(where: { $0.title == page.title }) ?? 0
                    } label: {
                        Text(page.title)
                    }.frame(maxWidth: .infinity).foregroundStyle(page.title == pages[selectedPage].title ? .primary : .secondary)
                }
            }.frame(maxWidth: .infinity).padding(.top, 16)
            pages[selectedPage].content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    TabbedStack(pages: [
        TabPage(title: "First", content: AnyView(Text("First"))),
        TabPage(title: "Second", content: AnyView(Text("Second"))),
    ])
}

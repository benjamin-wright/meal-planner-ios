//
//  UnitsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 20/09/2025.
//

import SwiftUI
import SwiftData

struct UnitsView: View {
    @State var selectedUnit: Int = 0
    let types = [ "Count", "Weight", "Volume" ]
    
    var body: some View {
        NavigationStack {
            TabbedStack(pages: [
                TabPage(title: "Count", content: AnyView(CountUnitsView())),
                TabPage(title: "Weight", content: AnyView(Text("Weight"))),
                TabPage(title: "Volume", content: AnyView(Text("Volume"))),
            ])
        }
    }
}

#Preview {
    UnitsView().modelContainer(Models.testing.modelContainer)
}

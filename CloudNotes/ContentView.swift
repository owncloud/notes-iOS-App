//
//  ContentView.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 1/3/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State var text = ""

    var body: some View {
        GeometryReader { geometry in
            VStack {
                HSplitView {
                    VStack { Text("Pane 1") }.frame(minWidth: 100.0, idealWidth: 250.0, maxWidth: 400.0, maxHeight: .infinity)
                    VStack { EditorTextView(text: self.$text) }.frame(minWidth: 200.0, maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

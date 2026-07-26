//
//  ContentView.swift
//  iRAM-Plus
//
//  Created by NovaDev404
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        WizardView()
            .environmentObject(DataManager.shared.model)
    }
}

#Preview {
    ContentView()
}

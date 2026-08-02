//
//  GetMoreRamApp.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/14.
//

import SwiftUI

@main
struct iRAMPlusApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            "saveLoginToKeychain": true
        ])
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

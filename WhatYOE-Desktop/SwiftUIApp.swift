/*
SwiftUI App Entry Point for WhatYOE Desktop Interface
*/

import SwiftUI

@main
struct WhatYOEDesktopApp: App {
    @NSApplicationDelegateAdaptor(DesktopAppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 700)
                .navigationTitle("")
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
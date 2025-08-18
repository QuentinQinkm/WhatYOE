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
        .commands {
            CommandGroup(after: .newItem) {
                Menu("Edit") {
                    Button("Remove All Scanned Jobs") {
                        removeAllScannedJobs()
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                }
            }
        }
    }
    
    private func removeAllScannedJobs() {
        let alert = NSAlert()
        alert.messageText = "Remove All Scanned Jobs"
        alert.informativeText = "This will permanently delete all analyzed job data and clear all caches. This action cannot be undone."
        alert.addButton(withTitle: "Remove All Jobs & Caches")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Clear all job data and caches
            JobManager.shared.removeAllJobs()
            
            // Clear resume name cache
            UserDefaults.standard.removeObject(forKey: "resumeNameCache")
            
            // Show confirmation
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Jobs & Caches Removed"
            confirmAlert.informativeText = "All scanned jobs and cached data have been successfully removed."
            confirmAlert.addButton(withTitle: "OK")
            confirmAlert.alertStyle = .informational
            confirmAlert.runModal()
        }
    }
}
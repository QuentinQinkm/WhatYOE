/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Desktop Interface App - handles local analysis UI
*/
import Cocoa
import os.log

class DesktopAppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    private var analysisWindow: NSWindow?
    
    override init() {
        super.init()
        print("🖥️ Desktop App init called")
    }
    
    @MainActor
    func applicationWillFinishLaunching(_ notification: Notification) {
        print("🖥️ Desktop App will finish launching")
        
        // ALWAYS run as desktop app (show dock icon)
        NSApplication.shared.setActivationPolicy(.regular)
        print("✅ Set activation policy to regular (desktop app)")
    }
    
    @MainActor
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🖥️ Desktop App launched")
        
        // Create and show the analysis window immediately
        createAndShowAnalysisWindow()
    }
    
    @MainActor
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Desktop app should quit when window is closed
        print("🔄 Desktop app window closed - terminating")
        return true
    }
    
    @MainActor
    func applicationWillTerminate(_ aNotification: Notification) {
        print("🛑 Desktop App terminating")
    }
    
    // MARK: - Window Management
    
    @MainActor
    private func createAndShowAnalysisWindow() {
        // SwiftUI app will handle window creation automatically
        print("✅ SwiftUI Desktop app launched")
    }
}
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
        print("🔧 Creating desktop analysis window")
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "WhatYOE - Desktop Analysis Interface"
        window.center()
        
        // Create the analysis view controller
        let viewController = DesktopAnalysisViewController()
        window.contentViewController = viewController
        
        analysisWindow = window
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("✅ Desktop analysis window created and shown")
    }
}
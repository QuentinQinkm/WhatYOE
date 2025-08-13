/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Controls the extension's parent app.
*/
import Cocoa
import os.log
import UniformTypeIdentifiers
import UserNotifications // Added for UNUserNotificationCenter

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    private var statusItem: NSStatusItem?
    private var analysisWindow: NSWindow?
    
    override init() {
        super.init()
        print("🔧 AppDelegate init called - PRINT STATEMENT")
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        print("🚀 applicationWillFinishLaunching called - PRINT STATEMENT")
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 WhatYOE Status Bar App launched - PRINT STATEMENT")
        os_log(.default, "🚀 WhatYOE Status Bar App launched")
        
        // Set up status bar immediately
        print("🔧 Setting up status bar... - PRINT STATEMENT")
        setupStatusBar()
        requestNotificationPermissions()
        
        // Check for command line arguments
        let arguments = CommandLine.arguments
        if arguments.contains("--open-resume-tab") {
            os_log(.default, "📄 Command line argument detected: opening Resume tab")
            // Delay opening to ensure status bar is set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.openAnalysisWindow(selectedTab: 0) // Resume tab
            }
        }
        
        os_log(.default, "✅ App setup complete - status bar should be visible")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        os_log(.default, "🛑 WhatYOE Status Bar App terminating")
    }
    
    private func setupStatusBar() {
        print("🔧 Setting up status bar... - PRINT STATEMENT")
        os_log(.default, "🔧 Setting up status bar...")
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Verify status bar item was created
        guard let statusItem = statusItem else {
            print("❌ Failed to create status bar item - PRINT STATEMENT")
            os_log(.error, "❌ Failed to create status bar item")
            return
        }
        
        print("✅ Status bar item created - PRINT STATEMENT")
        os_log(.default, "✅ Status bar item created")
        
        // Set status bar icon
        if let button = statusItem.button {
            button.title = "📊"
            button.font = NSFont.systemFont(ofSize: 16)
            print("✅ Status bar button configured - PRINT STATEMENT")
            os_log(.default, "✅ Status bar button configured")
        } else {
            print("❌ Status bar button is nil - PRINT STATEMENT")
            os_log(.error, "❌ Status bar button is nil")
            return
        }
        
        // Create and configure menu
        let statusMenu = NSMenu()
        
        // Local Analysis menu item
        let localAnalysisItem = NSMenuItem(title: "Local Analysis", action: #selector(openLocalAnalysis), keyEquivalent: "")
        localAnalysisItem.target = self
        statusMenu.addItem(localAnalysisItem)
        
        // Import Resume menu item
        let importResumeItem = NSMenuItem(title: "Import", action: #selector(openResumeTab), keyEquivalent: "")
        importResumeItem.target = self
        statusMenu.addItem(importResumeItem)
        
        // Separator
        statusMenu.addItem(NSMenuItem.separator())
        
        // Hide Main Window menu item
        let hideWindowItem = NSMenuItem(title: "Hide Main Window", action: #selector(hideMainWindow), keyEquivalent: "")
        hideWindowItem.target = self
        statusMenu.addItem(hideWindowItem)
        
        // Separator
        statusMenu.addItem(NSMenuItem.separator())
        
        // Exit menu item
        let exitItem = NSMenuItem(title: "Exit", action: #selector(exitApp), keyEquivalent: "")
        exitItem.target = self
        statusMenu.addItem(exitItem)
        
        // Set the menu
        statusItem.menu = statusMenu
        
        os_log(.default, "✅ Status bar menu configured")
        os_log(.default, "🎯 Status bar setup complete")
    }
    
    @objc private func openLocalAnalysis() {
        print("🔍 openLocalAnalysis called - PRINT STATEMENT")
        os_log(.default, "📊 Opening Local Analysis")
        
        openAnalysisWindow(selectedTab: 1) // Local Analysis tab
    }
    
    @objc private func openResumeTab() {
        print("🔍 openResumeTab called - PRINT STATEMENT")
        os_log(.default, "📄 Opening Resume tab")
        
        openAnalysisWindow(selectedTab: 0) // Resume tab
    }
    
    private func openAnalysisWindow(selectedTab: Int) {
        // Create and show the analysis window
        if analysisWindow == nil {
            print("🔧 Creating new analysis window - PRINT STATEMENT")
            createAnalysisWindow()
        } else {
            print("🔧 Using existing analysis window - PRINT STATEMENT")
        }
        
        // Set the selected tab
        if let viewController = analysisWindow?.contentViewController as? AnalysisViewController {
            viewController.selectTab(selectedTab)
        }
        
        // Temporarily change activation policy to show window
        NSApplication.shared.setActivationPolicy(.regular)
        
        analysisWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("✅ Analysis window should be visible now - PRINT STATEMENT")
    }
    
    @objc private func importResume() {
        os_log(.default, "📄 Import Resume requested")
        
        // Auto-open file picker
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.pdf]
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Select Resume PDF"
        openPanel.message = "Choose your resume PDF file to import"
        
        openPanel.begin { [weak self] result in
            if result == .OK, let url = openPanel.url {
                self?.handleResumeImport(url: url)
            }
        }
    }
    
    @objc private func exitApp() {
        os_log(.default, "🚪 Exit requested")
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func hideMainWindow() {
        os_log(.default, "🔄 Hiding main window and switching to accessory mode")
        
        // Hide any remaining windows
        NSApplication.shared.windows.forEach { window in
            window.orderOut(nil)
        }
        
        // Switch to accessory mode
        NSApplication.shared.setActivationPolicy(.accessory)
        os_log(.default, "✅ Switched to accessory mode")
    }
    
    private func createAnalysisWindow() {
        print("🔧 createAnalysisWindow called - PRINT STATEMENT")
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "WhatYOE - Resume Analysis"
        window.center()
        window.delegate = self
        
        let viewController = AnalysisViewController()
        window.contentViewController = viewController
        
        analysisWindow = window
        
        print("✅ Analysis window created successfully - PRINT STATEMENT")
    }
    
    private func handleResumeImport(url: URL) {
        os_log(.default, "📄 Resume imported: %@", url.lastPathComponent)
        
        // Store the file path for now - the actual cleaning will happen in the analysis window
        UserDefaults.standard.set(url.path, forKey: "lastImportedResumePath")
        
        // Show success notification using modern notification system
        let content = UNMutableNotificationContent()
        content.title = "Resume Imported"
        content.body = "Resume has been imported successfully. Open Local Analysis to process it."
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: "resume-imported", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                os_log(.error, "Failed to show notification: %@", error.localizedDescription)
            }
        }
    }
    
    // Function to get cleaned resume data for the extension
    func getCleanedResumeData() -> String {
        if let resumeData = UserDefaults.standard.string(forKey: "cleanedResumeData"), 
           !resumeData.isEmpty {
            return resumeData
        }
        return "No cleaned resume data available. Please run analysis first."
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                os_log(.default, "✅ Notification permissions granted")
            } else if let error = error {
                os_log(.error, "❌ Notification permissions denied: %@", error.localizedDescription)
            }
        }
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Don't quit the app when the analysis window is closed
        // Just hide it and change activation policy back to accessory
        if let window = notification.object as? NSWindow, window == analysisWindow {
            analysisWindow = nil
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}

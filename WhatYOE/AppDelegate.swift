import Cocoa
import os.log
import UniformTypeIdentifiers
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    private var statusItem: NSStatusItem?
    
    override init() {
        super.init()
        print("🔧 Background Service AppDelegate init called")
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        print("🚀 Background Service will finish launching")
        
        // ALWAYS run as background service (no dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)
        print("✅ Set activation policy to accessory (background service)")
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 Background Service launched")
        
        // Set up status bar immediately
        setupStatusBar()
        requestNotificationPermissions()
        
        print("✅ Background service setup complete")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        print("🛑 Background Service terminating")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Never terminate - always keep running as background service
        return false
    }
    
    // MARK: - Status Bar Setup
    
    private func setupStatusBar() {
        print("🔧 Setting up status bar...")
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else {
            print("❌ Failed to create status bar item")
            return
        }
        
        // Set status bar icon
        if let button = statusItem.button {
            button.title = "📊"
            button.font = NSFont.systemFont(ofSize: 16)
            button.toolTip = "WhatYOE Background Service"
            button.action = #selector(statusBarClicked)
            button.target = self
        }
        
        // Create menu
        let statusMenu = NSMenu()
        
        // Open Desktop Interface
        let desktopItem = NSMenuItem(title: "Open Desktop Interface", action: #selector(openDesktopInterface), keyEquivalent: "")
        desktopItem.target = self
        statusMenu.addItem(desktopItem)
        
        // Safari Extension Status
        let safariItem = NSMenuItem(title: "Safari Extension: Active", action: nil, keyEquivalent: "")
        safariItem.isEnabled = false
        statusMenu.addItem(safariItem)
        
        statusMenu.addItem(NSMenuItem.separator())
        
        // Quit
        let exitItem = NSMenuItem(title: "Quit Background Service", action: #selector(exitApp), keyEquivalent: "")
        exitItem.target = self
        statusMenu.addItem(exitItem)
        
        statusItem.menu = statusMenu
        print("✅ Status bar setup complete")
    }
    
    // MARK: - Actions
    
    @objc private func statusBarClicked() {
        print("📊 Status bar clicked - opening desktop interface")
        openDesktopInterface()
    }
    
    @objc private func openDesktopInterface() {
        print("🖥️ Launching desktop interface...")
        
        // Launch desktop app as separate process
        let desktopAppURL = getDesktopAppURL()
        
        if let url = desktopAppURL {
            Task {
                do {
                    let config = NSWorkspace.OpenConfiguration()
                    _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
                    print("✅ Desktop app launched successfully")
                } catch {
                    print("❌ Failed to launch desktop app: \(error.localizedDescription)")
                    self.showNotification(title: "Launch Error", message: "Could not launch desktop interface")
                }
            }
        } else {
            print("❌ Desktop app not found")
            showNotification(title: "Not Found", message: "Desktop app not found. Please build both targets.")
        }
    }
    
    @objc private func exitApp() {
        print("🚪 Exit requested")
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Helper Methods
    
    private func getDesktopAppURL() -> URL? {
        // Look for desktop app in the same bundle directory
        let currentAppURL = Bundle.main.bundleURL
        let desktopAppName = "WhatYOE-Desktop.app"
        let desktopAppURL = currentAppURL.deletingLastPathComponent().appendingPathComponent(desktopAppName)
        
        // Check if desktop app exists
        if FileManager.default.fileExists(atPath: desktopAppURL.path) {
            return desktopAppURL
        }
        
        // Fallback: try to find in Applications folder
        let applicationsURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
        if let appsURL = applicationsURL {
            let fallbackURL = appsURL.appendingPathComponent(desktopAppName)
            if FileManager.default.fileExists(atPath: fallbackURL.path) {
                return fallbackURL
            }
        }
        
        return nil
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else if let error = error {
                print("❌ Notification permissions denied: \(error.localizedDescription)")
            }
        }
    }
    
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: "notification", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show notification: \(error.localizedDescription)")
            }
        }
    }
}

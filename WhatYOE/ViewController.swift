/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Controls the extension's parent app.
*/
import Cocoa
import SafariServices.SFSafariApplication
import SafariServices.SFSafariExtensionManager
import os.log
import FoundationModels

let appName = "WhatYOE"
let extensionBundleIdentifier = "com.example.apple-samplecode.WhatYOE-Extension"

class ViewController: NSViewController {

    @IBOutlet var appNameLabel: NSTextField!
    
    // Create a reference to the system language model
    private var model = SystemLanguageModel.default
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appNameLabel.stringValue = appName
        
        // Check Foundation Models availability
        checkFoundationModelsAvailability()
        
        // Check the status of the extension in Safari and update the UI.
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { (state, error) in
            guard let state = state, error == nil else {
                var errorMessage: String = "Error: unable to determine state of the extension"

                if let errorDetail = error as NSError?, errorDetail.code == 1 {
                    errorMessage = "Couldn't find the WhatYOE extension. Are you running macOS 10.16+, or macOS 10.14+ with Safari 14+?"
                }

                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Check Version"
                    alert.informativeText = errorMessage
                    alert.beginSheetModal(for: self.view.window!) { (response) in }
                    
                    self.appNameLabel.stringValue = errorMessage
                }
                return
            }

            DispatchQueue.main.async {
                if state.isEnabled {
                    self.appNameLabel.stringValue = "\(appName)'s extension is currently on."
                } else {
                    self.appNameLabel.stringValue = "\(appName)'s extension is currently off. You can turn it on in Safari Extensions preferences."
                }
            }
        }
    }
    
    // MARK: - Foundation Models Availability Check
    private func checkFoundationModelsAvailability() {
        // Check if Foundation Models are available using Apple's API
        switch model.availability {
        case .available:
            os_log(.default, "✅ Foundation Models are available on this device")
        case .unavailable(.deviceNotEligible):
            os_log(.default, "❌ Foundation Models unavailable: Device not eligible")
            showFoundationModelsUnavailableAlert(reason: "Device not eligible")
        case .unavailable(.appleIntelligenceNotEnabled):
            os_log(.default, "❌ Foundation Models unavailable: Apple Intelligence not enabled")
            showFoundationModelsUnavailableAlert(reason: "Apple Intelligence not enabled")
        case .unavailable(.modelNotReady):
            os_log(.default, "⚠️ Foundation Models unavailable: Model not ready (downloading or system reasons)")
            showFoundationModelsUnavailableAlert(reason: "Model not ready")
        case .unavailable(let other):
            os_log(.default, "❌ Foundation Models unavailable: Unknown reason - %@", String(describing: other))
            showFoundationModelsUnavailableAlert(reason: "Unknown reason")
        }
    }
    
    private func showFoundationModelsUnavailableAlert(reason: String) {
        let alert = NSAlert()
        alert.messageText = "Foundation Models Unavailable"
        alert.informativeText = "Apple's Foundation Models are not available: \(reason)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        if let window = view.window {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }

}

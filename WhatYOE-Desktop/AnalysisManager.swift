/*
Analysis Manager for SwiftUI Desktop Interface
Frontend-only - communicates with backend WhatYOE app for analysis
*/

import Foundation
import AppKit

@MainActor
class AnalysisManager {
    static let shared = AnalysisManager()
    private let userDefaults: UserDefaults
    
    private init() {
        // Use shared app group container
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") {
            self.userDefaults = sharedDefaults
        } else {
            self.userDefaults = UserDefaults.standard
        }
    }
    
    func performAnalysis(
        resume: ResumeItem,
        jobDescription: String
    ) async throws -> String {
        
        // Create analysis request
        let request = AnalysisRequest(
            id: UUID().uuidString,
            resumeText: resume.cleanedText,
            jobDescription: jobDescription,
            timestamp: Date()
        )
        
        // Store request in shared defaults
        if let requestData = try? JSONEncoder().encode(request) {
            userDefaults.set(requestData, forKey: "analysisRequest")
            userDefaults.set("pending", forKey: "analysisStatus")
        }
        
        // Launch backend WhatYOE app for analysis
        try await launchBackendForAnalysis()
        
        // Wait for response
        return try await waitForAnalysisResponse(requestId: request.id)
    }
    
    private func launchBackendForAnalysis() async throws {
        let bundleIdentifier = "com.kuangming.WhatYOE"
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AnalysisError.backendNotFound
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--job-analysis"]
        
        try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        print("🚀 Launched WhatYOE backend for analysis")
    }
    
    private func waitForAnalysisResponse(requestId: String) async throws -> String {
        let maxWaitTime: TimeInterval = 120.0 // 2 minutes timeout for analysis
        let checkInterval: TimeInterval = 1.0 // Check every second
        let startTime = Date()
        
        print("🔍 Desktop: Waiting for analysis response for request: \(requestId)")
        
        while Date().timeIntervalSince(startTime) < maxWaitTime {
            // Check if response is ready
            if let responseData = userDefaults.data(forKey: "analysisResponse") {
                if let response = try? JSONDecoder().decode(AnalysisResponse.self, from: responseData) {
                    if response.requestId == requestId {
                        print("✅ Desktop: Received analysis response")
                        
                        // Clean up
                        userDefaults.removeObject(forKey: "analysisRequest")
                        userDefaults.removeObject(forKey: "analysisResponse")
                        userDefaults.removeObject(forKey: "analysisStatus")
                        
                        if let error = response.error {
                            throw AnalysisError.backendError(error)
                        }
                        
                        return response.results ?? ""
                    }
                }
            }
            
            // Wait before checking again
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
        
        throw AnalysisError.timeout
    }
    
    enum AnalysisError: LocalizedError {
        case backendNotFound
        case backendError(String)
        case timeout
        
        var errorDescription: String? {
            switch self {
            case .backendNotFound:
                return "WhatYOE backend app not found"
            case .backendError(let message):
                return "Backend error: \(message)"
            case .timeout:
                return "Analysis timeout - backend did not respond"
            }
        }
    }
}
//
//  ResumeManager.swift
//  WhatYOE
//
//  Resume storage and management functionality
//

import Foundation
import os.log
import PDFKit
import AppKit

// Import shared data structures
// (These should be defined in this file or included properly in the target)

struct ResumeItem {
    let id: String
    let name: String
    let cleanedText: String
    let dateCreated: Date
    
    init(name: String, cleanedText: String) {
        self.id = UUID().uuidString
        self.name = name
        self.cleanedText = cleanedText
        self.dateCreated = Date()
    }
    
    var isActive: Bool {
        return ResumeManager.shared.getActiveResumeId() == id
    }
}

class ResumeManager {
    static let shared = ResumeManager()
    
    private let resumesKey = "savedResumes"
    private let userDefaults: UserDefaults
    
    private init() {
        // Use shared app group container
        if let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") {
            self.userDefaults = sharedDefaults
        } else {
            // Fallback to standard UserDefaults if app group not available
            self.userDefaults = UserDefaults.standard
        }
    }
    
    func saveResume(_ resume: ResumeItem) {
        var resumes = getAllResumes()
        
        // Remove any existing resume with the same name
        resumes.removeAll { $0.name == resume.name }
        
        // Add the new resume
        resumes.append(resume)
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(resumes) {
            userDefaults.set(data, forKey: resumesKey)
        }
        
        // Also save the latest as the default for extension
        userDefaults.set(resume.cleanedText, forKey: "cleanedResumeData")
    }
    
    func getAllResumes() -> [ResumeItem] {
        guard let data = userDefaults.data(forKey: resumesKey),
              let resumes = try? JSONDecoder().decode([ResumeItem].self, from: data) else {
            return []
        }
        return resumes.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    func deleteResume(withId id: String) {
        var resumes = getAllResumes()
        resumes.removeAll { $0.id == id }
        
        if let data = try? JSONEncoder().encode(resumes) {
            userDefaults.set(data, forKey: resumesKey)
        }
    }
    
    func getResume(withId id: String) -> ResumeItem? {
        return getAllResumes().first { $0.id == id }
    }
    
    func setActiveResume(_ resume: ResumeItem) {
        userDefaults.set(resume.cleanedText, forKey: "cleanedResumeData")
        userDefaults.set(resume.id, forKey: "activeResumeId")
    }
    
    func getActiveResumeId() -> String? {
        return userDefaults.string(forKey: "activeResumeId")
    }
    
    var activeResume: ResumeItem? {
        guard let activeId = getActiveResumeId() else { return nil }
        return getResume(withId: activeId)
    }
    
    // MARK: - Resume Import and Processing
    
    func importResume(from url: URL) async throws -> Bool {
        do {
            // Extract text from PDF
            let extractedText = try extractTextFromPDF(url: url)
            
            // Clean the extracted text using AI
            let cleanedText = try await cleanResumeText(extractedText)
            
            // Create resume item
            let fileName = url.deletingPathExtension().lastPathComponent
            let resume = ResumeItem(name: fileName, cleanedText: cleanedText)
            
            // Save the resume
            saveResume(resume)
            
            // Set as active resume
            setActiveResume(resume)
            
            return true
        } catch {
            os_log(.error, "Failed to import resume: %@", error.localizedDescription)
            throw error
        }
    }
    
    func extractTextFromPDF(url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw NSError(domain: "PDFError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open PDF file"])
        }
        
        var extractedText = ""
        
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i) {
                if let pageContent = page.string {
                    extractedText += pageContent + "\n"
                }
            }
        }
        
        if extractedText.isEmpty {
            throw NSError(domain: "PDFError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No text could be extracted from PDF"])
        }
        
        return extractedText
    }
    
    func cleanResumeText(_ text: String) async throws -> String {
        do {
            // Send cleaning request to WhatYOE main app instead of processing locally
            let cleanedText = try await requestResumeCleaningFromMainApp(text)
            return cleanedText
        } catch {
            os_log(.error, "Server-based cleaning failed, falling back to basic cleaning: %@", error.localizedDescription)
            
            // Fallback to basic text cleaning if server request fails
            var cleanedText = text
            cleanedText = cleanedText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            cleanedText = cleanedText.replacingOccurrences(of: "\n\\s*\n", with: "\n\n", options: .regularExpression)
            cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedText
        }
    }
    
    private func requestResumeCleaningFromMainApp(_ text: String) async throws -> String {
        // Create cleaning request
        let request = ResumeCleaningRequest(
            id: UUID().uuidString,
            rawText: text,
            timestamp: Date()
        )
        
        // Store request in shared defaults
        if let requestData = try? JSONEncoder().encode(request) {
            userDefaults.set(requestData, forKey: "resumeCleaningRequest")
            userDefaults.set("pending", forKey: "resumeCleaningStatus")
        }
        
        // Launch main app to process the request
        try await launchMainAppForCleaning()
        
        // Wait for response
        return try await waitForCleaningResponse(requestId: request.id)
    }
    
    private func launchMainAppForCleaning() async throws {
        let bundleIdentifier = "com.kuangming.WhatYOE"
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw NSError(domain: "AppLaunch", code: 1, userInfo: [NSLocalizedDescriptionKey: "WhatYOE main app not found"])
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--resume-cleaning"]
        
        try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        os_log(.info, "Launched WhatYOE main app for resume cleaning")
    }
    
    private func waitForCleaningResponse(requestId: String) async throws -> String {
        let maxWaitTime: TimeInterval = 30.0 // 30 seconds timeout
        let checkInterval: TimeInterval = 0.5 // Check every 500ms
        let startTime = Date()
        
        print("🧹 Desktop: Waiting for cleaning response for request: \(requestId)")
        print("🧹 Desktop: Using UserDefaults suite: group.com.kuangming.WhatYOE.shared")
        
        while Date().timeIntervalSince(startTime) < maxWaitTime {
            // Check if response is ready
            if let responseData = userDefaults.data(forKey: "resumeCleaningResponse") {
                print("🧹 Desktop: Found response data, length: \(responseData.count)")
                
                if let response = try? JSONDecoder().decode(ResumeCleaningResponse.self, from: responseData) {
                    print("🧹 Desktop: Decoded response for request: \(response.requestId)")
                    print("🧹 Desktop: Expected request: \(requestId)")
                    
                    if response.requestId == requestId {
                        print("🧹 Desktop: Request ID matches! Processing response...")
                        
                        // Clean up
                        userDefaults.removeObject(forKey: "resumeCleaningRequest")
                        userDefaults.removeObject(forKey: "resumeCleaningResponse")
                        userDefaults.removeObject(forKey: "resumeCleaningStatus")
                        
                        if let error = response.error {
                            throw NSError(domain: "ResumeCleaning", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
                        }
                        
                        print("🧹 Desktop: Successfully received cleaned text, length: \(response.cleanedText?.count ?? 0)")
                        return response.cleanedText ?? ""
                    } else {
                        print("🧹 Desktop: Request ID mismatch - ignoring response")
                    }
                } else {
                    print("🧹 Desktop: Failed to decode response data")
                }
            } else {
                print("🧹 Desktop: No response data found yet...")
            }
            
            // Wait before checking again
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
        
        print("🧹 Desktop: Timeout reached - no response received")
        throw NSError(domain: "ResumeCleaning", code: 3, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for response from main app"])
    }
    
    // MARK: - Utility Methods
    
    func loadResumes() {
        // This method is called to refresh the resume list
        // The actual loading is done in getAllResumes()
        // This method exists for compatibility with existing code
    }
    
    func refreshResumeList() {
        // Trigger a refresh of the resume list
        // This could notify observers or reload data
    }
}

extension ResumeItem: Codable {}

// MARK: - Communication Data Structures (Frontend to Backend)
struct ResumeCleaningRequest: Codable {
    let id: String
    let rawText: String
    let timestamp: Date
}

struct ResumeCleaningResponse: Codable {
    let requestId: String
    let cleanedText: String?
    let error: String?
    let timestamp: Date
}

struct AnalysisRequest: Codable {
    let id: String
    let resumeText: String
    let jobDescription: String
    let timestamp: Date
}

struct AnalysisResponse: Codable {
    let requestId: String
    let results: String?
    let error: String?
    let timestamp: Date
}
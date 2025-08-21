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

struct ResumeItem: Identifiable {
    let id: String
    let name: String
    let dateCreated: Date
    
    // Simplified initializer - no more cleanedText redundancy
    init(id: String, name: String, dateCreated: Date) {
        self.id = id
        self.name = name
        self.dateCreated = dateCreated
    }
    
    // Legacy initializer for backward compatibility (generates new ID)
    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
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
        
        // Note: cleanedResumeData removed - now generated on-demand from structured data
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
    
    func updateResume(_ updatedResume: ResumeItem) {
        var resumes = getAllResumes()
        
        // Find and replace the resume with the same ID
        if let index = resumes.firstIndex(where: { $0.id == updatedResume.id }) {
            resumes[index] = updatedResume
            
            // Save to UserDefaults
            if let data = try? JSONEncoder().encode(resumes) {
                userDefaults.set(data, forKey: resumesKey)
            }
            
            // Update active resume data if this is the active resume
            if getActiveResumeId() == updatedResume.id {
                // Note: cleanedResumeData removed - now generated on-demand from structured data
            }
        }
    }
    
    func getResume(withId id: String) -> ResumeItem? {
        return getAllResumes().first { $0.id == id }
    }
    
    func setActiveResume(_ resume: ResumeItem) {
        // Note: cleanedResumeData removed - now generated on-demand from structured data
        userDefaults.set(resume.id, forKey: "activeResumeId")
    }
    
    func getActiveResumeId() -> String? {
        return userDefaults.string(forKey: "activeResumeId")
    }
    
    // MARK: - Frontend: Request formatted text from backend
    
    func getFormattedResumeText(for resumeId: String) async -> String? {
        // Frontend should request formatted text from backend WhatYOE app
        return await requestFormattedTextFromBackend(resumeId: resumeId)
    }
    
    func getActiveFormattedResumeText() async -> String? {
        guard let activeResumeId = getActiveResumeId() else {
            print("⚠️ No active resume ID found")
            return nil
        }
        return await getFormattedResumeText(for: activeResumeId)
    }
    
    private func requestFormattedTextFromBackend(resumeId: String) async -> String? {
        // Create request for formatted text
        let request = ResumeTextRequest(resumeId: resumeId, timestamp: Date())
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        guard let requestData = try? JSONEncoder().encode(request) else {
            print("❌ Failed to encode resume text request")
            return nil
        }
        
        // Store request for backend to process
        sharedDefaults.set(requestData, forKey: "resumeTextRequest")
        sharedDefaults.set("pending", forKey: "resumeTextRequestStatus")
        
        // Launch backend to process
        do {
            try await launchBackendForTextRequest()
            return try await waitForTextResponse(resumeId: resumeId)
        } catch {
            print("❌ Failed to get formatted text from backend: \(error)")
            return nil
        }
    }
    
    private func launchBackendForTextRequest() async throws {
        let bundleIdentifier = "com.kuangming.WhatYOE"
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
            try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second for launch
        } else {
            throw NSError(domain: "LaunchError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot find backend app"])
        }
    }
    
    private func waitForTextResponse(resumeId: String) async throws -> String {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        // Wait for response with timeout
        for _ in 0..<30 { // 15 second timeout
            if let status = sharedDefaults.string(forKey: "resumeTextRequestStatus") {
                if status == "completed", let responseData = sharedDefaults.data(forKey: "resumeTextResponse") {
                    if let response = try? JSONDecoder().decode(ResumeTextResponse.self, from: responseData),
                       response.resumeId == resumeId {
                        
                        // Cleanup
                        sharedDefaults.removeObject(forKey: "resumeTextRequest")
                        sharedDefaults.removeObject(forKey: "resumeTextResponse")
                        sharedDefaults.removeObject(forKey: "resumeTextRequestStatus")
                        
                        if let error = response.error {
                            throw NSError(domain: "BackendError", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
                        }
                        
                        return response.formattedText ?? "Resume text unavailable"
                    }
                } else if status == "error" {
                    throw NSError(domain: "BackendError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Backend processing failed"])
                }
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds
        }
        
        throw NSError(domain: "TimeoutError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Backend response timeout"])
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
            let (cleanedText, requestId) = try await cleanResumeText(extractedText)
            
            // Create resume item using the cleaning request ID to link with structured data
            let fileName = url.deletingPathExtension().lastPathComponent
            let resume = ResumeItem(id: requestId, name: fileName, dateCreated: Date())
            
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
    
    func cleanResumeText(_ text: String) async throws -> (cleanedText: String, requestId: String) {
        do {
            // Send cleaning request to WhatYOE main app instead of processing locally
            return try await requestResumeCleaningFromMainApp(text)
        } catch {
            os_log(.error, "Server-based cleaning failed, falling back to basic cleaning: %@", error.localizedDescription)
            
            // Fallback to basic text cleaning if server request fails
            var cleanedText = text
            cleanedText = cleanedText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            cleanedText = cleanedText.replacingOccurrences(of: "\n\\s*\n", with: "\n\n", options: .regularExpression)
            cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            // Generate a fallback ID since we don't have a real request ID
            return (cleanedText: cleanedText, requestId: UUID().uuidString)
        }
    }
    
    private func requestResumeCleaningFromMainApp(_ text: String) async throws -> (cleanedText: String, requestId: String) {
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
        let cleanedText = try await waitForCleaningResponse(requestId: request.id)
        return (cleanedText: cleanedText, requestId: request.id)
    }
    
    private func launchMainAppForCleaning() async throws {
        let bundleIdentifier = "com.kuangming.WhatYOE"
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw NSError(domain: "AppLaunch", code: 1, userInfo: [NSLocalizedDescriptionKey: "WhatYOE main app not found"])
        }
        
        let config = NSWorkspace.OpenConfiguration()
        
        try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        os_log(.info, "Launched WhatYOE main app - monitoring will pick up the request")
    }
    
    private func waitForCleaningResponse(requestId: String) async throws -> String {
        let maxWaitTime: TimeInterval = 60.0 // 60 seconds timeout
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

struct ResumeTextRequest: Codable {
    let resumeId: String
    let timestamp: Date
}

struct ResumeTextResponse: Codable {
    let resumeId: String
    let formattedText: String?
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
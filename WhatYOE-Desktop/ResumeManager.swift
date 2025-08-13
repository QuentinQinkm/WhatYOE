//
//  ResumeManager.swift
//  WhatYOE
//
//  Resume storage and management functionality
//

import Foundation
import os.log
import PDFKit

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
    
    private func extractTextFromPDF(url: URL) throws -> String {
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
    
    private func cleanResumeText(_ text: String) async throws -> String {
        // For now, just do basic text cleaning
        var cleanedText = text
        
        // Remove extra whitespace and normalize line breaks
        cleanedText = cleanedText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: "\n\\s*\n", with: "\n\n", options: .regularExpression)
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // TODO: Implement AI-based cleaning using PromptTemplates.resumeCleaningPrompt
        // This would require LanguageModelSession integration
        
        return cleanedText
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
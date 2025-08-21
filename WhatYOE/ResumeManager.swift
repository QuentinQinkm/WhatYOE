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
        
        // TODO: Implement AI-based cleaning using AIPromptLibrary.resumeCleaningPrompt
        // This would require LanguageModelSession integration
        
        return cleanedText
    }
    
    // MARK: - YOE Parsing for 5-variable System
    
    func parseActualYOE(from resumeText: String) async throws -> ResumeParsingResult {
        // Implementation requirements from development guide:
        // 1. Extract work experience sections
        // 2. Calculate total relevant years (avoid double-counting overlaps)
        // 3. Include project experience using standard conversion:
        //    - Major projects (6+ months): count as work experience
        //    - Moderate projects (2-6 months): count as 0.5x
        //    - Minor projects (<2 months): count as 0.1x
        // 4. Cap at 8.0 years maximum
        // 5. Return confidence score for validation
        
        do {
            let result = try await CandidateEvaluationAI.performResumeParsingForYOE(resumeText: resumeText)
            return result
        } catch {
            os_log(.error, "Failed to parse YOE from resume: %@", error.localizedDescription)
            // Return fallback result
            return ResumeParsingResult(
                actual_yoe: 0.0,
                confidence: 0.0,
                calculation_notes: "Failed to parse: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Required YOE Parsing
    
    func parseRequiredYOE(from jobDescription: String) -> Double {
        // Extract phrases like:
        // "3+ years of experience"
        // "minimum 5 years"
        // "2-4 years experience required"
        // Return median of range, cap at 8.0
        
        let patterns = [
            "[Mm]in(?:imum)?\\s*([0-9]+(?:\\.[0-9]+)?)\\s*\\+?\\s*[Yy]ears",
            "([0-9]+(?:\\.[0-9]+)?)\\s*\\+?\\s*[Yy]ears",
            "at least\\s*([0-9]+(?:\\.[0-9]+)?)\\s*[Yy]ears",
            "([0-9]+(?:\\.[0-9]+)?)\\s*[-–]\\s*([0-9]+(?:\\.[0-9]+)?)\\s*[Yy]ears"
        ]
        
        var extractedYears: [Double] = []
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(jobDescription.startIndex..<jobDescription.endIndex, in: jobDescription)
                let matches = regex.matches(in: jobDescription, options: [], range: range)
                
                for match in matches {
                    if match.numberOfRanges >= 2 {
                        // Single number or start of range
                        let firstRange = match.range(at: 1)
                        if let r1 = Range(firstRange, in: jobDescription) {
                            if let year1 = Double(String(jobDescription[r1])) {
                                if match.numberOfRanges >= 3 {
                                    // Range format (e.g., "2-4 years")
                                    let secondRange = match.range(at: 2)
                                    if let r2 = Range(secondRange, in: jobDescription) {
                                        if let year2 = Double(String(jobDescription[r2])) {
                                            // Take median of range
                                            extractedYears.append((year1 + year2) / 2.0)
                                            continue
                                        }
                                    }
                                }
                                extractedYears.append(year1)
                            }
                        }
                    }
                }
            }
        }
        
        // Return the most common or highest reasonable value, capped at 8.0
        if extractedYears.isEmpty {
            return 0.0
        }
        
        let cappedYears = extractedYears.map { min($0, 8.0) }
        return cappedYears.max() ?? 0.0
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
import SafariServices
import os.log
import FoundationModels
import AppKit

struct ResumeItem: Codable {
    let id: String
    let name: String
    let cleanedText: String
    let dateCreated: Date
}

// MARK: - Safari Analysis Communication
struct SafariAnalysisRequest: Codable {
    let id: String
    let resumeText: String
    let jobDescription: String
    let jobTitle: String?      // Job title extracted from page
    let company: String?       // Company name extracted from page
    let pageUrl: String?       // URL of the job posting
    let timestamp: Date
}

struct SafariAnalysisResponse: Codable {
    let requestId: String
    let results: String?
    let error: String?
    let timestamp: Date
    let scores: AnalysisScores?
}

struct AnalysisScores: Codable {
    let fitScores: [Double]
    let gapScores: [Double]
    let finalScore: Double
}

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    
    // MARK: - Properties  
    private let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
    
    // MARK: - Logging
    private func log(_ message: String) {
        print("🔍 \(message)")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)"
        
        var logs = sharedDefaults.stringArray(forKey: "debugLogs") ?? []
        logs.append(logEntry)
        if logs.count > 50 { logs.removeFirst(logs.count - 50) }
        sharedDefaults.set(logs, forKey: "debugLogs")
    }
    
    // MARK: - Main Handler
    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems[0] as? NSExtensionItem
        let message = item?.userInfo?[SFExtensionMessageKey]
        
        log("📨 Request received: \(String(describing: message))")
        
        // Check for page analysis messages (like the old working version)
        if let messageDict = message as? [String: Any],
           let messageContent = messageDict["message"] as? String {
            
            
            // Handle single request 4-cycle analysis (new optimized approach)
            if messageContent == "fourCycleAnalysis" {
                if let data = messageDict["data"] as? [String: Any] {
                    let characterCount = data["characterCount"] as? Int ?? 0
                    let wordCount = data["wordCount"] as? Int ?? 0
                    let pageText = data["pageText"] as? String ?? ""
                    
                    log("🚀 FOUR_CYCLE_ANALYSIS: Starting single request 4-cycle analysis - \(wordCount) words, \(characterCount) characters")
                    
                    analyzeFourCycleJobDescription(pageText: pageText, context: context)
                    return
                }
            }
            
            // Handle sequential phase analysis
            if messageContent == "phase1Analysis" {
                if let data = messageDict["data"] as? [String: Any] {
                    let pageText = data["pageText"] as? String ?? ""
                    log("🚀 PHASE1: Starting YOE Analysis")
                    setProgress(stage: "round_1", message: "Phase 1: YOE Analysis")
                    analyzeJobDescriptionPhase1(pageText: pageText, context: context)
                    return
                }
            }
            
            if messageContent == "phase2Analysis" {
                if let data = messageDict["data"] as? [String: Any] {
                    let pageText = data["pageText"] as? String ?? ""
                    log("🚀 PHASE2: Starting Education Analysis")
                    setProgress(stage: "round_2", message: "Phase 2: Education Analysis")
                    analyzeJobDescriptionPhase2(pageText: pageText, context: context)
                    return
                }
            }
            
            if messageContent == "phase3Analysis" {
                if let data = messageDict["data"] as? [String: Any] {
                    let pageText = data["pageText"] as? String ?? ""
                    log("🚀 PHASE3: Starting Skills Analysis")
                    setProgress(stage: "round_3", message: "Phase 3: Skills Analysis")
                    analyzeJobDescriptionPhase3(pageText: pageText, context: context)
                    return
                }
            }
            
            if messageContent == "phase4Analysis" {
                if let data = messageDict["data"] as? [String: Any] {
                    let pageText = data["pageText"] as? String ?? ""
                    log("🚀 PHASE4: Starting Experience Analysis")
                    setProgress(stage: "round_4", message: "Phase 4: Experience Analysis")
                    analyzeJobDescriptionPhase4(pageText: pageText, context: context)
                    return
                }
            }
            
            // Handle resume management (needed for popup functionality)
            if messageContent == "getAvailableResumes" {
                let resumes = getAvailableResumes()
                sendResponse(["status": "success", "resumes": resumes], context: context)
                return
            }
            
            // Handle job metadata storage from extension
            if messageContent == "storeJobMetadata" {
                if let data = messageDict["data"] as? [String: Any] {
                    let jobTitle = data["jobTitle"] as? String ?? "Unknown Position"
                    let company = data["company"] as? String ?? "Unknown Company"
                    let linkedinJobId = data["linkedinJobId"] as? String ?? "unknown"
                    let pageUrl = data["pageUrl"] as? String ?? "unknown"
                    
                    // Store in shared defaults for native app access
                    sharedDefaults.set(jobTitle, forKey: "currentJobTitle")
                    sharedDefaults.set(company, forKey: "currentCompany")
                    sharedDefaults.set(linkedinJobId, forKey: "currentLinkedInJobId")
                    sharedDefaults.set(pageUrl, forKey: "currentPageUrl")
                    
                    log("💾 Job metadata stored - Title: '\(jobTitle)', Company: '\(company)', LinkedIn Job ID: '\(linkedinJobId)'")
                    sendResponse(["status": "success", "message": "Job metadata stored"], context: context)
                } else {
                    sendResponse(["status": "error", "message": "Invalid metadata format"], context: context)
                }
                return
            }
            
            // Handle score retrieval for background.js logging
            if messageContent == "getLastAnalysisScores" {
                if let storedScores = sharedDefaults.object(forKey: "lastAnalysisScores") as? [String: Any] {
                    sendResponse(["status": "success", "scores": storedScores], context: context)
                } else {
                    sendResponse(["status": "error", "message": "No scores available"], context: context)
                }
                return
            }
            
            // Handle stop analysis command
            if messageContent == "stopAnalysis" {
                // Send stop command to background service
                sharedDefaults.set("stop", forKey: "stopAnalysisCommand")
                
                // Also set local flags for immediate response
                sharedDefaults.set("stopped", forKey: "safariAnalysisStatus")
                sharedDefaults.set("stopped", forKey: "analysisStatus")
                
                // Clear any pending requests
                sharedDefaults.removeObject(forKey: "safariAnalysisRequest")
                sharedDefaults.removeObject(forKey: "analysisRequest")
                
                log("🛑 Analysis stopped - background processing will be halted")
                sendResponse(["status": "success", "message": "Analysis stopped"], context: context)
                return
            }
            
            // Handle resume analysis command
            if messageContent == "resumeAnalysis" {
                // Send resume command to background service
                sharedDefaults.set("resume", forKey: "resumeAnalysisCommand")
                
                // Also set local flags for immediate response
                sharedDefaults.set("pending", forKey: "safariAnalysisStatus")
                sharedDefaults.set("pending", forKey: "analysisStatus")
                
                log("▶️ Analysis resumed - background processing will continue")
                sendResponse(["status": "success", "message": "Analysis resumed"], context: context)
                return
            }
            
            if messageContent == "setActiveResume" {
                if let data = messageDict["data"] as? [String: Any],
                   let resumeId = data["resumeId"] as? String {
                    let success = setActiveResume(id: resumeId)
                    sendResponse(["status": success ? "success" : "error"], context: context)
                } else {
                    sendResponse(["status": "error", "message": "Missing resumeId"], context: context)
                }
                return
            }
            
            if messageContent == "launchResumeApp" {
                let bundleIdentifier = "com.kuangming.WhatYOE"
                
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                    let config = NSWorkspace.OpenConfiguration()
                    config.arguments = ["--open-resume-tab"]
                    
                    NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                        let response = error == nil ? 
                            ["status": "success"] : 
                            ["status": "error", "message": "Failed to launch: \(error?.localizedDescription ?? "Unknown error")"]
                        self.sendResponse(response, context: context)
                    }
                } else {
                    sendResponse(["status": "error", "message": "App not found"], context: context)
                }
                return
            }
        }

        log("📤 Sending default response back to extension")
        let response = NSExtensionItem()
        response.userInfo = [ SFExtensionMessageKey: [ "Response to": message ] ]
        
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
    
    // MARK: - Request Handlers
    private func handleProgressRequest(context: NSExtensionContext) {
        log("🔍 Progress requested")
        
        if let progressData = sharedDefaults.dictionary(forKey: "analysisProgress") {
            let stage = progressData["stage"] as? String ?? ""
            let message = progressData["message"] as? String ?? ""
            log("📤 Sending progress: \(stage) - \(message)")
            sendJSONResponse(data: ["type": "progress_update", "stage": stage, "message": message], context: context)
        } else {
            log("❌ No progress data found")
            sendJSONResponse(data: ["type": "no_progress"], context: context)
        }
    }
    
    private func handleDebugLogsRequest(context: NSExtensionContext) {
        let logs = sharedDefaults.stringArray(forKey: "debugLogs") ?? []
        sendJSONResponse(data: ["type": "debug_logs", "logs": logs], context: context)
    }
    
    private func handleAvailableResumesRequest(context: NSExtensionContext) {
        let resumes = getAvailableResumes()
        sendResponse(["status": "success", "resumes": resumes], context: context)
    }
    
    private func handleSetActiveResumeRequest(message: [String: Any], context: NSExtensionContext) {
        guard let data = message["data"] as? [String: Any],
              let resumeId = data["resumeId"] as? String else {
            sendResponse(["status": "error", "message": "Missing resumeId"], context: context)
            return
        }
        
        let success = setActiveResume(id: resumeId)
        sendResponse(["status": success ? "success" : "error"], context: context)
    }
    
    private func handleLaunchResumeAppRequest(context: NSExtensionContext) {
        let bundleIdentifier = "com.kuangming.WhatYOE"
        
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = ["--open-resume-tab"]
            
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                let response = error == nil ? 
                    ["status": "success"] : 
                    ["status": "error", "message": "Failed to launch: \(error?.localizedDescription ?? "Unknown error")"]
                self.sendResponse(response, context: context)
            }
        } else {
            sendResponse(["status": "error", "message": "App not found"], context: context)
        }
    }
    
    
    // MARK: - Analysis
    
    // New optimized single request 4-cycle analysis
    private func analyzeFourCycleJobDescription(pageText: String, context: NSExtensionContext) {
        Task {
            do {
                let resumeData = getCleanedResumeData()
                
                log("🔄 Starting single request 4-cycle analysis via background server...")
                
                // Clear old scores to prevent contamination from previous job analysis
                sharedDefaults.removeObject(forKey: "lastAnalysisScores")
                sharedDefaults.removeObject(forKey: "safariAnalysisResponse")
                log("🧹 Cleared old scores and response data to prevent contamination")
                
                // Extract job metadata from shared defaults (set by JavaScript)
                let jobTitle = sharedDefaults.string(forKey: "currentJobTitle") ?? extractJobTitleFromPageText(pageText)
                let company = sharedDefaults.string(forKey: "currentCompany") ?? extractCompanyFromPageText(pageText)
                let pageUrl = sharedDefaults.string(forKey: "currentPageUrl") ?? "unknown"
                
                log("📋 Job Metadata - Title: '\(jobTitle)', Company: '\(company)'")
                log("🔍 Metadata source - Title from JS: \(sharedDefaults.string(forKey: "currentJobTitle") != nil ? "YES" : "NO"), Company from JS: \(sharedDefaults.string(forKey: "currentCompany") != nil ? "YES" : "NO")")
                
                // Send analysis request to background server with job metadata
                let results = try await requestFourCycleAnalysisFromBackgroundServer(
                    resumeText: resumeData,
                    jobDescription: pageText,
                    jobTitle: jobTitle,
                    company: company,
                    pageUrl: pageUrl
                )
                
                // Get the response with scores calculated by background service
                let (rawScore, processedScore) = getScoresFromBackgroundResponse()
                
                log("✅ 4-Cycle analysis complete: \(processedScore)")
                sendFinalResponseWithScores(score: processedScore, rawScore: rawScore, context: context)
                
            } catch {
                log("❌ 4-Cycle analysis failed: \(error)")
                sendFinalResponse(score: "0.0", rawScore: "0", context: context)
            }
        }
    }
    
    
    // MARK: - Phase Analysis Functions
    private func analyzeJobDescriptionPhase1(pageText: String, context: NSExtensionContext) {
        Task {
            do {
                let resumeData = getCleanedResumeData()
                let analysisMethod = getAnalysisMethodFromSharedDefaults()
                
                log("🔄 Phase 1: Starting YOE Analysis using \(analysisMethod) method...")
                
                // Clear old scores to prevent contamination from previous job analysis
                sharedDefaults.removeObject(forKey: "lastAnalysisScores")
                sharedDefaults.removeObject(forKey: "safariAnalysisResponse")
                log("🧹 Cleared old scores and response data to prevent contamination")
                
                // Send request to WhatYOE - let it handle all prompt logic
                let results = try await requestAnalysisFromWhatYOE(
                    resumeText: resumeData,
                    jobDescription: pageText,
                    phase: "phase1"
                )
                
                // Extract YOE score from results (0-3 scale)
                let score = extractPhaseScore(from: results, phase: "YOE")
                
                log("✅ Phase 1 complete: \(score)")
                setProgress(stage: "round_1", message: "Phase 1 Complete: \(score)")
                
                // Send response for Phase 1
                sendPhaseResponse(phase: "phase1", score: score, rawScore: score, context: context)
                
            } catch {
                log("❌ Phase 1 failed: \(error)")
                sendPhaseResponse(phase: "phase1", score: "0", rawScore: "0", context: context)
            }
        }
    }
    
    private func analyzeJobDescriptionPhase2(pageText: String, context: NSExtensionContext) {
        Task {
            do {
                let resumeData = getCleanedResumeData()
                let analysisMethod = getAnalysisMethodFromSharedDefaults()
                
                log("🔄 Phase 2: Starting Education Analysis using \(analysisMethod) method...")
                
                // Clear old scores to prevent contamination from previous job analysis
                sharedDefaults.removeObject(forKey: "lastAnalysisScores")
                sharedDefaults.removeObject(forKey: "safariAnalysisResponse")
                log("🧹 Cleared old scores and response data to prevent contamination")
                
                // Send request to WhatYOE - let it handle all prompt logic
                let results = try await requestAnalysisFromWhatYOE(
                    resumeText: resumeData,
                    jobDescription: pageText,
                    phase: "phase2"
                )
                
                // Extract Education score from results (0-3 scale)
                let score = extractPhaseScore(from: results, phase: "Education")
                
                log("✅ Phase 2 complete: \(score)")
                setProgress(stage: "round_2", message: "Phase 2 Complete: \(score)")
                
                // Send response for Phase 2
                sendPhaseResponse(phase: "phase2", score: score, rawScore: score, context: context)
                
            } catch {
                log("❌ Phase 2 failed: \(error)")
                sendPhaseResponse(phase: "phase2", score: "0", rawScore: "0", context: context)
            }
        }
    }
    
    private func analyzeJobDescriptionPhase3(pageText: String, context: NSExtensionContext) {
        Task {
            do {
                let resumeData = getCleanedResumeData()
                let analysisMethod = getAnalysisMethodFromSharedDefaults()
                
                log("🔄 Phase 3: Starting Skills Analysis using \(analysisMethod) method...")
                
                // Clear old scores to prevent contamination from previous job analysis
                sharedDefaults.removeObject(forKey: "lastAnalysisScores")
                sharedDefaults.removeObject(forKey: "safariAnalysisResponse")
                log("🧹 Cleared old scores and response data to prevent contamination")
                
                // Send request to WhatYOE - let it handle all prompt logic
                let results = try await requestAnalysisFromWhatYOE(
                    resumeText: resumeData,
                    jobDescription: pageText,
                    phase: "phase3"
                )
                
                // Extract Skills score from results (0-3 scale)
                let score = extractPhaseScore(from: results, phase: "Skills")
                
                log("✅ Phase 3 complete: \(score)")
                setProgress(stage: "round_3", message: "Phase 3 Complete: \(score)")
                
                // Send response for Phase 3
                sendPhaseResponse(phase: "phase3", score: score, rawScore: score, context: context)
                
            } catch {
                log("❌ Phase 3 failed: \(error)")
                sendPhaseResponse(phase: "phase3", score: "0", rawScore: "0", context: context)
            }
        }
    }
    
    private func analyzeJobDescriptionPhase4(pageText: String, context: NSExtensionContext) {
        Task {
            do {
                let resumeData = getCleanedResumeData()
                let analysisMethod = getAnalysisMethodFromSharedDefaults()
                
                log("🔄 Phase 4: Starting Experience Analysis using \(analysisMethod) method...")
                
                // Clear old scores to prevent contamination from previous job analysis
                sharedDefaults.removeObject(forKey: "lastAnalysisScores")
                sharedDefaults.removeObject(forKey: "safariAnalysisResponse")
                log("🧹 Cleared old scores and response data to prevent contamination")
                
                // Send request to WhatYOE - let it handle all prompt logic
                let results = try await requestAnalysisFromWhatYOE(
                    resumeText: resumeData,
                    jobDescription: pageText,
                    phase: "phase4"
                )
                
                // Extract Experience score from results (0-3 scale)
                let score = extractPhaseScore(from: results, phase: "Experience")
                
                log("✅ Phase 4 complete: \(score)")
                setProgress(stage: "round_4", message: "Phase 4 Complete: \(score)")
                
                // Send response for Phase 4
                sendPhaseResponse(phase: "phase4", score: score, rawScore: score, context: context)
                
            } catch {
                log("❌ Phase 4 failed: \(error)")
                sendPhaseResponse(phase: "phase4", score: "0", rawScore: "0", context: context)
            }
        }
    }
    
    
    private func requestFourCycleAnalysisFromBackgroundServer(resumeText: String, jobDescription: String, jobTitle: String, company: String, pageUrl: String) async throws -> String {
        // Create analysis request with job metadata
        let request = SafariAnalysisRequest(
            id: UUID().uuidString,
            resumeText: resumeText,
            jobDescription: jobDescription,
            jobTitle: jobTitle,
            company: company,
            pageUrl: pageUrl,
            timestamp: Date()
        )
        
        // Clear old scores and response data to prevent contamination
        sharedDefaults.removeObject(forKey: "lastAnalysisScores")
        sharedDefaults.removeObject(forKey: "safariAnalysisResponse")
        log("🧹 Cleared old scores and response data before starting new analysis")
        
        // Store request in shared defaults with fourRun method specified
        if let requestData = try? JSONEncoder().encode(request) {
            sharedDefaults.set(requestData, forKey: "safariAnalysisRequest")
            sharedDefaults.set("fourRun", forKey: "analysisMethod") // Ensure 4-cycle method
            sharedDefaults.set("pending", forKey: "safariAnalysisStatus")
        }
        
        // Wait for response with timeout
        return try await waitForAnalysisResponse(requestId: request.id)
    }
    
    // MARK: - Analysis Method Handling
    
    private func getAnalysisMethodFromSharedDefaults() -> String {
        return sharedDefaults.string(forKey: "analysisMethod") ?? "fourRun"
    }
    
    private func requestAnalysisFromWhatYOE(resumeText: String, jobDescription: String, phase: String) async throws -> String {
        // Extract job metadata for phase analysis too
        let jobTitle = sharedDefaults.string(forKey: "currentJobTitle") ?? extractJobTitleFromPageText(jobDescription)
        let company = sharedDefaults.string(forKey: "currentCompany") ?? extractCompanyFromPageText(jobDescription)
        let pageUrl = sharedDefaults.string(forKey: "currentPageUrl") ?? "unknown"
        
        // Create analysis request with job metadata
        let request = SafariAnalysisRequest(
            id: UUID().uuidString,
            resumeText: resumeText,
            jobDescription: jobDescription,
            jobTitle: jobTitle,
            company: company,
            pageUrl: pageUrl,
            timestamp: Date()
        )
        
        // Clear old scores and response data to prevent contamination
        sharedDefaults.removeObject(forKey: "lastAnalysisScores")
        sharedDefaults.removeObject(forKey: "safariAnalysisResponse")
        log("🧹 Cleared old scores and response data before starting new phase analysis")
        
        // Store request in shared defaults
        if let requestData = try? JSONEncoder().encode(request) {
            sharedDefaults.set(requestData, forKey: "safariAnalysisRequest")
            sharedDefaults.set("pending", forKey: "safariAnalysisStatus")
        }
        
        // Wait for response with timeout
        return try await waitForAnalysisResponse(requestId: request.id)
    }
    
    private func extractPhaseScore(from response: String, phase: String) -> String {
        // Look for Fit Score in the response (0-3 scale)
        if let match = response.range(of: #"Fit Score:\s*(\d+)"#, options: .regularExpression),
           let scoreText = response[match].split(separator: ":").last,
           let score = Int(scoreText.trimmingCharacters(in: .whitespaces)) {
            return String(score)
        }
        
        // Fallback: look for any number 0-3 in the response
        if let match = response.range(of: #"\b([0-3])\b"#, options: .regularExpression),
           let scoreText = response[match].split(separator: " ").last,
           let score = Int(scoreText) {
            return String(score)
        }
        
        log("⚠️ Could not extract score for \(phase), defaulting to 0")
        return "0"
    }
    
    // MARK: - Analysis Method Handling
    
    private func waitForAnalysisResponse(requestId: String) async throws -> String {
        let maxWaitTime: TimeInterval = 60.0 // 60 seconds timeout
        let checkInterval: TimeInterval = 0.5 // Check every 500ms
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxWaitTime {
            // Check if response is ready
            if let responseData = sharedDefaults.data(forKey: "safariAnalysisResponse"),
               let response = try? JSONDecoder().decode(SafariAnalysisResponse.self, from: responseData),
               response.requestId == requestId {
                
                // Clean up request and status ONLY (keep response for score extraction)
                sharedDefaults.removeObject(forKey: "safariAnalysisRequest")
                sharedDefaults.removeObject(forKey: "safariAnalysisStatus")
                
                if let error = response.error {
                    throw NSError(domain: "SafariAnalysis", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
                }
                
                return response.results ?? ""
            }
            
            // Wait before checking again
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
        
        throw NSError(domain: "SafariAnalysis", code: 3, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for analysis response"])
    }
    
    // MARK: - Resume Management
    private func getCleanedResumeData() -> String {
        guard let activeResumeId = sharedDefaults.string(forKey: "activeResumeId"),
              let resumesData = sharedDefaults.data(forKey: "savedResumes"),
              let resumes = try? JSONDecoder().decode([ResumeItem].self, from: resumesData),
              let activeResume = resumes.first(where: { $0.id == activeResumeId }) else {
            return "No resume data available. Please import resume first."
        }
        
        return activeResume.cleanedText
    }
    
    private func getAvailableResumes() -> [[String: String]] {
        guard let resumesData = sharedDefaults.data(forKey: "savedResumes"),
              let resumes = try? JSONDecoder().decode([ResumeItem].self, from: resumesData) else {
            return []
        }
        
        return resumes.map { resume in
            [
                "id": resume.id,
                "name": resume.name,
                "dateCreated": ISO8601DateFormatter().string(from: resume.dateCreated)
            ]
        }
    }
    
    private func setActiveResume(id: String) -> Bool {
        guard let resumesData = sharedDefaults.data(forKey: "savedResumes"),
              let resumes = try? JSONDecoder().decode([ResumeItem].self, from: resumesData),
              let selectedResume = resumes.first(where: { $0.id == id }) else {
            return false
        }
        
        sharedDefaults.set(id, forKey: "activeResumeId")
        sharedDefaults.set(selectedResume.cleanedText, forKey: "cleanedResumeData")
        return true
    }
    
    // MARK: - Job Information Extraction
    
    private func extractJobTitleFromPageText(_ pageText: String) -> String {
        // More sophisticated job title extraction
        let lines = pageText.components(separatedBy: .newlines)
        
        // First, try to find lines that look like job titles
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip very long lines (likely descriptions) or very short lines
            if trimmedLine.count > 80 || trimmedLine.count < 3 {
                continue
            }
            
            // Look for job title patterns with better context
            let jobTitlePatterns = [
                "Engineer", "Developer", "Manager", "Analyst", "Specialist", "Director", 
                "Senior", "Lead", "Principal", "Staff", "Consultant", "Architect",
                "Intern", "Associate", "Coordinator", "Representative", "Designer",
                "Scientist", "Researcher", "Advisor", "Officer", "Executive"
            ]
            
            // Check if line contains job title patterns and doesn't look like a description
            if jobTitlePatterns.contains(where: { trimmedLine.contains($0) }) &&
               !trimmedLine.contains("experience") &&
               !trimmedLine.contains("requirements") &&
               !trimmedLine.contains("responsibilities") {
                return trimmedLine
            }
        }
        
        // If no clear pattern found, try to extract from the first few lines
        let firstLines = Array(lines.prefix(10))
        for line in firstLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.count > 5 && trimmedLine.count < 60 {
                // Check if it looks like a job title (not a description)
                if !trimmedLine.contains(".") && !trimmedLine.contains("experience") {
                    return trimmedLine
                }
            }
        }
        
        return "Software Engineer" // Final fallback
    }
    
    private func extractCompanyFromPageText(_ pageText: String) -> String {
        // More sophisticated company extraction
        let lines = pageText.components(separatedBy: .newlines)
        
        // First, try to find lines with company indicators
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for lines with company indicators
            if trimmedLine.contains("Inc.") || trimmedLine.contains("LLC") || 
               trimmedLine.contains("Corp") || trimmedLine.contains("Ltd") ||
               trimmedLine.contains("Company") || trimmedLine.contains("Corporation") ||
               trimmedLine.contains("Limited") || trimmedLine.contains("Group") {
                return trimmedLine
            }
        }
        
        // If no company indicators found, try to extract from the first few lines
        let firstLines = Array(lines.prefix(15))
        for line in firstLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for lines that might be company names (not job descriptions)
            if trimmedLine.count > 2 && trimmedLine.count < 50 &&
               !trimmedLine.contains("experience") &&
               !trimmedLine.contains("requirements") &&
               !trimmedLine.contains("responsibilities") &&
               !trimmedLine.contains("skills") &&
               !trimmedLine.contains("qualifications") {
                
                // Check if it looks like a company name (capitalized, no periods in middle)
                let words = trimmedLine.components(separatedBy: " ")
                if words.count <= 4 && words.allSatisfy({ $0.first?.isUppercase == true }) {
                    return trimmedLine
                }
            }
        }
        
        return "Tech Company" // Final fallback
    }
    
    // MARK: - Score Processing
    
    private func getScoresFromBackgroundResponse() -> (String, String) {
        // Get scores from the background service response
        if let responseData = sharedDefaults.data(forKey: "safariAnalysisResponse"),
           let response = try? JSONDecoder().decode(SafariAnalysisResponse.self, from: responseData),
           let scores = response.scores {
            
            let finalScore = scores.finalScore
            let processedScoreString = String(format: "%.1f", finalScore)
            let rawEstimate = String(Int(finalScore.rounded()))
            
            // Store scores for background.js logging
            let allScores: [String: Any] = [
                "fitScores": scores.fitScores,
                "gapScores": scores.gapScores,
                "finalScore": finalScore
            ]
            sharedDefaults.set(allScores, forKey: "lastAnalysisScores")
            
            log("📊 Using scores from background service - Final: \(finalScore)")
            return (rawEstimate, processedScoreString)
        }
        
        log("⚠️ No scores available from background service, using fallback")
        return ("0", "0.0")
    }
    
    
    // MARK: - Progress Management
    private func setProgress(stage: String, message: String) {
        log("💾 Progress: \(stage) - \(message)")
        
        let progressData: [String: Any] = [
            "stage": stage,
            "message": message,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sharedDefaults.set(progressData, forKey: "analysisProgress")
    }
    
    private func clearProgress() {
        sharedDefaults.removeObject(forKey: "analysisProgress")
    }
    
    // MARK: - Response Helpers
    private func sendFinalResponse(score: String, rawScore: String, context: NSExtensionContext) {
        log("📊 Sending final result: \(score)")
        
        let response = NSExtensionItem()
        response.userInfo = [ SFExtensionMessageKey: [ 
            "aiAnalysis": score,
            "rawScore": rawScore,
            "status": "success"
        ]]
        
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
    
    private func sendFinalResponseWithScores(score: String, rawScore: String, context: NSExtensionContext) {
        log("📊 Sending final result with scores: \(score)")
        
        var responseDict: [String: Any] = [
            "aiAnalysis": score,
            "rawScore": rawScore,
            "status": "success"
        ]
        
        var attachedScores: [String: Any]? = nil
        
        // Only use scores from the freshest background service response
        if let responseData = sharedDefaults.data(forKey: "safariAnalysisResponse"),
           let response = try? JSONDecoder().decode(SafariAnalysisResponse.self, from: responseData),
           let scores = response.scores {
            let allScores: [String: Any] = [
                "fitScores": scores.fitScores,
                "gapScores": scores.gapScores,
                "finalScore": scores.finalScore
            ]
            attachedScores = allScores
            // Keep lastAnalysisScores in sync for background.js logging only (not for fallback)
            sharedDefaults.set(allScores, forKey: "lastAnalysisScores")
            log("✅ DEBUG: Using fresh scores from safariAnalysisResponse")
        }
        
        // Removed fallback to lastAnalysisScores to prevent score contamination between jobs
        
        if let attachedScores = attachedScores {
            responseDict["scores"] = attachedScores
        } else {
            log("ℹ️ DEBUG: No fresh scores available for this job - analysis may still be in progress")
        }
        
        log("🔍 DEBUG: Final responseDict = \(responseDict)")
        
        let responseItem = NSExtensionItem()
        responseItem.userInfo = [SFExtensionMessageKey: responseDict]
        context.completeRequest(returningItems: [responseItem], completionHandler: nil)
    }
    
    private func sendPhaseResponse(phase: String, score: String, rawScore: String, context: NSExtensionContext) {
        log("✅ Sending \(phase) response: \(score)")
        
        let response = NSExtensionItem()
        response.userInfo = [ SFExtensionMessageKey: [ 
            "phase": phase,
            "aiAnalysis": score,
            "rawScore": rawScore,
            "status": "success"
        ]]
        
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
    
    private func sendResponse(aiResponse: String, context: NSExtensionContext) {
        let response = NSExtensionItem()
        response.userInfo = [ SFExtensionMessageKey: [ 
            "aiAnalysis": aiResponse,
            "status": "success"
        ]]
        
        context.completeRequest(returningItems: [response], completionHandler: nil)
        log("✅ AI analysis response sent to extension")
    }
    
    private func sendResponse(_ data: [String: Any], context: NSExtensionContext) {
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: data]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
    
    private func sendJSONResponse(data: [String: Any], context: NSExtensionContext) {
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: data]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
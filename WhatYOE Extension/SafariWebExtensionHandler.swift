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
    let timestamp: Date
}

struct SafariAnalysisResponse: Codable {
    let requestId: String
    let results: String?
    let error: String?
    let timestamp: Date
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
                
                // Send analysis request to background server with fourRun method
                let results = try await requestFourCycleAnalysisFromBackgroundServer(
                    resumeText: resumeData,
                    jobDescription: pageText
                )
                
                // Extract combined score from 4-cycle analysis results  
                let (rawScore, processedScore) = extractFourCycleScore(from: results)
                
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
                
                // Send request to WhatYOE - let it handle all prompt logic
                let results = try await requestAnalysisFromWhatYOE(
                    resumeText: resumeData,
                    jobDescription: pageText,
                    phase: "phase3"
                )
                
                // Extract Skills score from results (0-3 scale)
                let score = extractPhaseScore(from: results, phase: "Technical Skills")
                
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
                
                // Send request to WhatYOE - let it handle all prompt logic
                let results = try await requestAnalysisFromWhatYOE(
                    resumeText: resumeData,
                    jobDescription: pageText,
                    phase: "phase4"
                )
                
                // Extract Experience score from results (0-3 scale)
                let score = extractPhaseScore(from: results, phase: "Relevant Experience")
                
                log("✅ Phase 4 complete: \(score)")
                setProgress(stage: "final_score", message: "Final Score: \(score)")
                
                // Send response for Phase 4
                sendPhaseResponse(phase: "phase4", score: score, rawScore: score, context: context)
                
            } catch {
                log("❌ Phase 4 failed: \(error)")
                sendPhaseResponse(phase: "phase4", score: "0", rawScore: "0", context: context)
            }
        }
    }
    
    
    private func requestFourCycleAnalysisFromBackgroundServer(resumeText: String, jobDescription: String) async throws -> String {
        // Create analysis request
        let request = SafariAnalysisRequest(
            id: UUID().uuidString,
            resumeText: resumeText,
            jobDescription: jobDescription,
            timestamp: Date()
        )
        
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
        // Create analysis request - let WhatYOE handle all prompt logic
        let request = SafariAnalysisRequest(
            id: UUID().uuidString,
            resumeText: resumeText,
            jobDescription: jobDescription,
            timestamp: Date()
        )
        
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
                
                // Clean up
                sharedDefaults.removeObject(forKey: "safariAnalysisRequest")
                sharedDefaults.removeObject(forKey: "safariAnalysisResponse")
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
    
    // MARK: - Score Processing
    
    private func extractFourCycleScore(from response: String) -> (String, String) {
        // Log the raw response to debug what we're getting
        log("🔍 Raw WhatYOE response (first 500 chars): \(String(response.prefix(500)))")
        log("🔍 Response length: \(response.count) characters")
        
        // Extract all 8 scores from 4-cycle analysis (4 fit + 4 gap scores, 0-3 scale each)
        // Try multiple patterns to be more flexible
        let fitScorePatterns = [
            #"Fit Score:\s*(\d+)"#,
            #"\*\*Fit Score:\*\*\s*\[?(\d+)\]?"#,
            #"Fit Score:\s*\[(\d+)\]"#
        ]
        let gapScorePatterns = [
            #"Gap Score:\s*(\d+)"#,
            #"\*\*Gap Score:\*\*\s*\[?(\d+)\]?"#,
            #"Gap Score:\s*\[(\d+)\]"#
        ]
        
        var fitScores: [Int] = []
        var gapScores: [Int] = []
        let nsString = response as NSString
        
        // Extract Fit Scores - try multiple patterns
        for pattern in fitScorePatterns {
            if let fitRegex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let fitResults = fitRegex.matches(in: response, options: [], range: NSRange(location: 0, length: nsString.length))
                
                for result in fitResults {
                    if result.numberOfRanges > 1 {
                        let scoreRange = result.range(at: 1)
                        let scoreString = nsString.substring(with: scoreRange)
                        if let score = Int(scoreString), score >= 0 && score <= 3 {
                            fitScores.append(score)
                        }
                    }
                }
                
                if !fitScores.isEmpty {
                    log("🎯 Found fit scores using pattern: \(pattern)")
                    break
                }
            }
        }
        
        // Extract Gap Scores - try multiple patterns
        for pattern in gapScorePatterns {
            if let gapRegex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let gapResults = gapRegex.matches(in: response, options: [], range: NSRange(location: 0, length: nsString.length))
                
                for result in gapResults {
                    if result.numberOfRanges > 1 {
                        let scoreRange = result.range(at: 1)
                        let scoreString = nsString.substring(with: scoreRange)
                        if let score = Int(scoreString), score >= 0 && score <= 3 {
                            gapScores.append(score)
                        }
                    }
                }
                
                if !gapScores.isEmpty {
                    log("🎯 Found gap scores using pattern: \(pattern)")
                    break
                }
            }
        }
        
        // Calculate final score using your formula
        let fitMultiplier = 1.0  // You can adjust this
        let gapMultiplier = 1.0  // You can adjust this
        
        let finalScore: Double
        if fitScores.count == 4 && gapScores.count == 4 {
            let fitSum = Double(fitScores.reduce(0, +))
            let gapSum = Double(gapScores.reduce(0, +))
            
            // Formula: (sum of fit * multiplier + sum of gap * multiplier) / 8
            finalScore = (fitSum * fitMultiplier + gapSum * gapMultiplier) / 8.0
        } else {
            log("⚠️ Expected 4 fit and 4 gap scores, got \(fitScores.count) fit and \(gapScores.count) gap")
            finalScore = 0.0
        }
        
        let processedScoreString = String(format: "%.1f", finalScore)
        let rawEstimate = Int(finalScore.rounded())
        
        log("🔢 Extracted 8 scores - Fit: \(fitScores), Gap: \(gapScores)")
        log("🔢 Final calculation: (Fit sum: \(fitScores.reduce(0, +)) * \(fitMultiplier) + Gap sum: \(gapScores.reduce(0, +)) * \(gapMultiplier)) / 8 = \(finalScore)")
        
        // Store scores for background.js logging
        let allScores: [String: Any] = [
            "fitScores": fitScores,
            "gapScores": gapScores,
            "finalScore": finalScore
        ]
        sharedDefaults.set(allScores, forKey: "lastAnalysisScores")
        
        return (String(rawEstimate), processedScoreString)
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
        
        // Get the stored scores from extractFourCycleScore
        let storedScores = sharedDefaults.object(forKey: "lastAnalysisScores") as? [String: Any]
        
        log("🔍 DEBUG: storedScores = \(String(describing: storedScores))")
        
        var responseDict: [String: Any] = [
            "aiAnalysis": score,
            "rawScore": rawScore,
            "status": "success"
        ]
        
        // Add scores if available
        if let scores = storedScores {
            responseDict["scores"] = scores
            log("✅ DEBUG: Added scores to response")
        } else {
            log("❌ DEBUG: No stored scores found")
        }
        
        log("🔍 DEBUG: Final responseDict = \(responseDict)")
        
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: responseDict]
        
        context.completeRequest(returningItems: [response], completionHandler: nil)
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
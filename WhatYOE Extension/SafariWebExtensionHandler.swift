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

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    
    // MARK: - Properties
    private let sharedDefaults = UserDefaults(suiteName: "group.com.apple.WhatYOE.shared") ?? UserDefaults.standard
    private let model = SystemLanguageModel.default
    
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
            
            // Handle page analysis (main functionality)
            if messageContent == "pageAnalysis" {
                if let data = messageDict["data"] as? [String: Any] {
                    let characterCount = data["characterCount"] as? Int ?? 0
                    let wordCount = data["wordCount"] as? Int ?? 0
                    let _ = data["title"] as? String ?? "Unknown"
                    let pageText = data["pageText"] as? String ?? ""
                    
                    log("📊 PAGE_ANALYSIS: Starting analysis - \(wordCount) words, \(characterCount) characters")
                    
                    // Analyze with Foundation Model
                    analyzeJobDescription(pageText: pageText, context: context)
                    return // Don't send immediate response, wait for AI analysis
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
                let bundleIdentifier = "com.apple.WhatYOE"
                
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
        let bundleIdentifier = "com.apple.WhatYOE"
        
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
    
    private func handlePageAnalysisRequest(message: [String: Any], context: NSExtensionContext) {
        guard let data = message["data"] as? [String: Any],
              let pageText = data["pageText"] as? String else {
            log("❌ Missing page data")
            sendResponse(["status": "error", "message": "Missing page data"], context: context)
            return
        }
        
        let wordCount = data["wordCount"] as? Int ?? 0
        log("🎯 Starting analysis: \(wordCount) words")
        
        analyzeJobDescription(pageText: pageText, context: context)
    }
    
    // MARK: - Analysis
    private func analyzeJobDescription(pageText: String, context: NSExtensionContext) {
        // Check if models are available
        guard case .available = model.availability else {
            log("⚠️ Foundation Models not available")
            sendFinalResponse(score: "0.0", rawScore: "0", context: context)
            return
        }
        
        Task {
            do {
                let resumeData = getCleanedResumeData()
                
                // Step 1: Clean job description
                log("💾 Progress: parsing_jd - Parsing job description...")
                let cleanedJob = try await cleanJobDescription(pageText)
                
                // Step 2: 4-round evaluation
                let evaluationResult = try await performEvaluation(resume: resumeData, job: cleanedJob)
                
                // Step 3: Final score
                log("💾 Progress: final_score - Calculating final score...")
                let (rawScore, processedScore) = extractScore(from: evaluationResult)
                
                log("✅ Analysis complete: \(processedScore)")
                sendFinalResponse(score: processedScore, rawScore: rawScore, context: context)
                
            } catch {
                log("❌ Analysis failed: \(error)")
                sendFinalResponse(score: "0.0", rawScore: "0", context: context)
            }
        }
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
    
    private func cleanJobDescription(_ jobText: String) async throws -> String {
        let jobCleaningPrompt = """
        You are a professional document processor. Clean and structure this job description for analysis.
        
        Extract and organize:
        - Job Title and Level (Junior/Mid/Senior)
        - Required Experience (years)
        - Required Education
        - Required Technical Skills
        - Preferred Technical Skills
        - Key Responsibilities
        - Company/Industry Context
        
        Remove:
        - Company marketing language
        - Legal boilerplate
        - Redundant information
        
        Output a clear, structured job description focused on requirements.
        """
        
        let session = LanguageModelSession(instructions: jobCleaningPrompt)
        let prompt = """
        Clean and structure this job description text:
        
        === RAW JOB DESCRIPTION ===
        \(jobText)
        
        === END RAW JOB DESCRIPTION ===
        
        Provide the cleaned, structured version following your instructions.
        """
        let response = try await session.respond(to: prompt)
        return response.content
    }
    
    private func performEvaluation(resume: String, job: String) async throws -> String {
        let yearsPrompt = """
        Evaluate ONLY Years of Experience:
        
        **Why they fit:** [List relevant experience from resume]
        **Why they don't fit:** [Experience gaps, if any]
        **Fit Score:** [0-3]
        **Gap Score:** [0-3]
        
        FIT SCORING: 0=None, 1=Some, 2=Good, 3=Strong
        GAP SCORING: 0=Major gaps, 1=Moderate gaps, 2=Minor gaps, 3=No gaps
        """
        
        let educationPrompt = """
        Evaluate ONLY Education:
        
        **Why they fit:** [Degrees and relevance to job]
        **Why they don't fit:** [Educational gaps, if any]
        **Fit Score:** [0-3]
        **Gap Score:** [0-3]
        
        FIT SCORING: 0=None, 1=Some, 2=Good, 3=Strong
        GAP SCORING: 0=Major gaps, 1=Moderate gaps, 2=Minor gaps, 3=No gaps
        """
        
        let skillsPrompt = """
        Evaluate ONLY Technical Skills:
        
        **Why they fit:** [Technical skills that match requirements]
        **Why they don't fit:** [Missing technical skills, if any]
        **Fit Score:** [0-3]
        **Gap Score:** [0-3]
        
        FIT SCORING: 0=None, 1=Some, 2=Good, 3=Strong
        GAP SCORING: 0=Major gaps, 1=Moderate gaps, 2=Minor gaps, 3=No gaps
        """
        
        let experiencePrompt = """
        Evaluate ONLY Relevant Experience:
        
        **Why they fit:** [Industry/role experience that aligns]
        **Why they don't fit:** [Relevant experience gaps, if any]
        **Fit Score:** [0-3]
        **Gap Score:** [0-3]
        
        FIT SCORING: 0=None, 1=Some, 2=Good, 3=Strong
        GAP SCORING: 0=Major gaps, 1=Moderate gaps, 2=Minor gaps, 3=No gaps
        """
        
        let rounds = [
            ("round_1", "Years of Experience", yearsPrompt),
            ("round_2", "Education", educationPrompt),
            ("round_3", "Technical Skills", skillsPrompt),
            ("round_4", "Relevant Experience", experiencePrompt)
        ]
        
        var results: [String] = []
        
        for (stage, title, prompt) in rounds {
            log("💾 Progress: \(stage) - Evaluating \(title)...")
            
            let session = LanguageModelSession(instructions: prompt)
            let userPrompt = "JOB:\n\(job)\n\nRESUME:\n\(resume)\n\nEvaluate \(title.lowercased()) only."
            let result = try await session.respond(to: userPrompt)
            results.append("## \(title.uppercased())\n\(result.content)")
        }
        
        return combineResults(results)
    }
    
    // MARK: - Score Processing
    private func combineResults(_ results: [String]) -> String {
        let (fitScores, gapScores) = extractScoresFromResults(results)
        let totalFitScore = fitScores.reduce(0.0, +)
        let totalGapScore = gapScores.reduce(0.0, +)
        let finalScore = (totalFitScore + totalGapScore) / 8.0
        
        return """
        \(results.joined(separator: "\n\n"))
        
        ## FINAL EVALUATION
        **Total Fit Score:** \(String(format: "%.1f", totalFitScore)) / 12
        **Total Gap Score:** \(String(format: "%.1f", totalGapScore)) / 12
        **Final Score:** \(String(format: "%.1f", finalScore)) (0-3 scale)
        """
    }
    
    private func extractScoresFromResults(_ results: [String]) -> (fitScores: [Double], gapScores: [Double]) {
        var fitScores: [Double] = []
        var gapScores: [Double] = []
        
        for result in results {
            if let fitScore = extractScore(from: result, pattern: #"Fit Score:\*?\*?\s*(\d+)"#) {
                let adjustedScore = fitScore == 1 ? Double(fitScore) * 0.9 : 
                                   fitScore >= 2 ? Double(fitScore) * 1.1 : 0.0
                fitScores.append(adjustedScore)
            } else {
                fitScores.append(0.0)
            }
            
            if let gapScore = extractScore(from: result, pattern: #"Gap Score:\*?\*?\s*(\d+)"#) {
                gapScores.append(Double(gapScore) * 0.9)
            } else {
                gapScores.append(0.0)
            }
        }
        
        return (fitScores: fitScores, gapScores: gapScores)
    }
    
    private func extractScore(from text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let scoreRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(String(text[scoreRange]))
    }
    
    private func extractScore(from response: String) -> (String, String) {
        if let match = response.range(of: #"Final Score:\*?\*?\s*(\d+\.?\d*)"#, options: .regularExpression),
           let scoreText = response[match].split(separator: " ").last,
           let score = Double(scoreText) {
            let rawEstimate = Int(score * 8)
            let processedScoreString = String(format: "%.1f", score)
            return (String(rawEstimate), processedScoreString)
        }
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
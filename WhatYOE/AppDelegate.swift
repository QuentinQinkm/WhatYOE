import Cocoa
import os.log
import UniformTypeIdentifiers
import UserNotifications
import FoundationModels

// MARK: - Data Structures
struct ResumeItem {
    let id: String
    let name: String
    let cleanedText: String
    let dateCreated: Date
    
    // Convenience initializer for backward compatibility
    init(name: String, cleanedText: String) {
        self.id = UUID().uuidString
        self.name = name
        self.cleanedText = cleanedText
        self.dateCreated = Date()
    }
    
    init(id: String, name: String, cleanedText: String, dateCreated: Date) {
        self.id = id
        self.name = name
        self.cleanedText = cleanedText
        self.dateCreated = dateCreated
    }
}

extension ResumeItem: Codable {}

// MARK: - Resume Manager for Main App
class ResumeManager {
    static let shared = ResumeManager()
    private let userDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
    
    private init() {}
    
    func getAllResumes() -> [ResumeItem] {
        guard let data = userDefaults.data(forKey: "savedResumes"),
              let resumes = try? JSONDecoder().decode([ResumeItem].self, from: data) else {
            return []
        }
        return resumes
    }
    
    func saveResume(_ resume: ResumeItem) {
        var resumes = getAllResumes()
        resumes.append(resume)
        if let data = try? JSONEncoder().encode(resumes) {
            userDefaults.set(data, forKey: "savedResumes")
        }
    }
    
    func deleteResume(withId id: String) {
        var resumes = getAllResumes()
        resumes.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(resumes) {
            userDefaults.set(data, forKey: "savedResumes")
        }
    }
    
    func getResume(withId id: String) -> ResumeItem? {
        return getAllResumes().first { $0.id == id }
    }
    
    func setActiveResume(_ resume: ResumeItem) {
        userDefaults.set(resume.id, forKey: "activeResumeId")
        userDefaults.set(resume.cleanedText, forKey: "cleanedResumeData")
    }
    
    func getActiveResumeId() -> String? {
        return userDefaults.string(forKey: "activeResumeId")
    }
}

// MARK: - Communication Data Structures
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
        print("🚀 WhatYOE Background Service starting...")
        
        // Check for resume cleaning request
        if CommandLine.arguments.contains("--resume-cleaning") {
            print("🧹 Resume cleaning request detected")
            handleResumeCleaningRequest()
        } else if CommandLine.arguments.contains("--job-analysis") {
            print("🔍 Job analysis request detected")
            handleJobAnalysisRequest()
        } else {
            // Set up status bar immediately
            setupStatusBar()
            requestNotificationPermissions()
            
            print("✅ Background service setup complete")
        }
        
        // Always start monitoring for requests regardless of startup mode
        startSafariAnalysisMonitoring()
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
    
    // MARK: - Resume Cleaning Server
    
    private func handleResumeCleaningRequest() {
        // Set up as background service for cleaning
        setupStatusBar()
        
        Task {
            await processResumeCleaningRequest()
        }
    }
    
    private func processResumeCleaningRequest() async {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        guard let requestData = sharedDefaults.data(forKey: "resumeCleaningRequest"),
              let request = try? JSONDecoder().decode(ResumeCleaningRequest.self, from: requestData) else {
            print("❌ No valid cleaning request found")
            return
        }
        
        print("🧹 Processing resume cleaning request: \(request.id)")
        print("🧹 Main App: Using UserDefaults suite: group.com.kuangming.WhatYOE.shared")
        
        do {
            // Use PromptTemplates for consistent cleaning
            let cleanedText = try await cleanResumeTextWithAI(request.rawText)
            
            // Send response back
            let response = ResumeCleaningResponse(
                requestId: request.id,
                cleanedText: cleanedText,
                error: nil,
                timestamp: Date()
            )
            
            if let responseData = try? JSONEncoder().encode(response) {
                print("🧹 Main App: Saving response data, length: \(responseData.count)")
                print("🧹 Main App: Response request ID: \(response.requestId)")
                
                sharedDefaults.set(responseData, forKey: "resumeCleaningResponse")
                sharedDefaults.set("completed", forKey: "resumeCleaningStatus")
                
                // Force synchronization
                sharedDefaults.synchronize()
                
                print("🧹 Main App: Response saved successfully")
                print("🧹 Main App: Response data now available at key: 'resumeCleaningResponse'")
                
                // Verify the data was saved
                if let savedData = sharedDefaults.data(forKey: "resumeCleaningResponse") {
                    print("🧹 Main App: Verification - saved data length: \(savedData.count)")
                } else {
                    print("🧹 Main App: WARNING - Response data not found after saving!")
                }
                
                print("✅ Resume cleaning completed and response saved")
            }
            
        } catch {
            print("❌ Resume cleaning failed: \(error)")
            
            // Send error response
            let response = ResumeCleaningResponse(
                requestId: request.id,
                cleanedText: nil,
                error: error.localizedDescription,
                timestamp: Date()
            )
            
            if let responseData = try? JSONEncoder().encode(response) {
                sharedDefaults.set(responseData, forKey: "resumeCleaningResponse")
                sharedDefaults.set("error", forKey: "resumeCleaningStatus")
                sharedDefaults.synchronize()
            }
        }
    }
    
    private func cleanResumeTextWithAI(_ text: String) async throws -> String {
        let session = LanguageModelSession(instructions: PromptTemplates.resumeCleaningPrompt)
        let prompt = PromptTemplates.createCleaningPrompt(text: text, isResume: true)
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Job Analysis Server
    
    private func handleJobAnalysisRequest() {
        // Set up as background service for analysis
        setupStatusBar()
        
        Task {
            await processJobAnalysisRequest()
        }
    }
    
    private func processJobAnalysisRequest() async {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        guard let requestData = sharedDefaults.data(forKey: "analysisRequest"),
              let request = try? JSONDecoder().decode(AnalysisRequest.self, from: requestData) else {
            print("❌ No valid analysis request found")
            return
        }
        
        print("🔍 Processing job analysis request: \(request.id)")
        
        do {
            // Clean job description first
            let cleanedJob = try await cleanJobDescriptionWithAI(request.jobDescription)
            
            // Perform 4-round evaluation using existing logic
            let results = try await performFourRoundEvaluation(
                resumeText: request.resumeText,
                jobDescription: cleanedJob
            )
            
            // Combine results
            let combinedResults = combineEvaluationResults(results: results)
            
            // Send response back
            let response = AnalysisResponse(
                requestId: request.id,
                results: combinedResults,
                error: nil,
                timestamp: Date()
            )
            
            if let responseData = try? JSONEncoder().encode(response) {
                sharedDefaults.set(responseData, forKey: "analysisResponse")
                sharedDefaults.set("completed", forKey: "analysisStatus")
                print("✅ Job analysis completed and response saved")
            }
            
        } catch {
            print("❌ Job analysis failed: \(error)")
            
            // Send error response
            let response = AnalysisResponse(
                requestId: request.id,
                results: nil,
                error: error.localizedDescription,
                timestamp: Date()
            )
            
            if let responseData = try? JSONEncoder().encode(response) {
                sharedDefaults.set(responseData, forKey: "analysisResponse")
                sharedDefaults.set("error", forKey: "analysisStatus")
            }
        }
    }
    
    private func cleanJobDescriptionWithAI(_ text: String) async throws -> String {
        let session = LanguageModelSession(instructions: PromptTemplates.jobCleaningPrompt)
        let prompt = PromptTemplates.createCleaningPrompt(text: text, isResume: false)
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func performFourRoundEvaluation(resumeText: String, jobDescription: String) async throws -> [String] {
        let model = SystemLanguageModel.default
        
        guard case .available = model.availability else {
            throw NSError(domain: "AI", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI not available"])
        }
        
        let prompts = [
            PromptTemplates.yearsEvaluationPrompt,
            PromptTemplates.educationEvaluationPrompt,
            PromptTemplates.technicalSkillsEvaluationPrompt,
            PromptTemplates.relevantExperienceEvaluationPrompt
        ]
        
        var results: [String] = []
        
        for prompt in prompts {
            let session = LanguageModelSession(instructions: prompt)
            let fullPrompt = prompt + "\n\nResume:\n\(resumeText)\n\nJob Description:\n\(jobDescription)"
            let response = try await session.respond(to: fullPrompt)
            results.append(response.content)
        }
        
        return results
    }
    
    private func performComprehensiveEvaluation(resumeText: String, jobDescription: String) async throws -> String {
        let model = SystemLanguageModel.default
        
        guard case .available = model.availability else {
            throw NSError(domain: "AI", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI not available"])
        }
        
        // Use the comprehensive evaluation prompt
        let comprehensivePrompt = PromptTemplates.createComprehensiveEvaluationPrompt(
            cleanedResume: resumeText,
            cleanedJob: jobDescription
        )
        
        print("🚀 Comprehensive prompt length: \(comprehensivePrompt.count) characters")
        print("🚀 Resume text length: \(resumeText.count) characters")
        print("🚀 Job description length: \(jobDescription.count) characters")
        
        // Calculate token usage breakdown
        let promptTemplateLength = comprehensivePrompt.count - resumeText.count - jobDescription.count
        let estimatedPromptTokens = promptTemplateLength / 4
        let estimatedResumeTokens = resumeText.count / 4
        let estimatedJobTokens = jobDescription.count / 4
        let totalEstimatedTokens = estimatedPromptTokens + estimatedResumeTokens + estimatedJobTokens
        
        print("🚀 Token breakdown:")
        print("   - Prompt template: ~\(estimatedPromptTokens) tokens")
        print("   - Resume text: ~\(estimatedResumeTokens) tokens")
        print("   - Job description: ~\(estimatedJobTokens) tokens")
        print("   - Total estimated: ~\(totalEstimatedTokens) tokens")
        print("   - Available: 4,096 tokens")
        print("   - Remaining: ~\(4096 - totalEstimatedTokens) tokens")
        
        // Create session with instructions, then send the prompt
        let session = LanguageModelSession(instructions: "You are a professional recruiter. Evaluate candidates comprehensively.")
        let response = try await session.respond(to: comprehensivePrompt)
        
        return response.content
    }
    
    private func combineEvaluationResults(results: [String]) -> String {
        let yearsResult = results[0]
        let educationResult = results[1]
        let skillsResult = results[2]
        let experienceResult = results[3]
        
        let (fitScores, gapScores) = extractScoresFromResults(
            years: yearsResult,
            education: educationResult,
            skills: skillsResult,
            experience: experienceResult
        )
        
        let totalFitScore = fitScores.reduce(0.0, +)
        let totalGapScore = gapScores.reduce(0.0, +)
        let finalScore = (totalFitScore + totalGapScore) / 8.0
        
        return """
        # EVALUATION RESULTS
        
        ## 1. YEARS OF EXPERIENCE
        \(yearsResult)
        
        ## 2. EDUCATION
        \(educationResult)
        
        ## 3. TECHNICAL SKILLS
        \(skillsResult)
        
        ## 4. RELEVANT EXPERIENCE
        \(experienceResult)
        
        ## FINAL SCORE
        **Total Fit Score:** \(String(format: "%.1f", totalFitScore)) / 12
        **Total Gap Score:** \(String(format: "%.1f", totalGapScore)) / 12
        **Final Score:** \(String(format: "%.1f", finalScore)) (0-3 scale)
        
        ## RECOMMENDATION
        \(getRecommendation(finalScore: finalScore))
        """
    }
    
    private func extractScoresFromResults(years: String, education: String, skills: String, experience: String) -> (fitScores: [Double], gapScores: [Double]) {
        let results = [years, education, skills, experience]
        var fitScores: [Double] = []
        var gapScores: [Double] = []
        
        for result in results {
            fitScores.append(extractScore(from: result, type: "Fit Score"))
            gapScores.append(extractScore(from: result, type: "Gap Score"))
        }
        
        return (fitScores, gapScores)
    }
    
    private func extractScore(from text: String, type: String) -> Double {
        let patterns = [
            "\\*\\*\(type):\\*\\*\\s*([0-9]+(?:\\.\\d+)?)",
            "\\*\\*\(type.lowercased()):\\*\\*\\s*([0-9]+(?:\\.\\d+)?)",
            "\(type):\\s*([0-9]+(?:\\.\\d+)?)",
            "\(type.lowercased()):\\s*([0-9]+(?:\\.\\d+)?)"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: text.utf16.count)
                
                if let match = regex.firstMatch(in: text, range: range) {
                    let scoreRange = match.range(at: 1)
                    if let range = Range(scoreRange, in: text) {
                        let scoreString = String(text[range])
                        if let score = Double(scoreString) {
                            return score
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        return 0.0
    }
    
    private func getRecommendation(finalScore: Double) -> String {
        switch finalScore {
        case 0.0..<1.0:
            return "❌ Poor Match - Candidate does not meet minimum requirements"
        case 1.0..<2.0:
            return "⚠️ Weak Match - Candidate has some gaps but may be considered"
        case 2.0..<2.5:
            return "✅ Good Match - Candidate meets most requirements"
        case 2.5...3.0:
            return "🎯 Excellent Match - Candidate is highly qualified"
        default:
            return "❓ Unknown - Score out of expected range"
        }
    }
    
    // MARK: - Safari Analysis Monitoring
    
    private func startSafariAnalysisMonitoring() {
        // Start a background task to monitor for Safari analysis requests
        Task {
            await monitorSafariAnalysisRequests()
        }
        
        // Start a background task to monitor for desktop app analysis requests
        Task {
            await monitorDesktopAnalysisRequests()
        }
        
        // Start a background task to monitor for resume cleaning requests
        Task {
            await monitorResumeCleaningRequests()
        }
        
        print("🌐 Safari analysis monitoring started")
        print("🖥️ Desktop analysis monitoring started")
        print("🧹 Resume cleaning monitoring started")
    }
    
    private func monitorSafariAnalysisRequests() async {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        while true {
            // Check for pending Safari analysis requests
            if let requestData = sharedDefaults.data(forKey: "safariAnalysisRequest"),
               let request = try? JSONDecoder().decode(SafariAnalysisRequest.self, from: requestData),
               sharedDefaults.string(forKey: "safariAnalysisStatus") == "pending" {
                
                print("🌐 Processing Safari analysis request: \(request.id)")
                await processSafariAnalysisRequest(request)
            }
            
            // Check every 500ms
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
    
    private func monitorDesktopAnalysisRequests() async {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        while true {
            // Check for pending desktop analysis requests
            if let requestData = sharedDefaults.data(forKey: "analysisRequest"),
               let request = try? JSONDecoder().decode(AnalysisRequest.self, from: requestData),
               sharedDefaults.string(forKey: "analysisStatus") == "pending" {
                
                print("🖥️ Processing desktop analysis request: \(request.id)")
                await processDesktopAnalysisRequest(request)
            }
            
            // Check every 500ms
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
    
    private func monitorResumeCleaningRequests() async {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        print("🧹 Resume cleaning monitoring started - checking every 500ms")
        
        while true {
            // Check for pending resume cleaning requests
            if let requestData = sharedDefaults.data(forKey: "resumeCleaningRequest"),
               let request = try? JSONDecoder().decode(ResumeCleaningRequest.self, from: requestData),
               sharedDefaults.string(forKey: "resumeCleaningStatus") == "pending" {
                
                print("🧹 Processing resume cleaning request: \(request.id)")
                await processResumeCleaningRequest()
            }
            
            // Check every 500ms
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
    
    private func processSafariAnalysisRequest(_ request: SafariAnalysisRequest) async {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        do {
            // Check which analysis method to use
            let analysisMethod = sharedDefaults.string(forKey: "analysisMethod") ?? "fourRun"
            let analysisType = sharedDefaults.string(forKey: "safariAnalysisType") ?? "standard"
            
            print("🌐 Processing Safari analysis request using \(analysisMethod) method")
            
            let cleanedJob = try await cleanJobDescriptionWithAI(request.jobDescription)
            let results: String
            
            if analysisMethod == "singleRun" || analysisType == "comprehensive" {
                // Use comprehensive single-run analysis
                print("🚀 Using comprehensive single-run analysis")
                results = try await performComprehensiveEvaluation(
                    resumeText: request.resumeText,
                    jobDescription: cleanedJob
                )
            } else {
                // Use traditional 4-run analysis
                print("🔄 Using traditional 4-run analysis")
                let phaseResults = try await performFourRoundEvaluation(
                    resumeText: request.resumeText,
                    jobDescription: cleanedJob
                )
                results = combineEvaluationResults(results: phaseResults)
            }
            
            // Send response back to Safari extension
            let response = SafariAnalysisResponse(
                requestId: request.id,
                results: results,
                error: nil,
                timestamp: Date()
            )
            
            if let responseData = try? JSONEncoder().encode(response) {
                sharedDefaults.set(responseData, forKey: "safariAnalysisResponse")
                sharedDefaults.set("completed", forKey: "safariAnalysisStatus")
                print("✅ Safari analysis completed and response saved")
            }
            
        } catch {
            print("❌ Safari analysis failed: \(error)")
            
            // Send error response
            let response = SafariAnalysisResponse(
                requestId: request.id,
                results: nil,
                error: error.localizedDescription,
                timestamp: Date()
            )
            
            if let responseData = try? JSONEncoder().encode(response) {
                sharedDefaults.set(responseData, forKey: "safariAnalysisResponse")
                sharedDefaults.set("error", forKey: "safariAnalysisStatus")
            }
        }
    }
    
    private func processDesktopAnalysisRequest(_ request: AnalysisRequest) async {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        do {
            // Check which analysis method to use
            let analysisMethod = sharedDefaults.string(forKey: "analysisMethod") ?? "fourRun"
            
            print("🖥️ Processing desktop analysis request using \(analysisMethod) method")
            print("🖥️ Resume text length: \(request.resumeText.count) characters")
            print("🖥️ Job description length: \(request.jobDescription.count) characters")
            
            let cleanedJob = try await cleanJobDescriptionWithAI(request.jobDescription)
            print("🖥️ Cleaned job description length: \(cleanedJob.count) characters")
            
            let results: String
            
            if analysisMethod == "singleRun" {
                // Use comprehensive single-run analysis
                print("🚀 Using comprehensive single-run analysis")
                
                // Create the full prompt to check size
                let fullPrompt = PromptTemplates.createComprehensiveEvaluationPrompt(
                    cleanedResume: request.resumeText,
                    cleanedJob: cleanedJob
                )
                print("🚀 Full prompt length: \(fullPrompt.count) characters")
                print("🚀 Full prompt preview: \(String(fullPrompt.prefix(200)))...")
                
                // Estimate token count (rough approximation: 1 token ≈ 4 characters)
                let estimatedTokens = fullPrompt.count / 4
                print("🚀 Estimated tokens: ~\(estimatedTokens) (characters ÷ 4)")
                print("🚀 Token limit: 4,096")
                print("🚀 Token usage: \(estimatedTokens)/4,096 (\(Int((Double(estimatedTokens) / 4096.0) * 100))%)")
                
                if estimatedTokens > 4000 {
                    print("⚠️ WARNING: Estimated tokens exceed 4,000 - may hit limit!")
                } else if estimatedTokens > 3500 {
                    print("⚠️ WARNING: Estimated tokens above 3,500 - approaching limit!")
                } else {
                    print("✅ Estimated tokens well within limit")
                }
                
                results = try await performComprehensiveEvaluation(
                    resumeText: request.resumeText,
                    jobDescription: cleanedJob
                )
            } else {
                // Use traditional 4-run analysis
                print("🔄 Using traditional 4-run analysis")
                
                // Log token usage for 4-round method
                let totalInputLength = request.resumeText.count + cleanedJob.count
                let estimatedTotalTokens = totalInputLength / 4
                print("🔄 Total input length: \(totalInputLength) characters")
                print("🔄 Estimated total tokens: ~\(estimatedTotalTokens) (characters ÷ 4)")
                print("🔄 Note: 4-round method uses shorter prompts per call")
                
                let phaseResults = try await performFourRoundEvaluation(
                    resumeText: request.resumeText,
                    jobDescription: cleanedJob
                )
                results = combineEvaluationResults(results: phaseResults)
            }
            
            // Send response back to desktop app
            let response = AnalysisResponse(
                requestId: request.id,
                results: results,
                error: nil,
                timestamp: Date()
            )
            
            if let responseData = try? JSONEncoder().encode(response) {
                sharedDefaults.set(responseData, forKey: "analysisResponse")
                sharedDefaults.set("completed", forKey: "analysisStatus")
                print("✅ Desktop analysis completed and response saved")
            }
            
        } catch {
            print("❌ Desktop analysis failed: \(error)")
            
            // Send error response
            let response = AnalysisResponse(
                requestId: request.id,
                results: nil,
                error: error.localizedDescription,
                timestamp: Date()
            )
            
            if let responseData = try? JSONEncoder().encode(response) {
                sharedDefaults.set(responseData, forKey: "analysisResponse")
                sharedDefaults.set("error", forKey: "analysisStatus")
            }
        }
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

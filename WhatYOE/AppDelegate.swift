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

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    private var statusItem: NSStatusItem?
    private var isAnalysisStopped = false
    
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
        
        print("🚀 Starting concurrent 4-round evaluation...")
        let startTime = Date()
        
        // Create concurrent tasks for all 4 evaluations
        async let yearsTask = evaluateWithPrompt(
            prompt: prompts[0],
            resumeText: resumeText,
            jobDescription: jobDescription,
            name: "Years of Experience"
        )
        
        async let educationTask = evaluateWithPrompt(
            prompt: prompts[1],
            resumeText: resumeText,
            jobDescription: jobDescription,
            name: "Education"
        )
        
        async let skillsTask = evaluateWithPrompt(
            prompt: prompts[2],
            resumeText: resumeText,
            jobDescription: jobDescription,
            name: "Technical Skills"
        )
        
        async let experienceTask = evaluateWithPrompt(
            prompt: prompts[3],
            resumeText: resumeText,
            jobDescription: jobDescription,
            name: "Relevant Experience"
        )
        
        // Wait for all tasks to complete concurrently
        let results = try await [
            yearsTask,
            educationTask,
            skillsTask,
            experienceTask
        ]
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ Concurrent 4-round evaluation completed in \(String(format: "%.1f", duration)) seconds")
        
        return results
    }
    
    // Helper function for individual evaluation tasks
    private func evaluateWithPrompt(prompt: String, resumeText: String, jobDescription: String, name: String) async throws -> String {
        let startTime = Date()
        print("🔄 Starting \(name) evaluation at \(startTime)...")
        
        let session = LanguageModelSession(instructions: prompt)
        let userQuery = "Resume:\n\(resumeText)\n\nJob Description:\n\(jobDescription)"
        let response = try await session.respond(to: userQuery)
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ Completed \(name) evaluation in \(String(format: "%.2f", duration))s")
        return response.content
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
        let (formattedOutput, _, _, _) = ScoreCalculator.processEvaluationResults(results: results)
        return formattedOutput
    }
    
    // Score calculation and extraction now handled by ScoreCalculator
    
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
        
        // Start a background task to monitor for stop/resume commands
        Task {
            await monitorStopResumeCommands()
        }
        
        print("🌐 Safari analysis monitoring started")
        print("🖥️ Desktop analysis monitoring started")
        print("🧹 Resume cleaning monitoring started")
        print("🛑 Stop/resume command monitoring started")
    }
    
    private func monitorSafariAnalysisRequests() async {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        var lastStopMessageTime: Date? = nil
        
        while true {
            // Check if analysis has been stopped globally
            if isAnalysisStopped {
                // Only log the stop message once, not repeatedly
                if lastStopMessageTime == nil {
                    print("🛑 Safari analysis monitoring stopped globally")
                    lastStopMessageTime = Date()
                }
                
                // Wait longer when stopped to reduce log spam
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                continue
            }
            
            // Check if analysis has been stopped via UserDefaults
            let status = sharedDefaults.string(forKey: "safariAnalysisStatus")
            if status == "stopped" {
                // Only log the stop message once, not repeatedly
                if lastStopMessageTime == nil {
                    print("🛑 Safari analysis monitoring stopped by user request")
                    lastStopMessageTime = Date()
                }
                
                // Wait longer when stopped to reduce log spam
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                continue
            }
            
            // Reset stop message time when resuming
            if lastStopMessageTime != nil {
                print("▶️ Safari analysis monitoring resumed")
                lastStopMessageTime = nil
            }
            
            // Check for pending Safari analysis requests
            if let requestData = sharedDefaults.data(forKey: "safariAnalysisRequest"),
               let request = try? JSONDecoder().decode(SafariAnalysisRequest.self, from: requestData),
               status == "pending" {
                
                print("🌐 Processing Safari analysis request: \(request.id)")
                await processSafariAnalysisRequest(request)
            }
            
            // Check every 500ms when active
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
    
    private func monitorDesktopAnalysisRequests() async {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        var lastStopMessageTime: Date? = nil
        
        while true {
            // Check if analysis has been stopped
            let status = sharedDefaults.string(forKey: "analysisStatus")
            if status == "stopped" {
                // Only log the stop message once, not repeatedly
                if lastStopMessageTime == nil {
                    print("🛑 Desktop analysis monitoring stopped by user request")
                    lastStopMessageTime = Date()
                }
                
                // Wait longer when stopped to reduce log spam
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                continue
                }
            
            // Reset stop message time when resuming
            if lastStopMessageTime != nil {
                print("▶️ Desktop analysis monitoring resumed")
                lastStopMessageTime = nil
            }
            
            // Check for pending desktop analysis requests
            if let requestData = sharedDefaults.data(forKey: "analysisRequest"),
               let request = try? JSONDecoder().decode(AnalysisRequest.self, from: requestData),
               status == "pending" {
                
                print("🖥️ Processing desktop analysis request: \(request.id)")
                await processDesktopAnalysisRequest(request)
            }
            
            // Check every 500ms when active
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
    
    private func monitorResumeCleaningRequests() async {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        print("🧹 Resume cleaning monitoring started - checking every 500ms")
        
        while true {
            // Check if analysis has been stopped globally
            if isAnalysisStopped {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                continue
            }
            
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
    
    // MARK: - Stop/Resume Control
    
    private func handleStopAnalysis() {
        isAnalysisStopped = true
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        // Set status to stopped
        sharedDefaults.set("stopped", forKey: "safariAnalysisStatus")
        sharedDefaults.set("stopped", forKey: "analysisStatus")
        
        // Clear any pending requests
        sharedDefaults.removeObject(forKey: "safariAnalysisRequest")
        sharedDefaults.removeObject(forKey: "analysisRequest")
        
        print("🛑 Analysis stopped globally - all monitoring halted")
    }
    
    private func handleResumeAnalysis() {
        isAnalysisStopped = false
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        // Reset status to allow processing
        sharedDefaults.set("pending", forKey: "safariAnalysisStatus")
        sharedDefaults.set("pending", forKey: "analysisStatus")
        
        print("▶️ Analysis resumed globally - all monitoring active")
    }
    
    private func monitorStopResumeCommands() async {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        while true {
            // Check for stop command
            if sharedDefaults.string(forKey: "stopAnalysisCommand") == "stop" {
                handleStopAnalysis()
                sharedDefaults.removeObject(forKey: "stopAnalysisCommand")
            }
            
            // Check for resume command
            if sharedDefaults.string(forKey: "resumeAnalysisCommand") == "resume" {
                handleResumeAnalysis()
                sharedDefaults.removeObject(forKey: "resumeAnalysisCommand")
            }
            
            // Check every 1 second
            try? await Task.sleep(nanoseconds: 1_000_000_000)
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
            
            // Save the job analysis result
            let activeResumeId = ResumeManager.shared.getActiveResumeId() ?? "unknown"
            let jobTitle = request.jobTitle ?? "Unknown Position"
            let company = request.company ?? "Unknown Company"
            
            let savedJob = JobManager.shared.createJobFromSafariAnalysis(
                jobTitle: jobTitle,
                company: company,
                cleanedJobDescription: cleanedJob,
                analysisResult: results,
                resumeId: activeResumeId
            )
            
            print("💼 Job saved with ID: \(savedJob.jobId)")
            
            // Prepare scores for response
            let fitScores = [
                savedJob.analysisScores.yearsOfExperienceFit,
                savedJob.analysisScores.educationFit,
                savedJob.analysisScores.technicalSkillsFit,
                savedJob.analysisScores.relevantExperienceFit
            ].filter { $0 > 0.0 } // Only include valid scores
            
            let gapScores = [
                savedJob.analysisScores.yearsOfExperienceGap,
                savedJob.analysisScores.educationGap,
                savedJob.analysisScores.technicalSkillsGap,
                savedJob.analysisScores.relevantExperienceGap
            ].filter { $0 > 0.0 } // Only include valid scores
            
            print("🔢 Final scores for Safari - Fit: \(fitScores), Gap: \(gapScores), Final: \(savedJob.analysisScores.finalScore)")
            
            let analysisScores = AnalysisScores(
                fitScores: fitScores,
                gapScores: gapScores,
                finalScore: savedJob.analysisScores.finalScore
            )
            
            // Send response back to Safari extension
            let response = SafariAnalysisResponse(
                requestId: request.id,
                results: results,
                error: nil,
                timestamp: Date(),
                scores: analysisScores
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
                timestamp: Date(),
                scores: nil
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
            
            let cleanedJob = try await cleanJobDescriptionWithAI(request.jobDescription)
            
            let results: String
            
            if analysisMethod == "singleRun" {
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

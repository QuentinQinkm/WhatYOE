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
        
        // Always set up status bar and start monitoring
        setupStatusBar()
        startSafariAnalysisMonitoring()
        
        print("✅ Background service setup complete")
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
            button.image = NSImage(named: "StatusBarIcon")
            //button.font = NSFont.systemFont(ofSize: 16)
            //button.toolTip = "WhatYOE Background Service"
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
        // Use Guided Generation for structured resume extraction
        let session = LanguageModelSession(instructions: PromptTemplates.resumeCleaningPrompt)
        let prompt = PromptTemplates.createCleaningPrompt(text: text, isResume: true)
        let response = try await session.respond(to: prompt, generating: CleanedResume.self)
        
        // Convert structured data back to text for backward compatibility
        return formatCleanedResumeAsText(response.content)
    }
    
    private func formatCleanedResumeAsText(_ resume: CleanedResume) -> String {
        var text = ""
        
        // Contact Info
        text += "\(resume.contactInfo.name)\n"
        if let email = resume.contactInfo.email { text += "Email: \(email)\n" }
        if let phone = resume.contactInfo.phone { text += "Phone: \(phone)\n" }
        text += "\n"
        
        // Summary
        if let summary = resume.summary {
            text += "PROFESSIONAL SUMMARY\n\(summary)\n\n"
        }
        
        // Professional Experience
        text += "PROFESSIONAL EXPERIENCE\n\n"
        
        // Work Experience
        if !resume.professionalExperience.workExperience.isEmpty {
            text += "Work Experience\n"
            for exp in resume.professionalExperience.workExperience {
                text += "\(exp.role) at \(exp.company)\n"
                text += "\(exp.startDate) - \(exp.endDate ?? "Present")\n"
                for achievement in exp.keyAchievements {
                    text += "• \(achievement)\n"
                }
                text += "\n"
            }
        }
        
        // Other Experience
        if !resume.professionalExperience.otherExperience.isEmpty {
            text += "Other Experience\n"
            for exp in resume.professionalExperience.otherExperience {
                text += "\(exp.title)"
                if let org = exp.organization { text += " - \(org)" }
                text += " (\(exp.experienceType))\n"
                if let start = exp.startDate {
                    text += "\(start) - \(exp.endDate ?? "Present")\n"
                }
                text += "\(exp.description)\n"
                if !exp.technologiesUsed.isEmpty {
                    text += "Technologies: \(exp.technologiesUsed.joined(separator: ", "))\n"
                }
                for achievement in exp.achievements {
                    text += "• \(achievement)\n"
                }
                text += "\n"
            }
        }
        
        // Education
        if !resume.education.isEmpty {
            text += "EDUCATION\n"
            for edu in resume.education {
                text += "\(edu.degree)"
                if let field = edu.field { text += " in \(field)" }
                text += " - \(edu.institution)"
                if let year = edu.year { text += " (\(year))" }
                text += "\n"
            }
            text += "\n"
        }
        
        // Skills
        text += "SKILLS\n"
        if !resume.skills.technicalSkills.isEmpty {
            text += "Technical Skills: \(resume.skills.technicalSkills.joined(separator: ", "))\n"
        }
        if !resume.skills.professionalSkills.isEmpty {
            text += "Professional Skills: \(resume.skills.professionalSkills.joined(separator: ", "))\n"
        }
        if !resume.skills.industrySkills.isEmpty {
            text += "Industry Skills: \(resume.skills.industrySkills.joined(separator: ", "))\n"
        }
        text += "\n"
        
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    
    // MARK: - Job Analysis Server
    
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
            
            // Perform 4-round guided evaluation
            let evaluation = try await GuidedEvaluationService.performFourRoundGuidedEvaluation(
                resumeText: request.resumeText,
                jobDescription: cleanedJob
            )
            
            // Format and combine results
            let phaseResults = GuidedEvaluationService.formatFourRoundEvaluation(evaluation)
            let combinedResults = combineEvaluationResults(results: phaseResults)
            
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
        // Use Guided Generation for structured job description extraction
        let session = LanguageModelSession(instructions: PromptTemplates.jobCleaningPrompt)
        let prompt = PromptTemplates.createCleaningPrompt(text: text, isResume: false)
        let response = try await session.respond(to: prompt, generating: CleanedJobDescription.self)
        
        // Convert structured data back to text for backward compatibility
        return formatCleanedJobAsText(response.content)
    }
    
    private func formatCleanedJobAsText(_ job: CleanedJobDescription) -> String {
        var text = ""
        
        // Header
        text += "\(job.title) at \(job.company)\n\n"
        
        // Experience Requirements
        if let minYears = job.experienceRequired.minimumYears {
            text += "EXPERIENCE REQUIRED\n"
            text += "Minimum \(minYears) years - \(job.experienceRequired.level) level\n"
            if let industry = job.experienceRequired.industryContext {
                text += "Industry: \(industry)\n"
            }
            text += "\n"
        }
        
        // Education
        if let education = job.educationRequirements {
            text += "EDUCATION\n\(education)\n\n"
        }
        
        // Required Skills
        text += "REQUIRED SKILLS\n"
        if !job.requiredSkills.technicalSkills.isEmpty {
            text += "Technical Skills: \(job.requiredSkills.technicalSkills.joined(separator: ", "))\n"
        }
        if !job.requiredSkills.professionalSkills.isEmpty {
            text += "Professional Skills: \(job.requiredSkills.professionalSkills.joined(separator: ", "))\n"
        }
        if !job.requiredSkills.industrySkills.isEmpty {
            text += "Industry Skills: \(job.requiredSkills.industrySkills.joined(separator: ", "))\n"
        }
        text += "\n"
        
        // Preferred Skills
        if let preferred = job.preferredSkills, 
           !preferred.technicalSkills.isEmpty || !preferred.professionalSkills.isEmpty || !preferred.industrySkills.isEmpty {
            text += "PREFERRED SKILLS\n"
            if !preferred.technicalSkills.isEmpty {
                text += "Technical Skills: \(preferred.technicalSkills.joined(separator: ", "))\n"
            }
            if !preferred.professionalSkills.isEmpty {
                text += "Professional Skills: \(preferred.professionalSkills.joined(separator: ", "))\n"
            }
            if !preferred.industrySkills.isEmpty {
                text += "Industry Skills: \(preferred.industrySkills.joined(separator: ", "))\n"
            }
            text += "\n"
        }
        
        
        // Responsibilities
        if !job.responsibilities.isEmpty {
            text += "\nRESPONSIBILITIES\n"
            for resp in job.responsibilities {
                text += "• \(resp)\n"
            }
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
                
                print("🧹 Found pending resume cleaning request: \(request.id)")
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
                // Use comprehensive guided evaluation
                print("🚀 Using comprehensive guided evaluation")
                let evaluation = try await GuidedEvaluationService.performComprehensiveGuidedEvaluation(
                    resumeText: request.resumeText,
                    jobDescription: cleanedJob
                )
                results = GuidedEvaluationService.formatComprehensiveEvaluation(evaluation)
            } else {
                // Use four-round guided evaluation
                print("🔄 Using four-round guided evaluation")
                let evaluation = try await GuidedEvaluationService.performFourRoundGuidedEvaluation(
                    resumeText: request.resumeText,
                    jobDescription: cleanedJob
                )
                let phaseResults = GuidedEvaluationService.formatFourRoundEvaluation(evaluation)
                results = combineEvaluationResults(results: phaseResults)
            }
            
            // Save the job analysis result
            let activeResumeId = ResumeManager.shared.getActiveResumeId() ?? "unknown"
            let jobTitle = request.jobTitle ?? "Unknown Position"
            let company = request.company ?? "Unknown Company"
            let linkedinJobId = sharedDefaults.string(forKey: "currentLinkedInJobId") ?? "unknown"
            
            let savedJob = JobManager.shared.createJobFromSafariAnalysis(
                jobTitle: jobTitle,
                company: company,
                cleanedJobDescription: cleanedJob,
                analysisResult: results,
                resumeId: activeResumeId,
                linkedinJobId: linkedinJobId
            )
            
            print("💼 Job saved with ID: \(savedJob.jobId)")
            
            // Notify desktop app of new job via shared storage
            let newJobNotification = [
                "jobId": savedJob.jobId,
                "resumeId": activeResumeId,
                "timestamp": Date().timeIntervalSince1970
            ] as [String : Any]
            sharedDefaults.set(newJobNotification, forKey: "newJobNotification")
            print("🔔 [Backend] Signaled new job to desktop app: \(savedJob.jobId)")
            
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
                // Use comprehensive guided evaluation
                print("🚀 Using comprehensive guided evaluation")
                
                let evaluation = try await GuidedEvaluationService.performComprehensiveGuidedEvaluation(
                    resumeText: request.resumeText,
                    jobDescription: cleanedJob
                )
                results = GuidedEvaluationService.formatComprehensiveEvaluation(evaluation)
            } else {
                // Use four-round guided evaluation
                print("🔄 Using four-round guided evaluation")
                
                let evaluation = try await GuidedEvaluationService.performFourRoundGuidedEvaluation(
                    resumeText: request.resumeText,
                    jobDescription: cleanedJob
                )
                let phaseResults = GuidedEvaluationService.formatFourRoundEvaluation(evaluation)
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
        let desktopAppName = "WhatYOE-Desktop.app"
        
        // Search locations in priority order
        let searchPaths = [
            // 1. Same bundle directory (for production builds)
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(desktopAppName),
            
            // 2. Xcode DerivedData (for development builds)
            URL(fileURLWithPath: "/Users/kuangmingqin/Library/Developer/Xcode/DerivedData/WhatYOE-bcfbmdhcazdaqphjlkdutbkjazjw/Build/Products/Debug/\(desktopAppName)"),
            
            // 3. Applications folder
            FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first?.appendingPathComponent(desktopAppName)
        ].compactMap { $0 }
        
        // Return the first existing app
        for url in searchPaths {
            if FileManager.default.fileExists(atPath: url.path) {
                print("🔍 Found desktop app at: \(url.path)")
                return url
            }
        }
        
        print("❌ Desktop app not found in any of these locations:")
        for url in searchPaths {
            print("   - \(url.path)")
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

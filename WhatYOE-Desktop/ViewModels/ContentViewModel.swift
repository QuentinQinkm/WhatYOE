import SwiftUI
import Combine
import PDFKit
import UniformTypeIdentifiers

enum JobSortOrder: String, CaseIterable {
    case time = "Time"
    case score = "Score"
}

@MainActor
class ContentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var resumes: [ResumeItem] = []
    @Published var selectedResume: ResumeItem?
    @Published var selectedTab = 0
    @Published var pendingResumeData: PendingResumeData?
    @Published var jobs: [JobItem] = []
    @Published var selectedJob: JobItem?
    @Published var renamingResume: ResumeItem?
    @Published var renameText = ""
    @Published var selectedResumeIdForJobs: String? = nil
    @Published var resumeOptionsForJobs: [(id: String, name: String)] = []
    
    // MARK: - Private Properties
    private let resumeManager = ResumeManager.shared
    private let jobManager = JobManager.shared
    private var lastJobCount = 0
    @Published var hasNewJobs = false
    @Published var sortOrder: JobSortOrder = .time
    private var resumeNameCache: [String: String] = [:]  // Store resume names persistently
    private var lastNotificationTimestamp: Double = 0
    private var notificationTimer: Timer?
    
    // MARK: - Initialization
    init() {
        loadResumeNameCache()
        loadResumes()
        loadJobs()
        loadResumeOptionsForJobs()
        setupNotifications()
        startNotificationMonitoring()
    }
    
    deinit {
        notificationTimer?.invalidate()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        // Listen for manual job updates (existing)
        NotificationCenter.default.addObserver(
            forName: Notification.Name("JobsUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadJobs()
        }
        
        // Note: Cross-process NotificationCenter doesn't work - using shared UserDefaults monitoring instead
    }
    
    private func startNotificationMonitoring() {
        // Monitor shared UserDefaults for new job notifications every 2 seconds
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForNewJobNotifications()
            }
        }
        print("🔄 [Desktop] Started notification monitoring")
    }
    
    private func checkForNewJobNotifications() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        
        guard let notification = sharedDefaults.dictionary(forKey: "newJobNotification"),
              let jobId = notification["jobId"] as? String,
              let resumeId = notification["resumeId"] as? String,
              let timestamp = notification["timestamp"] as? Double else {
            return
        }
        
        // Only process if this is a new notification
        if timestamp > lastNotificationTimestamp {
            lastNotificationTimestamp = timestamp
            handleNewJobAdded(jobId: jobId, resumeId: resumeId)
        }
    }
    
    private func handleNewJobAdded(jobId: String, resumeId: String) {
        print("🔔 [Desktop] New job notification received: \(jobId) for resume: \(resumeId)")
        
        // Check if this job affects current view
        let shouldShowNotification = selectedResumeIdForJobs == nil || selectedResumeIdForJobs == resumeId
        
        if shouldShowNotification {
            hasNewJobs = true
            print("🔔 [Desktop] Showing green dot - new job affects current view")
        }
    }
    
    
    // MARK: - Data Loading
    func loadResumes() {
        resumes = resumeManager.getAllResumes()
        updateResumeNameCache()  // Update cache whenever resumes are loaded
    }
    
    func loadJobs() {
        if let selectedResumeId = selectedResumeIdForJobs {
            jobs = jobManager.getJobsForResume(resumeId: selectedResumeId)
            print("🔍 [Desktop] Loading jobs for resume: \(selectedResumeId), found: \(jobs.count)")
        } else {
            jobs = jobManager.getAllJobs()
            print("🔍 [Desktop] Loading all jobs, found: \(jobs.count)")
        }
        
        lastJobCount = jobs.count
        
        if selectedJob == nil && !jobs.isEmpty {
            selectedJob = jobs.first
        }
    }
    
    // MARK: - Manual Refresh
    func refreshData() {
        print("🔄 [Desktop] Manual refresh triggered")
        loadJobs()
        loadResumeOptionsForJobs()
        hasNewJobs = false // Clear the notification dot
    }
    
    // MARK: - Cleanup
    func removeAllJobsAndCaches() {
        // Remove all job files
        jobManager.removeAllJobs()
        
        // Clear resume name cache
        clearResumeNameCache()
        
        // Refresh the UI
        loadJobs()
        loadResumeOptionsForJobs()
        
        print("🧹 [Desktop] Removed all jobs and cleared all caches")
    }
    
    // MARK: - Sorting
    func changeSortOrder(_ newOrder: JobSortOrder) {
        sortOrder = newOrder
        print("🔄 [Desktop] Sort order changed to: \(newOrder.rawValue)")
    }
    
    // MARK: - Navigation
    func jumpToResume(withId resumeId: String) {
        // Find the resume and select it
        if let resume = resumes.first(where: { $0.id == resumeId }) {
            selectedResume = resume
            selectedTab = 1 // Switch to Resume tab
            print("🎯 [Desktop] Jumping to resume: \(resume.name)")
        }
    }
    
    // MARK: - Resume Name Cache Management
    private func loadResumeNameCache() {
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.data(forKey: "resumeNameCache"),
           let cache = try? JSONDecoder().decode([String: String].self, from: data) {
            resumeNameCache = cache
            print("🔍 [Desktop] Loaded resume name cache: \(resumeNameCache)")
        }
    }
    
    private func saveResumeNameCache() {
        let userDefaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(resumeNameCache) {
            userDefaults.set(data, forKey: "resumeNameCache")
            print("💾 [Desktop] Saved resume name cache")
        }
    }
    
    private func clearResumeNameCache() {
        resumeNameCache.removeAll()
        UserDefaults.standard.removeObject(forKey: "resumeNameCache")
        print("🧹 [Desktop] Cleared resume name cache")
    }
    
    private func updateResumeNameCache() {
        for resume in resumes {
            resumeNameCache[resume.id] = resume.name
        }
        saveResumeNameCache()
    }

    func loadResumeOptionsForJobs() {
        let resumeIds = jobManager.getAllResumeIdsWithJobs()
        print("🔍 [Desktop] Found resume IDs with jobs: \(resumeIds)")
        
        resumeOptionsForJobs = resumeIds.compactMap { resumeId in
            // First try to find in current resumes
            if let resume = resumes.first(where: { $0.id == resumeId }) {
                print("🔍 [Desktop] Matched resume: \(resumeId) -> \(resume.name)")
                return (id: resumeId, name: resume.name)
            }
            // Then try cached name for deleted resumes
            else if let cachedName = resumeNameCache[resumeId] {
                print("🔍 [Desktop] Using cached name for deleted resume: \(resumeId) -> \(cachedName)")
                return (id: resumeId, name: "\(cachedName) (deleted)")
            }
            // Fallback to ID
            else {
                print("🔍 [Desktop] No name found for ID: \(resumeId), using fallback")
                return (id: resumeId, name: "Resume \(resumeId.prefix(8))")
            }
        }
        print("🔍 [Desktop] Final resume options: \(resumeOptionsForJobs)")
    }
    
    func onResumeSelectionChanged(_ resumeId: String?) {
        selectedResumeIdForJobs = resumeId
        loadJobs()
        // Reset job selection when changing resume filter
        selectedJob = jobs.first
    }
    
    // MARK: - Label Text
    func getLabelText() -> String {
        switch selectedTab {
        case 0:
            return selectedJob != nil ? "Job Analysis Report" : ""
        case 1:
            return pendingResumeData != nil ? "Raw Resume Content" : (selectedResume != nil ? "Cleaned Resume Content" : "")
        case 2:
            return "Analysis Results"
        default:
            return ""
        }
    }
    
    // MARK: - Resume Operations
    func importResume() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Resume"
        openPanel.allowedContentTypes = [.pdf]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK {
            guard let url = openPanel.url else { return }
            
            Task {
                do {
                    let rawText = try resumeManager.extractTextFromPDF(url: url)
                    let fileName = url.deletingPathExtension().lastPathComponent
                    
                    await MainActor.run {
                        pendingResumeData = PendingResumeData(
                            fileName: fileName,
                            rawText: rawText,
                            url: url
                        )
                        selectedTab = 1
                    }
                } catch {
                    print("❌ Failed to extract text from PDF: \(error)")
                }
            }
        }
    }
    
    func proceedWithLLM() {
        guard var pendingData = pendingResumeData else { return }
        
        pendingData.isProcessing = true
        pendingResumeData = pendingData
        
        Task {
            do {
                let cleanedText = try await resumeManager.cleanResumeText(pendingData.rawText)
                
                await MainActor.run {
                    var updatedData = pendingData
                    updatedData.cleanedText = cleanedText
                    updatedData.isProcessing = false
                    pendingResumeData = updatedData
                }
            } catch {
                await MainActor.run {
                    var updatedData = pendingData
                    updatedData.isProcessing = false
                    pendingResumeData = updatedData
                    print("❌ Failed to clean resume text: \(error)")
                }
            }
        }
    }
    
    func saveProcessedResume() {
        guard let pendingData = pendingResumeData,
              let cleanedText = pendingData.cleanedText else { return }
        
        let resume = ResumeItem(
            name: pendingData.fileName,
            cleanedText: cleanedText
        )
        
        resumeManager.saveResume(resume)
        loadResumes()
        
        pendingResumeData = nil
        selectedResume = resume
    }
    
    func cancelImport() {
        pendingResumeData = nil
    }
    
    func deleteResume(_ resume: ResumeItem) {
        resumeManager.deleteResume(withId: resume.id)
        loadResumes()
    }
    
    func startRename(_ resume: ResumeItem) {
        renamingResume = resume
        renameText = resume.name
    }
    
    func saveRename() {
        guard let resume = renamingResume else { return }
        
        let updatedResume = ResumeItem(
            id: resume.id,
            name: renameText.trimmingCharacters(in: .whitespacesAndNewlines),
            cleanedText: resume.cleanedText,
            dateCreated: resume.dateCreated
        )
        
        resumeManager.updateResume(updatedResume)
        loadResumes()
        
        if selectedResume?.id == resume.id {
            selectedResume = updatedResume
        }
        
        renamingResume = nil
        renameText = ""
    }
    
    func cancelRename() {
        renamingResume = nil
        renameText = ""
    }
    
    // MARK: - Job Operations
    func deleteJob(_ job: JobItem) {
        jobManager.deleteJob(withId: job.jobId)
        loadJobs()
        
        if selectedJob?.jobId == job.jobId {
            selectedJob = jobs.first
        }
    }
}
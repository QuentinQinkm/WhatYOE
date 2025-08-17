import SwiftUI
import Combine
import PDFKit
import UniformTypeIdentifiers

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
    
    // MARK: - Initialization
    init() {
        loadResumes()
        loadJobs()
        loadResumeOptionsForJobs()
        setupNotifications()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("JobsUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadJobs()
        }
    }
    
    // MARK: - Data Loading
    func loadResumes() {
        resumes = resumeManager.getAllResumes()
    }
    
    func loadJobs() {
        if let selectedResumeId = selectedResumeIdForJobs {
            jobs = jobManager.getJobsForResume(resumeId: selectedResumeId)
            print("🔍 [Desktop] Loading jobs for resume: \(selectedResumeId), found: \(jobs.count)")
        } else {
            jobs = jobManager.getAllJobs()
            print("🔍 [Desktop] Loading all jobs, found: \(jobs.count)")
        }
        
        if selectedJob == nil && !jobs.isEmpty {
            selectedJob = jobs.first
        }
    }
    
    func loadResumeOptionsForJobs() {
        let resumeIds = jobManager.getAllResumeIdsWithJobs()
        print("🔍 [Desktop] Found resume IDs with jobs: \(resumeIds)")
        print("🔍 [Desktop] Available resumes: \(resumes.map { $0.id })")
        
        resumeOptionsForJobs = resumeIds.compactMap { resumeId in
            if let resume = resumes.first(where: { $0.id == resumeId }) {
                print("🔍 [Desktop] Matched resume: \(resumeId) -> \(resume.name)")
                return (id: resumeId, name: resume.name)
            } else {
                print("🔍 [Desktop] No resume found for ID: \(resumeId), using fallback name")
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
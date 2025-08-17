//
//  JobManager.swift
//  WhatYOE
//
//  Job storage and management functionality for analyzed jobs from Safari extension
//

import Foundation
import os.log

// MARK: - Job Data Models

struct JobAnalysisScores {
    let yearsOfExperienceFit: Double
    let yearsOfExperienceGap: Double
    let educationFit: Double
    let educationGap: Double
    let technicalSkillsFit: Double
    let technicalSkillsGap: Double
    let relevantExperienceFit: Double
    let relevantExperienceGap: Double
    let finalScore: Double
    
    init(yearsOfExperienceFit: Double = 0.0,
         yearsOfExperienceGap: Double = 0.0,
         educationFit: Double = 0.0,
         educationGap: Double = 0.0,
         technicalSkillsFit: Double = 0.0,
         technicalSkillsGap: Double = 0.0,
         relevantExperienceFit: Double = 0.0,
         relevantExperienceGap: Double = 0.0,
         finalScore: Double = 0.0) {
        self.yearsOfExperienceFit = yearsOfExperienceFit
        self.yearsOfExperienceGap = yearsOfExperienceGap
        self.educationFit = educationFit
        self.educationGap = educationGap
        self.technicalSkillsFit = technicalSkillsFit
        self.technicalSkillsGap = technicalSkillsGap
        self.relevantExperienceFit = relevantExperienceFit
        self.relevantExperienceGap = relevantExperienceGap
        self.finalScore = finalScore
    }
}

struct JobItem {
    let jobId: String                    // LinkedIn job ID (e.g., "4242941130")
    let jobTitle: String
    let company: String
    let cleanedJobDescription: String
    let analysisResult: String
    let analysisScores: JobAnalysisScores
    let resumeId: String  // ID of the resume used for analysis
    let dateAnalyzed: Date
    
    init(jobTitle: String,
         company: String,
         cleanedJobDescription: String,
         analysisResult: String,
         analysisScores: JobAnalysisScores,
         resumeId: String,
         linkedinJobId: String) {
        self.jobId = linkedinJobId  // Use LinkedIn job ID instead of UUID
        self.jobTitle = jobTitle
        self.company = company
        self.cleanedJobDescription = cleanedJobDescription
        self.analysisResult = analysisResult
        self.analysisScores = analysisScores
        self.resumeId = resumeId
        self.dateAnalyzed = Date()
    }
    
    init(jobId: String,
         jobTitle: String,
         company: String,
         cleanedJobDescription: String,
         analysisResult: String,
         analysisScores: JobAnalysisScores,
         resumeId: String,
         dateAnalyzed: Date) {
        self.jobId = jobId
        self.jobTitle = jobTitle
        self.company = company
        self.cleanedJobDescription = cleanedJobDescription
        self.analysisResult = analysisResult
        self.analysisScores = analysisScores
        self.resumeId = resumeId
        self.dateAnalyzed = dateAnalyzed
    }
}

extension JobAnalysisScores: Codable {}
extension JobItem: Codable {}

// MARK: - Job Manager for WhatYOE Background Server

class JobManager {
    static let shared = JobManager()
    
    private init() {}
    
    // MARK: - Core Job Management
    
    func getAllJobs() -> [JobItem] {
        var allJobs: [JobItem] = []
        
        // Get all resume IDs with jobs
        let resumeIds = FileManager.getAllResumeIdsWithJobs()
        
        for resumeId in resumeIds {
            let jobIds = FileManager.getJobIds(forResumeId: resumeId)
            
            for jobId in jobIds {
                if let job = loadJob(resumeId: resumeId, jobId: jobId) {
                    allJobs.append(job)
                }
            }
        }
        
        return allJobs.sorted { $0.dateAnalyzed > $1.dateAnalyzed }
    }
    
    func getJobsForResume(resumeId: String) -> [JobItem] {
        var jobs: [JobItem] = []
        let jobIds = FileManager.getJobIds(forResumeId: resumeId)
        
        for jobId in jobIds {
            if let job = loadJob(resumeId: resumeId, jobId: jobId) {
                jobs.append(job)
            }
        }
        
        return jobs.sorted { $0.dateAnalyzed > $1.dateAnalyzed }
    }
    
    func saveJob(_ job: JobItem) {
        print("🔍 [Backend JobManager] Attempting to save job: \(job.jobTitle) with resumeId: \(job.resumeId) and jobId: \(job.jobId)")
        
        // Debug: Show the base directory being used
        if let baseDir = FileManager.getJobsBaseDirectory() {
            print("🔍 [Backend JobManager] Using base directory: \(baseDir.path)")
        } else {
            print("❌ [Backend JobManager] Could not determine base directory")
        }
        
        guard let filePath = FileManager.getJobFilePath(resumeId: job.resumeId, jobId: job.jobId) else {
            print("❌ [Backend JobManager] Failed to get file path for job: \(job.jobTitle)")
            os_log(.error, "💼 Failed to get file path for job: %@", job.jobTitle)
            return
        }
        
        print("🔍 [Backend JobManager] Full file path: \(filePath.path)")
        print("🔍 [Backend JobManager] Parent directory exists: \(FileManager.default.fileExists(atPath: filePath.deletingLastPathComponent().path))")
        
        do {
            let data = try JSONEncoder().encode(job)
            try data.write(to: filePath)
            print("✅ [Backend JobManager] Job saved successfully to: \(filePath.path)")
            print("🔍 [Backend JobManager] File size: \(data.count) bytes")
            os_log(.info, "💼 Job saved: %@ at %@ (File: %@)", job.jobTitle, job.company, filePath.lastPathComponent)
            
            // Verify file was actually written
            if FileManager.default.fileExists(atPath: filePath.path) {
                print("✅ [Backend JobManager] File verification: Job file exists on disk")
            } else {
                print("❌ [Backend JobManager] File verification: Job file NOT found on disk")
            }
            
            // Notify desktop app of job updates
            NotificationCenter.default.post(name: Notification.Name("JobsUpdated"), object: nil)
        } catch {
            print("❌ [Backend JobManager] Failed to save job: \(job.jobTitle) - Error: \(error)")
            os_log(.error, "💼 Failed to save job: %@ - Error: %@", job.jobTitle, error.localizedDescription)
        }
    }
    
    func deleteJob(withId jobId: String) {
        // Find the job first to get its resumeId
        guard let job = getJob(withId: jobId),
              let filePath = FileManager.getJobFilePath(resumeId: job.resumeId, jobId: jobId) else {
            os_log(.error, "💼 Failed to find job for deletion: %@", jobId)
            return
        }
        
        do {
            try FileManager.default.removeItem(at: filePath)
            os_log(.info, "💼 Job deleted: %@", jobId)
            
            // Notify desktop app of job updates
            NotificationCenter.default.post(name: Notification.Name("JobsUpdated"), object: nil)
        } catch {
            os_log(.error, "💼 Failed to delete job: %@ - Error: %@", jobId, error.localizedDescription)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func loadJob(resumeId: String, jobId: String) -> JobItem? {
        guard let filePath = FileManager.getJobFilePath(resumeId: resumeId, jobId: jobId) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: filePath)
            let job = try JSONDecoder().decode(JobItem.self, from: data)
            return job
        } catch {
            os_log(.error, "💼 Failed to load job %@/%@: %@", resumeId, jobId, error.localizedDescription)
            return nil
        }
    }
    
    func getJob(withId jobId: String) -> JobItem? {
        return getAllJobs().first { $0.jobId == jobId }
    }
    
    // MARK: - Analysis Result Processing
    
    func createJobFromSafariAnalysis(jobTitle: String,
                                   company: String,
                                   cleanedJobDescription: String,
                                   analysisResult: String,
                                   resumeId: String,
                                   linkedinJobId: String) -> JobItem {
        
        print("🔍 [Backend JobManager] createJobFromSafariAnalysis called")
        print("🔍 [Backend JobManager] Job Title: \(jobTitle)")
        print("🔍 [Backend JobManager] Company: \(company)")
        print("🔍 [Backend JobManager] Resume ID: \(resumeId)")
        print("🔍 [Backend JobManager] LinkedIn Job ID: \(linkedinJobId)")
        
        // Extract scores from analysis result
        let scores = extractScoresFromAnalysisResult(analysisResult)
        
        // Create and save job
        let job = JobItem(
            jobTitle: jobTitle,
            company: company,
            cleanedJobDescription: cleanedJobDescription,
            analysisResult: analysisResult,
            analysisScores: scores,
            resumeId: resumeId,
            linkedinJobId: linkedinJobId
        )
        
        print("🔍 [Backend JobManager] Job created, now calling saveJob...")
        saveJob(job)
        print("🔍 [Backend JobManager] Job save completed, returning job")
        return job
    }
    
    private func extractScoresFromAnalysisResult(_ result: String) -> JobAnalysisScores {
        // Parse the analysis result to extract all 8 scores plus final score
        // Using centralized ScoreCalculator methods
        
        let yearsExpFit = ScoreCalculator.extractScore(from: result, type: "Fit Score", section: "YEARS OF EXPERIENCE")
        let yearsExpGap = ScoreCalculator.extractScore(from: result, type: "Gap Score", section: "YEARS OF EXPERIENCE")
        
        let educationFit = ScoreCalculator.extractScore(from: result, type: "Fit Score", section: "EDUCATION")
        let educationGap = ScoreCalculator.extractScore(from: result, type: "Gap Score", section: "EDUCATION")
        
        let techSkillsFit = ScoreCalculator.extractScore(from: result, type: "Fit Score", section: "TECHNICAL SKILLS")
        let techSkillsGap = ScoreCalculator.extractScore(from: result, type: "Gap Score", section: "TECHNICAL SKILLS")
        
        let relevantExpFit = ScoreCalculator.extractScore(from: result, type: "Fit Score", section: "RELEVANT EXPERIENCE")
        let relevantExpGap = ScoreCalculator.extractScore(from: result, type: "Gap Score", section: "RELEVANT EXPERIENCE")
        
        // Calculate final score using centralized logic - only include valid scores (>0.0)
        let allFitScores = [yearsExpFit, educationFit, techSkillsFit, relevantExpFit]
        let allGapScores = [yearsExpGap, educationGap, techSkillsGap, relevantExpGap]
        
        let fitScores = allFitScores.filter { $0 > 0.0 }
        let gapScores = allGapScores.filter { $0 > 0.0 }
        
        let finalScore = ScoreCalculator.calculateFinalScore(fitScores: fitScores, gapScores: gapScores)
        
        return JobAnalysisScores(
            yearsOfExperienceFit: yearsExpFit,
            yearsOfExperienceGap: yearsExpGap,
            educationFit: educationFit,
            educationGap: educationGap,
            technicalSkillsFit: techSkillsFit,
            technicalSkillsGap: techSkillsGap,
            relevantExperienceFit: relevantExpFit,
            relevantExperienceGap: relevantExpGap,
            finalScore: finalScore
        )
    }
    
    // Score extraction now handled by ScoreCalculator
    
    // MARK: - Filtering and Search
    
    func getAllResumeIdsWithJobs() -> [String] {
        return FileManager.getAllResumeIdsWithJobs()
    }
    
    func getJobsByCompany(_ company: String) -> [JobItem] {
        return getAllJobs().filter { $0.company.lowercased().contains(company.lowercased()) }
    }
    
    func getJobsByScore(minimumScore: Double) -> [JobItem] {
        return getAllJobs().filter { $0.analysisScores.finalScore >= minimumScore }
    }
    
    func searchJobs(query: String) -> [JobItem] {
        let lowercaseQuery = query.lowercased()
        return getAllJobs().filter { job in
            job.jobTitle.lowercased().contains(lowercaseQuery) ||
            job.company.lowercased().contains(lowercaseQuery) ||
            job.cleanedJobDescription.lowercased().contains(lowercaseQuery)
        }
    }
    
    // MARK: - Statistics
    
    func getJobStatistics() -> (totalJobs: Int, averageScore: Double, topCompanies: [String]) {
        let jobs = getAllJobs()
        let totalJobs = jobs.count
        
        let averageScore = jobs.isEmpty ? 0.0 : jobs.map { $0.analysisScores.finalScore }.reduce(0, +) / Double(jobs.count)
        
        let companyFrequency = Dictionary(grouping: jobs, by: { $0.company })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        let topCompanies = Array(companyFrequency.prefix(5).map { $0.key })
        
        return (totalJobs: totalJobs, averageScore: averageScore, topCompanies: topCompanies)
    }
}
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
    let finalScore: Double
    
    // 5-variable system fields (current active system)
    let exp_score: Int      // Experience score (0-4) from LLM
    let edu_score: Int      // Education score (0-4) from LLM
    let skill_score: Int    // Skills score (0-4) from LLM
    let actual_yoe: Double  // Parsed actual YOE (0-8)
    let required_yoe: Double // Parsed required YOE (0-8)
    
    init(finalScore: Double = 0.0, 
         exp_score: Int = 0, 
         edu_score: Int = 0, 
         skill_score: Int = 0, 
         actual_yoe: Double = 0.0, 
         required_yoe: Double = 0.0) {
        self.finalScore = finalScore
        self.exp_score = exp_score
        self.edu_score = edu_score
        self.skill_score = skill_score
        self.actual_yoe = actual_yoe
        self.required_yoe = required_yoe
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
    
    func createJobFromSafariAnalysisWithScores(jobTitle: String,
                                             company: String,
                                             cleanedJobDescription: String,
                                             analysisResult: String,
                                             analysisScores: JobAnalysisScores,
                                             resumeId: String,
                                             linkedinJobId: String) -> JobItem {
        
        print("🔍 [Backend JobManager] createJobFromSafariAnalysisWithScores called")
        print("🔍 [Backend JobManager] Job Title: \(jobTitle)")
        print("🔍 [Backend JobManager] Company: \(company)")
        print("🔍 [Backend JobManager] Resume ID: \(resumeId)")
        print("🔍 [Backend JobManager] LinkedIn Job ID: \(linkedinJobId)")
        
        // Create and save job with provided scores
        let job = JobItem(
            jobTitle: jobTitle,
            company: company,
            cleanedJobDescription: cleanedJobDescription,
            analysisResult: analysisResult,
            analysisScores: analysisScores,
            resumeId: resumeId,
            linkedinJobId: linkedinJobId
        )
        
        print("🔍 [Backend JobManager] Job created with new 5-variable scores, now calling saveJob...")
        saveJob(job)
        print("🔍 [Backend JobManager] Job save completed, returning job")
        return job
    }
    
    private func extractScoresFromAnalysisResult(_ result: String) -> JobAnalysisScores {
        // Extract final score from formatted result, set others to 0
        // This method handles the current 5-variable system format
        let pattern = "Final Score:\\s*([0-9]+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            if let match = regex.firstMatch(in: result, options: [], range: range) {
                let scoreRange = match.range(at: 1)
                if let r = Range(scoreRange, in: result) {
                    let scoreString = String(result[r])
                    if let scoreInt = Int(scoreString) {
                        let finalScore = Double(scoreInt)
                        return JobAnalysisScores(finalScore: finalScore)
                    }
                }
            }
        }
        // Fallback to zeros if not matched
        return JobAnalysisScores(finalScore: 0)
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
    
    // MARK: - Job Lookup by LinkedIn ID
    func getJobByLinkedInId(_ linkedinJobId: String, resumeId: String) -> JobItem? {
        // Check if job exists for specific resume
        let resumeJobs = getJobsForResume(resumeId: resumeId)
        return resumeJobs.first { $0.jobId == linkedinJobId }
    }
}
//
//  JobManager.swift
//  WhatYOE-Desktop
//
//  Job storage and management functionality - Desktop version
//

import Foundation
import os.log

// Note: These data models should match the main WhatYOE JobManager exactly

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

// MARK: - Job Manager for Desktop Interface (Read-Only)

class JobManager {
    static let shared = JobManager()
    
    private init() {}
    
    // MARK: - Read Operations (Desktop UI focuses on viewing)
    
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
    
    func getJob(withId jobId: String) -> JobItem? {
        return getAllJobs().first { $0.jobId == jobId }
    }
    
    func getAllResumeIdsWithJobs() -> [String] {
        return FileManager.getAllResumeIdsWithJobs()
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
            print("❌ Failed to load job \(resumeId)/\(jobId): \(error)")
            return nil
        }
    }
    
    // MARK: - Filtering and Search (for Desktop UI)
    
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
    
    // MARK: - Write Operations (for context menu actions)
    
    func deleteJob(withId jobId: String) {
        // Find the job first to get its resumeId
        guard let job = getJob(withId: jobId),
              let filePath = FileManager.getJobFilePath(resumeId: job.resumeId, jobId: jobId) else {
            print("❌ Failed to find job for deletion: \(jobId)")
            return
        }
        
        do {
            try FileManager.default.removeItem(at: filePath)
            print("✅ Job deleted: \(jobId)")
        } catch {
            print("❌ Failed to delete job: \(jobId) - Error: \(error)")
        }
    }
    
    func removeAllJobs() {
        let resumeIds = FileManager.getAllResumeIdsWithJobs()
        var deletedCount = 0
        var errorCount = 0
        
        for resumeId in resumeIds {
            let jobIds = FileManager.getJobIds(forResumeId: resumeId)
            
            for jobId in jobIds {
                guard let filePath = FileManager.getJobFilePath(resumeId: resumeId, jobId: jobId) else {
                    errorCount += 1
                    continue
                }
                
                do {
                    try FileManager.default.removeItem(at: filePath)
                    deletedCount += 1
                } catch {
                    print("❌ Failed to delete job \(resumeId)/\(jobId): \(error)")
                    errorCount += 1
                }
            }
            
            // Clean up empty resume directories
            if let resumeDir = FileManager.getResumeJobsDirectory(resumeId: resumeId),
               (try? FileManager.default.contentsOfDirectory(atPath: resumeDir.path))?.isEmpty == true {
                try? FileManager.default.removeItem(at: resumeDir)
            }
        }
        
        print("✅ Removed \(deletedCount) jobs with \(errorCount) errors")
    }
    
    // MARK: - Utility Methods
    
    func refreshJobList() {
        // Trigger a refresh of the job list for UI updates
        // This could notify observers or reload data
    }
    
    // MARK: - Job Lookup by LinkedIn ID
    func getJobByLinkedInId(_ linkedinJobId: String, resumeId: String) -> JobItem? {
        // Check if job exists for specific resume
        let resumeJobs = getJobsForResume(resumeId: resumeId)
        return resumeJobs.first { $0.jobId == linkedinJobId }
    }
}
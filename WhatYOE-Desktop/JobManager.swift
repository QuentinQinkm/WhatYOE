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
    let jobId: String
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
         resumeId: String) {
        self.jobId = UUID().uuidString
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
    private let userDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
    private let jobsKey = "savedJobs"
    
    private init() {}
    
    // MARK: - Read Operations (Desktop UI focuses on viewing)
    
    func getAllJobs() -> [JobItem] {
        guard let data = userDefaults.data(forKey: jobsKey),
              let jobs = try? JSONDecoder().decode([JobItem].self, from: data) else {
            return []
        }
        return jobs.sorted { $0.dateAnalyzed > $1.dateAnalyzed }
    }
    
    func getJob(withId jobId: String) -> JobItem? {
        return getAllJobs().first { $0.jobId == jobId }
    }
    
    // MARK: - Filtering and Search (for Desktop UI)
    
    func getJobsForResume(resumeId: String) -> [JobItem] {
        return getAllJobs().filter { $0.resumeId == resumeId }
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
        var jobs = getAllJobs()
        jobs.removeAll { $0.jobId == jobId }
        
        if let data = try? JSONEncoder().encode(jobs) {
            userDefaults.set(data, forKey: jobsKey)
            userDefaults.synchronize()
        }
    }
    
    // MARK: - Utility Methods
    
    func refreshJobList() {
        // Trigger a refresh of the job list for UI updates
        // This could notify observers or reload data
    }
}
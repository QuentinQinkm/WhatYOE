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

// MARK: - Job Manager for WhatYOE Background Server

class JobManager {
    static let shared = JobManager()
    private let userDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
    private let jobsKey = "savedJobs"
    
    private init() {}
    
    // MARK: - Core Job Management
    
    func getAllJobs() -> [JobItem] {
        guard let data = userDefaults.data(forKey: jobsKey),
              let jobs = try? JSONDecoder().decode([JobItem].self, from: data) else {
            return []
        }
        return jobs.sorted { $0.dateAnalyzed > $1.dateAnalyzed }
    }
    
    func saveJob(_ job: JobItem) {
        var jobs = getAllJobs()
        
        // Remove any existing job with the same jobId
        jobs.removeAll { $0.jobId == job.jobId }
        
        // Add the new job
        jobs.append(job)
        
        // Keep only the latest 100 jobs to prevent storage bloat
        if jobs.count > 100 {
            jobs = Array(jobs.sorted { $0.dateAnalyzed > $1.dateAnalyzed }.prefix(100))
        }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(jobs) {
            userDefaults.set(data, forKey: jobsKey)
            userDefaults.synchronize()
            os_log(.info, "💼 Job saved: %@ at %@", job.jobTitle, job.company)
            
            // Notify desktop app of job updates
            NotificationCenter.default.post(name: Notification.Name("JobsUpdated"), object: nil)
        } else {
            os_log(.error, "💼 Failed to encode and save job: %@", job.jobTitle)
        }
    }
    
    func deleteJob(withId jobId: String) {
        var jobs = getAllJobs()
        jobs.removeAll { $0.jobId == jobId }
        
        if let data = try? JSONEncoder().encode(jobs) {
            userDefaults.set(data, forKey: jobsKey)
            userDefaults.synchronize()
            os_log(.info, "💼 Job deleted: %@", jobId)
            
            // Notify desktop app of job updates
            NotificationCenter.default.post(name: Notification.Name("JobsUpdated"), object: nil)
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
                                   resumeId: String) -> JobItem {
        
        // Extract scores from analysis result
        let scores = extractScoresFromAnalysisResult(analysisResult)
        
        // Create and save job
        let job = JobItem(
            jobTitle: jobTitle,
            company: company,
            cleanedJobDescription: cleanedJobDescription,
            analysisResult: analysisResult,
            analysisScores: scores,
            resumeId: resumeId
        )
        
        saveJob(job)
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
}
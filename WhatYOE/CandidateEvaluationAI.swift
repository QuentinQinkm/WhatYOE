//
//  CandidateEvaluationAI.swift
//  WhatYOE
//
//  AI-Powered Candidate Evaluation Service  
//  Handles the 5-Variable Scoring System AI interactions
//

import Foundation
import FoundationModels

/// Service class for AI-powered candidate evaluation using the 5-Variable Scoring System
///
/// This service provides three main AI evaluation functions:
/// 1. LLM Scoring: Experience, Education, Skills evaluation (0-4 scale each)
/// 2. YOE Parsing: Job-relevant years of experience calculation
/// 3. Resume-optimized evaluation using cleaned resume data
///
/// All functions return structured data defined in AIEvaluationOutputs.swift
class CandidateEvaluationAI {}

// MARK: - 5-Variable Scoring System AI Functions

extension CandidateEvaluationAI {
    
    // MARK: - LLM Evaluation Functions
    
    /// Evaluates candidate using raw text inputs (resume + job description)
    ///
    /// **Purpose:** Complete AI evaluation of candidate across 3 dimensions
    /// **Input:** Raw resume text + raw job description text  
    /// **Output:** Experience, Education, Skills scores (0-4 each) + rationales
    /// **Used by:** Main evaluation pipeline when working with raw documents
    ///
    /// - Parameters:
    ///   - resumeText: Raw resume content as extracted from PDF/text
    ///   - jobDescription: Raw job posting content
    /// - Returns: LLMScoringOutput with scores and rationales
    /// - Throws: AI service errors if evaluation fails
    static func evaluateCandidate_WithRawText(
        resumeText: String, 
        jobDescription: String
    ) async throws -> LLMScoringOutput {
        let session = LanguageModelSession(instructions: AIPromptLibrary.fiveVariableLLMSystemPrompt)
        let prompt = AIPromptLibrary.createFiveVariableLLMPrompt(resume: resumeText, job: jobDescription)
        let response = try await session.respond(to: prompt, generating: LLMScoringOutput.self)
        return response.content
    }
    
    /// Evaluates candidate using cleaned/structured resume data (more efficient)
    ///
    /// **Purpose:** Optimized AI evaluation using pre-cleaned resume structure
    /// **Input:** Structured CleanedResume object + raw job description
    /// **Output:** Experience, Education, Skills scores (0-4 each) + rationales  
    /// **Used by:** Evaluation pipeline when resume has already been cleaned
    /// **Advantage:** More focused prompts, better token efficiency, reduced hallucination
    ///
    /// - Parameters:
    ///   - cleanedResume: Structured resume data from resume cleaning pipeline
    ///   - jobDescription: Raw job posting content
    /// - Returns: LLMScoringOutput with scores and rationales
    /// - Throws: AI service errors if evaluation fails
    static func evaluateCandidate_WithCleanedResume(
        cleanedResume: CleanedResume, 
        jobDescription: String
    ) async throws -> LLMScoringOutput {
        let session = LanguageModelSession(instructions: AIPromptLibrary.fiveVariableLLMSystemPrompt)
        
        // Create focused prompt using structured resume data
        let prompt = buildOptimizedPrompt(cleanedResume: cleanedResume, jobDescription: jobDescription)
        
        let response = try await session.respond(to: prompt, generating: LLMScoringOutput.self)
        return response.content
    }
    
    // MARK: - YOE Calculation Functions
    
    /// Calculates job-relevant years of experience from raw resume text
    ///
    /// **Purpose:** Extract actual YOE specifically relevant to the target job
    /// **Input:** Raw resume text  
    /// **Output:** Calculated YOE + confidence score + calculation explanation
    /// **Used by:** Main evaluation pipeline to get Variable 2 (Actual YOE)
    /// **Note:** This is job-agnostic - considers all relevant experience, not job-specific
    ///
    /// - Parameter resumeText: Raw resume content as extracted from PDF/text
    /// - Returns: ResumeParsingResult with YOE calculation and confidence
    /// - Throws: AI service errors if parsing fails
    static func calculateYOE_FromRawResume(
        resumeText: String
    ) async throws -> ResumeParsingResult {
        let session = LanguageModelSession(instructions: AIPromptLibrary.resumeYOEParsingSystemPrompt)
        let prompt = AIPromptLibrary.createResumeYOEParsingPrompt(resume: resumeText)
        let response = try await session.respond(to: prompt, generating: ResumeParsingResult.self)
        return response.content
    }
    
    /// Calculates job-specific years of experience from cleaned resume data
    ///
    /// **Purpose:** Extract YOE specifically relevant to the target job requirements
    /// **Input:** Structured CleanedResume + target job context
    /// **Output:** Job-relevant YOE + confidence + detailed calculation breakdown
    /// **Used by:** Advanced evaluation pipeline for more precise YOE calculation  
    /// **Advantage:** Job-specific relevance assessment, better accuracy
    ///
    /// - Parameters:
    ///   - cleanedResume: Structured resume data from cleaning pipeline
    ///   - jobContext: Job description or requirements for relevance filtering
    /// - Returns: ResumeParsingResult with job-specific YOE calculation
    /// - Throws: AI service errors if parsing fails
    static func calculateYOE_JobSpecific(
        cleanedResume: CleanedResume,
        jobContext: String
    ) async throws -> ResumeParsingResult {
        let session = LanguageModelSession(instructions: AIPromptLibrary.resumeYOEParsingSystemPrompt)
        
        // Create job-aware prompt for more precise YOE calculation
        let prompt = buildJobSpecificYOEPrompt(cleanedResume: cleanedResume, jobContext: jobContext)
        
        let response = try await session.respond(to: prompt, generating: ResumeParsingResult.self)
        return response.content
    }
    
    // MARK: Required YOE Extraction (Variable 1)
    
    /// Extract required years of experience from job description using dedicated AI structure
    ///
    /// **Purpose:** Extract Required YOE (Variable 1) from job descriptions as a number
    /// **Input:** Raw job description text
    /// **Output:** RequiredYOEResult with extracted number + confidence + explanation
    /// **Used by:** 5-variable scoring system for Variable 1 calculation
    /// **Advantage:** Direct number extraction, handles various formats, confident scoring
    ///
    /// - Parameters:
    ///   - jobDescription: Raw job description text
    /// - Returns: RequiredYOEResult with required YOE number and extraction details
    /// - Throws: AI service errors if extraction fails
    static func extractRequiredYOEFromJob(jobDescription: String) async throws -> RequiredYOEResult {
        let session = LanguageModelSession(instructions: AIPromptLibrary.requiredYOEExtractionSystemPrompt)
        
        let prompt = """
        Extract the required years of experience from this job description:
        
        === JOB DESCRIPTION ===
        \(jobDescription)
        === END JOB DESCRIPTION ===
        
        Find minimum/required years of experience mentioned in the posting.
        """
        
        let response = try await session.respond(to: prompt, generating: RequiredYOEResult.self)
        return response.content
    }
}

// MARK: - Private Helper Functions

private extension CandidateEvaluationAI {
    
    /// Builds optimized prompt for cleaned resume evaluation
    static func buildOptimizedPrompt(cleanedResume: CleanedResume, jobDescription: String) -> String {
        return """
        === JOB DESCRIPTION ===
        \(jobDescription)

        === CLEANED RESUME DATA ===
        Work Experience: \(formatWorkExperience(cleanedResume.professionalExperience.workExperience))
        Other Experience: \(formatOtherExperience(cleanedResume.professionalExperience.otherExperience))
        Education: \(formatEducation(cleanedResume.education))
        Technical Skills: \(cleanedResume.skills.technicalSkills.joined(separator: ", "))
        Professional Skills: \(cleanedResume.skills.professionalSkills.joined(separator: ", "))
        Industry Skills: \(cleanedResume.skills.industrySkills.joined(separator: ", "))
        """
    }
    
    /// Builds job-specific YOE calculation prompt  
    static func buildJobSpecificYOEPrompt(cleanedResume: CleanedResume, jobContext: String) -> String {
        return """
        === TARGET JOB CONTEXT ===
        \(jobContext)
        
        === CANDIDATE RESUME ===
        Work Experience: \(formatWorkExperience(cleanedResume.professionalExperience.workExperience))
        Other Experience: \(formatOtherExperience(cleanedResume.professionalExperience.otherExperience))
        Skills: \(cleanedResume.skills.technicalSkills.joined(separator: ", "))
        
        Calculate years of experience specifically relevant to this job's requirements.
        Focus on transferable skills and directly applicable experience.
        """
    }
    
    // MARK: - Data Formatting Helpers
    
    static func formatWorkExperience(_ experiences: [WorkExperience]) -> String {
        return experiences.map { experience in
            "\(experience.role) at \(experience.company) (\(experience.startDate)-\(experience.endDate ?? "Present"))"
        }.joined(separator: ", ")
    }
    
    static func formatOtherExperience(_ experiences: [OtherExperience]) -> String {
        return experiences.map { experience in
            "\(experience.title) (\(experience.experienceType))"
        }.joined(separator: ", ")
    }
    
    static func formatEducation(_ education: [Education]) -> String {
        return education.map { edu in
            "\(edu.degree) in \(edu.field ?? "N/A") from \(edu.institution)"
        }.joined(separator: ", ")
    }
}

// MARK: - Legacy Function Aliases (for backward compatibility)

extension CandidateEvaluationAI {
    
    /// Legacy alias for evaluateCandidate_WithRawText
    /// **Deprecated:** Use evaluateCandidate_WithRawText for clarity
    @available(*, deprecated, renamed: "evaluateCandidate_WithRawText")
    static func performFiveVariableLLMEvaluation(resumeText: String, jobDescription: String) async throws -> LLMScoringOutput {
        return try await evaluateCandidate_WithRawText(resumeText: resumeText, jobDescription: jobDescription)
    }
    
    /// Legacy alias for evaluateCandidate_WithCleanedResume  
    /// **Deprecated:** Use evaluateCandidate_WithCleanedResume for clarity
    @available(*, deprecated, renamed: "evaluateCandidate_WithCleanedResume")
    static func performFiveVariableLLMEvaluationWithCleanedResume(cleanedResume: CleanedResume, jobDescription: String) async throws -> LLMScoringOutput {
        return try await evaluateCandidate_WithCleanedResume(cleanedResume: cleanedResume, jobDescription: jobDescription)
    }
    
    /// Legacy alias for calculateYOE_FromRawResume
    /// **Deprecated:** Use calculateYOE_FromRawResume for clarity  
    @available(*, deprecated, renamed: "calculateYOE_FromRawResume")
    static func performResumeParsingForYOE(resumeText: String) async throws -> ResumeParsingResult {
        return try await calculateYOE_FromRawResume(resumeText: resumeText)
    }
}
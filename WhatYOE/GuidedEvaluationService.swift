//
//  GuidedEvaluationService.swift
//  WhatYOE
//
//  Modular service for Guided Generation evaluations
//

import Foundation
import FoundationModels

class GuidedEvaluationService {}

// (Legacy evaluation prompts removed)

// Legacy 4-variable system functions removed - now using unified 5-variable system

// MARK: - New 5-variable Scoring System
extension GuidedEvaluationService {
    /// Single-round LLM evaluation for all 3 scoring dimensions
    static func performFiveVariableLLMEvaluation(resumeText: String, jobDescription: String) async throws -> LLMScoringOutput {
        let session = LanguageModelSession(instructions: PromptTemplates.fiveVariableLLMSystemPrompt)
        let prompt = PromptTemplates.createFiveVariableLLMPrompt(resume: resumeText, job: jobDescription)
        let response = try await session.respond(to: prompt, generating: LLMScoringOutput.self)
        return response.content
    }
    
    /// Single-round LLM evaluation using cleaned resume (more efficient)
    static func performFiveVariableLLMEvaluationWithCleanedResume(cleanedResume: CleanedResume, jobDescription: String) async throws -> LLMScoringOutput {
        let session = LanguageModelSession(instructions: PromptTemplates.fiveVariableLLMSystemPrompt)
        
        // Create a more focused prompt using the cleaned resume structure
        let prompt = """
        === JOB DESCRIPTION ===
        \(jobDescription)

        === CLEANED RESUME ===
        Work Experience: \(cleanedResume.professionalExperience.workExperience.map { "\($0.role) at \($0.company) (\($0.startDate)-\($0.endDate ?? "Present"))" }.joined(separator: ", "))
        Other Experience: \(cleanedResume.professionalExperience.otherExperience.map { "\($0.title) (\($0.experienceType))" }.joined(separator: ", "))
        Education: \(cleanedResume.education.map { "\($0.degree) in \($0.field ?? "N/A") from \($0.institution)" }.joined(separator: ", "))
        Skills: Technical: \(cleanedResume.skills.technicalSkills.joined(separator: ", ")), Professional: \(cleanedResume.skills.professionalSkills.joined(separator: ", ")), Industry: \(cleanedResume.skills.industrySkills.joined(separator: ", "))
        """
        
        let response = try await session.respond(to: prompt, generating: LLMScoringOutput.self)
        return response.content
    }
    
    /// Resume parsing for actual YOE extraction
    static func performResumeParsingForYOE(resumeText: String) async throws -> ResumeParsingResult {
        let session = LanguageModelSession(instructions: PromptTemplates.resumeYOEParsingSystemPrompt)
        let prompt = PromptTemplates.createResumeYOEParsingPrompt(resume: resumeText)
        let response = try await session.respond(to: prompt, generating: ResumeParsingResult.self)
        return response.content
    }
}
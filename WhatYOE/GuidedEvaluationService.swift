//
//  GuidedEvaluationService.swift
//  WhatYOE
//
//  Modular service for Guided Generation evaluations
//

import Foundation
import FoundationModels

class GuidedEvaluationService {
    
    // MARK: - Evaluation Methods
    
    /// Performs four separate evaluations (for testing efficiency)
    static func performFourRoundGuidedEvaluation(
        resumeText: String,
        jobDescription: String
    ) async throws -> FourRoundEvaluation {
        
        let session = LanguageModelSession(instructions: EvaluationPrompts.fourRoundSystemPrompt)
        let prompt = EvaluationPrompts.createFourRoundPrompt(resume: resumeText, job: jobDescription)
        
        let response = try await session.respond(to: prompt, generating: FourRoundEvaluation.self)
        return response.content
    }
    
    /// Performs single comprehensive evaluation (for efficiency comparison)
    static func performComprehensiveGuidedEvaluation(
        resumeText: String,
        jobDescription: String
    ) async throws -> ComprehensiveEvaluation {
        
        let session = LanguageModelSession(instructions: EvaluationPrompts.comprehensiveSystemPrompt)
        let prompt = EvaluationPrompts.createComprehensivePrompt(resume: resumeText, job: jobDescription)
        
        let response = try await session.respond(to: prompt, generating: ComprehensiveEvaluation.self)
        return response.content
    }
    
    // MARK: - Text Conversion (for backward compatibility)
    
    /// Converts structured four-round evaluation to text format
    static func formatFourRoundEvaluation(_ evaluation: FourRoundEvaluation) -> [String] {
        var results: [String] = []
        
        // Years of Experience
        results.append(formatCriterionEvaluation(evaluation.yearsOfExperience, title: "YEARS OF EXPERIENCE EVALUATION"))
        
        // Education
        results.append(formatCriterionEvaluation(evaluation.education, title: "EDUCATION EVALUATION"))
        
        // Technical Skills
        results.append(formatCriterionEvaluation(evaluation.technicalSkills, title: "TECHNICAL SKILLS EVALUATION"))
        
        // Relevant Experience
        results.append(formatCriterionEvaluation(evaluation.relevantExperience, title: "RELEVANT EXPERIENCE EVALUATION"))
        
        return results
    }
    
    /// Converts structured comprehensive evaluation to text format
    static func formatComprehensiveEvaluation(_ evaluation: ComprehensiveEvaluation) -> String {
        var text = "COMPREHENSIVE EVALUATION\n\n"
        
        // Individual criteria
        for criterion in evaluation.criteriaEvaluations {
            let title = titleForCriterion(criterion.criterion)
            text += formatCriterionEvaluation(criterion, title: title) + "\n\n"
        }
        
        // Overall assessment
        text += "FINAL SUMMARY\n"
        text += "**Overall Fit Score:** \(evaluation.overallAssessment.overallFitScore)\n"
        text += "**Overall Gap Score:** \(evaluation.overallAssessment.overallGapScore)\n"
        text += "**Recommendation:** \(evaluation.overallAssessment.recommendation)\n"
        
        return text
    }
    
    // MARK: - Helper Methods
    
    private static func formatCriterionEvaluation(_ criterion: CriterionEvaluation, title: String) -> String {
        var text = "## \(title)\n"
        
        text += "**Why they fit:**\n"
        for reason in criterion.whyTheyFit {
            text += "• \(reason)\n"
        }
        
        text += "**Why they don't fit:**\n"
        for reason in criterion.whyTheyDontFit {
            text += "• \(reason)\n"
        }
        
        text += "**Fit Score:** \(criterion.fitScore)\n"
        text += "**Gap Score:** \(criterion.gapScore)\n"
        
        return text
    }
    
    private static func titleForCriterion(_ criterion: EvaluationCriterion) -> String {
        switch criterion {
        case .yearsOfExperience:
            return "YEARS OF EXPERIENCE EVALUATION"
        case .education:
            return "EDUCATION EVALUATION"
        case .technicalSkills:
            return "TECHNICAL SKILLS EVALUATION"
        case .relevantExperience:
            return "RELEVANT EXPERIENCE EVALUATION"
        }
    }
}

// MARK: - Evaluation Prompts

struct EvaluationPrompts {
    
    // MARK: - System Prompts
    
    static let fourRoundSystemPrompt = """
    You are a professional recruiter evaluating a candidate against job requirements.
    
    Evaluate the candidate on exactly 4 criteria:
    1. Years of Experience
    2. Education 
    3. Technical Skills
    4. Relevant Experience
    
    SCORING SYSTEM:
    - Fit Score: 0=None, 1=Some, 2=Good, 3=Strong
    - Gap Score: 0=Major gaps, 1=Moderate gaps, 2=Minor gaps, 3=No gaps (higher is better)
    
    For each criterion, provide specific reasons why they fit and don't fit, then assign scores.
    """
    
    static let comprehensiveSystemPrompt = """
    You are a professional recruiter performing a comprehensive candidate evaluation.
    
    Evaluate ALL 4 criteria in a single comprehensive analysis:
    1. Years of Experience
    2. Education
    3. Technical Skills  
    4. Relevant Experience
    
    SCORING SYSTEM:
    - Fit Score: 0=None, 1=Some, 2=Good, 3=Strong
    - Gap Score: 0=Major gaps, 1=Moderate gaps, 2=Minor gaps, 3=No gaps (higher is better)
    
    Provide thorough evaluation with specific evidence and final recommendation.
    """
    
    // MARK: - Prompt Creators
    
    static func createFourRoundPrompt(resume: String, job: String) -> String {
        return """
        Evaluate this candidate systematically across all 4 criteria:
        
        === JOB DESCRIPTION ===
        \(job)
        
        === CANDIDATE RESUME ===
        \(resume)
        
        Provide structured evaluation for each criterion with specific evidence.
        """
    }
    
    static func createComprehensivePrompt(resume: String, job: String) -> String {
        return """
        Perform comprehensive evaluation of this candidate:
        
        === JOB DESCRIPTION ===
        \(job)
        
        === CANDIDATE RESUME ===
        \(resume)
        
        Evaluate all criteria comprehensively and provide final recommendation.
        """
    }
}
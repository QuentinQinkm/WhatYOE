//
//  AIEvaluationOutputs.swift
//  WhatYOE
//
//  5-Variable Scoring System Output Structures
//  These structures define the AI response formats for candidate evaluation
//

import Foundation
import FoundationModels

// MARK: - 5-Variable System Overview
/*
 The 5-Variable Scoring System evaluates candidates using:
 
 1. Required YOE (from job description parsing)
 2. Actual YOE (from job-relevant resume analysis) 
 3. Experience Score (0-4, AI-evaluated)
 4. Education Score (0-4, AI-evaluated)
 5. Skills Score (0-4, AI-evaluated)
 
 This file contains structures 3, 4, 5 (AI evaluation outputs) and 2 (YOE parsing output)
 */

// MARK: - AI Evaluation Output (Variables 3, 4, 5)

/// AI evaluation output for the three scored dimensions of candidate assessment
/// Used by: CandidateEvaluationAI.performFiveVariableLLMEvaluation()
@Generable
struct LLMScoringOutput {
    // MARK: Scores (0-4 scale)
    
    @Guide(description: "Experience relevance score (0-4): How well does their experience match this job's core tasks? 0=No relevant experience, 1=Minimal relevance, 2=Moderate relevance, 3=Strong relevance, 4=Excellent relevance")
    let exp_score: Int
    
    @Guide(description: "Education relevance score (0-4): How well does their education align with job requirements? 0=No relevant education, 1=Some relevant coursework, 2=Related degree but not exact match, 3=Required degree obtained, 4=Advanced degree exceeding requirements")
    let edu_score: Int
    
    @Guide(description: "Skills proficiency score (0-4): Overall coverage of required skills? 0=Missing most critical skills, 1=Has some required skills with major gaps, 2=Meets basic requirements with some gaps, 3=Strong skill match with minor gaps only, 4=Excellent skill coverage exceeding requirements")
    let skill_score: Int
    
    // MARK: Rationales (2-3 lines each)
    
    @Guide(description: "Experience rationale: Brief explanation for experience score (max 2-3 lines)")
    let experience_rationale: String
    
    @Guide(description: "Education rationale: Brief explanation for education score (max 2-3 lines)")  
    let education_rationale: String
    
    @Guide(description: "Skills rationale: Brief explanation for skills score (max 2-3 lines)")
    let skills_rationale: String
}

// MARK: - YOE Parsing Output (Variable 2)

/// Job-relevant years of experience calculation result
/// Used by: CandidateEvaluationAI.performResumeParsingForYOE()
@Generable
struct ResumeParsingResult {
    @Guide(description: "Actual years of experience (0-8 range): candidate's total job-relevant experience calculated from resume content")
    let actual_yoe: Double
    
    @Guide(description: "Parsing confidence (0-1 range): AI confidence level in the YOE extraction accuracy")
    let confidence: Double
    
    @Guide(description: "Calculation explanation: Brief step-by-step breakdown of how the YOE was calculated")
    let calculation_notes: String
}

// MARK: - Scoring Scale Reference

/// Reference guide for scoring scales used in LLM evaluation
enum ScoringScale {
    /// Experience relevance scoring guide
    enum Experience: Int, CaseIterable {
        case none = 0           // No relevant experience
        case minimal = 1        // Minimal relevance  
        case moderate = 2       // Moderate relevance
        case strong = 3         // Strong relevance
        case excellent = 4      // Excellent relevance
        
        var description: String {
            switch self {
            case .none: return "No relevant experience"
            case .minimal: return "Minimal relevance"
            case .moderate: return "Moderate relevance" 
            case .strong: return "Strong relevance"
            case .excellent: return "Excellent relevance"
            }
        }
    }
    
    /// Education relevance scoring guide  
    enum Education: Int, CaseIterable {
        case none = 0           // No relevant education
        case coursework = 1     // Some relevant coursework
        case related = 2        // Related degree but not exact match
        case required = 3       // Required degree obtained
        case advanced = 4       // Advanced degree exceeding requirements
        
        var description: String {
            switch self {
            case .none: return "No relevant education"
            case .coursework: return "Some relevant coursework"
            case .related: return "Related degree but not exact match"
            case .required: return "Required degree obtained" 
            case .advanced: return "Advanced degree exceeding requirements"
            }
        }
    }
    
    /// Skills proficiency scoring guide
    enum Skills: Int, CaseIterable {
        case missing = 0        // Missing most critical skills
        case gaps = 1          // Has some required skills with major gaps
        case basic = 2         // Meets basic requirements with some gaps
        case strong = 3        // Strong skill match with minor gaps only
        case excellent = 4     // Excellent skill coverage exceeding requirements
        
        var description: String {
            switch self {
            case .missing: return "Missing most critical skills"
            case .gaps: return "Has some required skills with major gaps"
            case .basic: return "Meets basic requirements with some gaps"
            case .strong: return "Strong skill match with minor gaps only"
            case .excellent: return "Excellent skill coverage exceeding requirements"
            }
        }
    }
}
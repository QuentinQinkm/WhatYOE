//
//  SpecGuidedStructures.swift
//  WhatYOE
//
//  Guided Generation data structures for 5-variable scoring system
//

import Foundation
import FoundationModels

// MARK: - 5-variable system structures (current active system)

@Generable
struct LLMScoringOutput {
    @Guide(description: "Experience relevance score (0-4 integer): How relevant is their experience to this job's core tasks? 0=No relevant experience, 1=Minimal relevance, 2=Moderate relevance, 3=Strong relevance, 4=Excellent relevance")
    let exp_score: Int
    
    @Guide(description: "Education relevance score (0-4 integer): How relevant is their education to job requirements? 0=No relevant education, 1=Some relevant coursework, 2=Related degree but not exact match, 3=Required degree obtained, 4=Advanced degree exceeding requirements")
    let edu_score: Int
    
    @Guide(description: "Skills proficiency score (0-4 integer): Overall proficiency in required skills? 0=Missing most critical skills, 1=Has some required skills with gaps, 2=Meets basic requirements with some gaps, 3=Strong skill match with minor gaps only, 4=Excellent skill coverage exceeding requirements")
    let skill_score: Int
    
    @Guide(description: "Experience rationale (max 2-3 lines)")
    let experience_rationale: String
    
    @Guide(description: "Education rationale (max 2-3 lines)")
    let education_rationale: String
    
    @Guide(description: "Skills rationale (max 2-3 lines)")
    let skills_rationale: String
}

@Generable
struct ResumeParsingResult {
    @Guide(description: "Actual years of experience (0-8 range, float): candidate's cumulative relevant years of experience extracted from resume")
    let actual_yoe: Double
    
    @Guide(description: "Parsing confidence (0-1 range): confidence level in the YOE extraction")
    let confidence: Double
    
    @Guide(description: "Brief explanation of how YOE was calculated")
    let calculation_notes: String
}



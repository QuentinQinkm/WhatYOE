//
//  EvaluationStructures.swift
//  WhatYOE
//
//  Guided Generation structures for resume-job evaluation
//

import Foundation
import FoundationModels

// MARK: - Individual Criterion Evaluation

@Generable
struct CriterionEvaluation {
    @Guide(description: "Which criterion is being evaluated")
    let criterion: EvaluationCriterion
    
    @Guide(description: "Reasons why the candidate fits this criterion")
    let whyTheyFit: [String]
    
    @Guide(description: "Reasons why the candidate doesn't fit this criterion")
    let whyTheyDontFit: [String]
    
    @Guide(description: "Fit score from 0-3 (0=None, 1=Some, 2=Good, 3=Strong)")
    let fitScore: Int
    
    @Guide(description: "Gap score from 0-3 (0=Major gaps, 1=Moderate gaps, 2=Minor gaps, 3=No gaps)")
    let gapScore: Int
}

@Generable
enum EvaluationCriterion {
    case yearsOfExperience
    case education
    case technicalSkills
    case relevantExperience
}

// MARK: - Four Round Evaluation

@Generable
struct FourRoundEvaluation {
    @Guide(description: "Years of experience evaluation")
    let yearsOfExperience: CriterionEvaluation
    
    @Guide(description: "Education evaluation")
    let education: CriterionEvaluation
    
    @Guide(description: "Technical skills evaluation")
    let technicalSkills: CriterionEvaluation
    
    @Guide(description: "Relevant experience evaluation")
    let relevantExperience: CriterionEvaluation
    
    @Guide(description: "Overall assessment summary")
    let overallSummary: OverallAssessment
}

// MARK: - Single Round Comprehensive Evaluation

@Generable
struct ComprehensiveEvaluation {
    @Guide(description: "All four criteria evaluated together")
    let criteriaEvaluations: [CriterionEvaluation]
    
    @Guide(description: "Overall assessment and recommendation")
    let overallAssessment: OverallAssessment
}

// MARK: - Shared Assessment Structure

@Generable
struct OverallAssessment {
    @Guide(description: "Overall fit score from 0-3")
    let overallFitScore: Int
    
    @Guide(description: "Overall gap score from 0-3")
    let overallGapScore: Int
    
    @Guide(description: "Final recommendation summary")
    let recommendation: String
    
    @Guide(description: "Key strengths of the candidate")
    let keyStrengths: [String]
    
    @Guide(description: "Main concerns or gaps")
    let mainConcerns: [String]
}
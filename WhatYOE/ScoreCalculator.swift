//
//  ScoreCalculator.swift
//  WhatYOE
//
//  Centralized scoring calculation to ensure consistency across the app
//

import Foundation

struct ScoreCalculator {
    // (Legacy fit/gap-based scoring removed)
}

// MARK: - 5-variable Scoring System (current active system)

struct ScoringComponents {
    let f_YOE: Double        // YOE factor (capped at 1.0)
    let S_exp: Double        // Experience score
    let w_edu: Double        // Education weight
    let S_edu: Double        // Education score  
    let S_base: Double       // Base weighted score
    let M_skill: Double      // Skills multiplier
    let S_final: Double      // Final score (0-1)
}

struct ScoringParameters {
    let H: Double            // Education decay smoothing (default: 5.0)
    let epsilon: Double      // Division by zero prevention (default: 0.01)
    let f_YOE_cap: Double    // Experience factor cap (fixed: 1.0)
    
    static let `default` = ScoringParameters(H: 5.0, epsilon: 0.01, f_YOE_cap: 1.5)
}

struct FiveVariableScoringResult {
    let score: Double              // 0-1 scale
    let score_percentage: Int      // 0-100 scale  
    let components: ScoringComponents
    let inputs: ScoringInputs
    let success: Bool
    let error: String?
}

struct ScoringInputs {
    let actual_yoe: Double      // From resume parsing (0-8)
    let required_yoe: Double    // From job parsing (0-8)
    let exp_score: Int          // From LLM (0-4)
    let edu_score: Int          // From LLM (0-4)
    let skill_score: Int        // From LLM (0-4)
}

extension Double {
    func map(from: ClosedRange<Double>, to: ClosedRange<Double>) -> Double {
        let fromRange = from.upperBound - from.lowerBound
        let toRange = to.upperBound - to.lowerBound
        let normalized = (self - from.lowerBound) / fromRange
        return to.lowerBound + (normalized * toRange)
    }
}

extension ScoreCalculator {
    // MARK: - 5-variable scoring system
    static func validateInputs(
        actualYOE: Double,
        requiredYOE: Double, 
        expScore: Int,
        eduScore: Int,
        skillScore: Int
    ) throws {
        // Range validations
        if actualYOE < 0 || actualYOE > 8 {
            throw NSError(domain: "ScoringError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid actualYOE: \(actualYOE). Must be 0-8."])
        }
        
        if requiredYOE < 0 || requiredYOE > 8 {
            throw NSError(domain: "ScoringError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid requiredYOE: \(requiredYOE). Must be 0-8."])
        }
        
        // LLM scores must be integers 0-4
        let scores = [(expScore, "expScore"), (eduScore, "eduScore"), (skillScore, "skillScore")]
        for (score, name) in scores {
            if score < 0 || score > 4 {
                throw NSError(domain: "ScoringError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid \(name): \(score). Must be integer 0-4."])
            }
        }
    }
    
    static func normalizeInputs(
        actualYOE: Double,
        requiredYOE: Double,
        expScore: Int,
        eduScore: Int,
        skillScore: Int
    ) -> ScoringInputs {
        return ScoringInputs(
            actual_yoe: max(0, min(8, actualYOE)),
            required_yoe: max(0, min(8, requiredYOE)),
            exp_score: max(0, min(4, expScore)),
            edu_score: max(0, min(4, eduScore)),
            skill_score: max(0, min(4, skillScore))
        )
    }
    
    static func computeCandidateScore(
        actualYOE: Double,      // From resume parsing
        requiredYOE: Double,    // From job parsing  
        expScore: Int,          // From LLM (0-4)
        eduScore: Int,          // From LLM (0-4)
        skillScore: Int,        // From LLM (0-4)
        params: ScoringParameters = .default
    ) -> FiveVariableScoringResult {
        
        do {
            // Validate inputs
            try validateInputs(
                actualYOE: actualYOE,
                requiredYOE: requiredYOE,
                expScore: expScore,
                eduScore: eduScore,
                skillScore: skillScore
            )
            
            // Normalize inputs
            let inputs = normalizeInputs(
                actualYOE: actualYOE,
                requiredYOE: requiredYOE,
                expScore: expScore,
                eduScore: eduScore,
                skillScore: skillScore
            )
            
            // 1. YOE Factor (with cap at 1.5)
            let f_YOE = min(
                params.f_YOE_cap, 
                sqrt(inputs.actual_yoe / (inputs.required_yoe + params.epsilon))
            )
            
            // 2. Experience Score (mapped to 0.2-1.15 range)
            let raw_exp = sqrt(Double(inputs.exp_score)) * f_YOE
            let S_exp = raw_exp.map(from: 0...3.0, to: 0.2...1.151)
            
            // 3. Education Weight (mapped to 0.1-0.7 range)
            let raw_w_edu = 1.0 / (1.0 + pow(inputs.required_yoe / params.H, 2))
            let w_edu = raw_w_edu.map(from: 0.28...1.0, to: 0.1...0.7)
            
            // 4. Education Score (mapped to 0.2-1.15 range)
            let raw_edu = sqrt(Double(inputs.edu_score))
            let S_edu = raw_edu.map(from: 0...2.0, to: 0.2...1.15)
            
            // 5. Base Score (weighted combination)
            let S_base = (1.0 - w_edu) * S_exp + w_edu * S_edu
            
            // 6. Skills Multiplier (penalty-only, fixed formula)
            let M_skill = 0.5 + 0.5 * (Double(inputs.skill_score) / 4.0)
            
            // 7. Final Score (mapped to 0-100 range)
            let raw_final = S_base * M_skill
            let S_final = max(0.0, min(1.0, raw_final))
            
            let components = ScoringComponents(
                f_YOE: f_YOE,
                S_exp: S_exp,
                w_edu: w_edu,
                S_edu: S_edu,
                S_base: S_base,
                M_skill: M_skill,
                S_final: S_final
            )
            
            return FiveVariableScoringResult(
                score: S_final,
                score_percentage: Int((S_final * 100.0).rounded()),
                components: components,
                inputs: inputs,
                success: true,
                error: nil
            )
            
            } catch {
            return FiveVariableScoringResult(
                score: 0,
                score_percentage: 0,
                components: ScoringComponents(f_YOE: 0, S_exp: 0, w_edu: 0, S_edu: 0, S_base: 0, M_skill: 0, S_final: 0),
                inputs: ScoringInputs(actual_yoe: 0, required_yoe: 0, exp_score: 0, edu_score: 0, skill_score: 0),
                success: false,
                error: error.localizedDescription
            )
        }
    }
    
    static func specRating(for scorePct: Int) -> String {
        if scorePct < 75 { return "Denied" }
        if scorePct < 85 { return "Poor" }
        if scorePct < 93 { return "Maybe" }
        return "Good"
    }
}
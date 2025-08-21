//
//  ScoreCalculator.swift
//  WhatYOE
//
//  Centralized scoring calculation using improved Option B algorithm
//  Ensures consistency across the app with enhanced score calculation
//

import Foundation

struct ScoreCalculator {}

// MARK: - Improved Option B Scoring System

/// Input structure for candidate evaluation
struct EvaluationInputs {
    let actualYOE: Double        // candidate's job-relevant YOE
    let requiredYOE: Double      // job's required YOE (seniority target)
    let expScore: Int            // 0...4
    let eduScore: Int            // 0...4
    let skillScore: Int          // 0...4
}

/// Updated scoring parameters with improved Option B algorithm
struct ScoringParameters {
    // Seniority factor
    let epsilon: Double          // avoids div-by-zero when requiredYOE == 0
    let fYOECap: Double          // caps over-qualification boost (e.g., 1.5)

    // Education weight as a linear function of required YOE:
    //   wEdu = clamp(wEduIntercept - wEduSlope * requiredYOE, wEduMin, wEduMax)
    let wEduIntercept: Double    // e.g., 0.70  (higher weight at entry level)
    let wEduSlope: Double        // e.g., 0.10  (drops ~0.1 per YOE)
    let wEduMin: Double          // e.g., 0.15
    let wEduMax: Double          // e.g., 0.60

    // Skills multiplier (penalty-only): [0.8, 1.0]
    //   M_skill = 0.8 + 0.2 * (skill/4)
    let skillFloor: Double       // e.g., 0.80
    let skillSpan: Double        // e.g., 0.20

    static let `default` = ScoringParameters(
        epsilon: 0.01,
        fYOECap: 1.5,
        wEduIntercept: 0.85,
        wEduSlope: 0.05,
        wEduMin: 0.15,
        wEduMax: 0.75,
        skillFloor: 0.95,
        skillSpan: 0.05
    )
}

/// Detailed score breakdown for debugging and analysis
struct ScoreBreakdown {
    let fYOE: Double
    let sExp: Double
    let sEdu: Double
    let wEdu: Double
    let sBase: Double
    let mSkill: Double
    let final01: Double      // 0...1
    let finalPercent: Double // 0...100
}

/// Modern result structure
struct ScoringResult {
    let score: Double              // 0-1 scale
    let score_percentage: Int      // 0-100 scale  
    let breakdown: ScoreBreakdown
    let success: Bool
    let error: String?
}

// MARK: - Core Scoring Algorithm (Option B)

extension ScoreCalculator {
    
    /// Improved Option B scoring algorithm with enhanced education weighting
    ///
    /// **Key Improvements:**
    /// • Linear education weight decay instead of exponential
    /// • Proper 0-1 normalization for all components  
    /// • Skills penalty-only multiplier [0.8, 1.0]
    /// • Square root scaling for diminishing returns
    ///
    /// - Parameters:
    ///   - inputs: EvaluationInputs with candidate and job data
    ///   - params: ScoringParameters for algorithm tuning
    /// - Returns: ScoreBreakdown with detailed component analysis
    static func scoreOptionB(
        inputs: EvaluationInputs,
        params: ScoringParameters = .default
    ) -> ScoreBreakdown {

        // 1) Seniority match factor with diminishing returns & cap
        //    fYOE = min(fYOECap, sqrt(actual / (required + ε)))
        let denom = max(inputs.requiredYOE + params.epsilon, params.epsilon)
        let ratio = max(inputs.actualYOE / denom, 0.0)
        let fYOE = min(params.fYOECap, sqrt(ratio))

        // 2) Experience score normalized to [0,1]
        //    raw max of sqrt(expScore) is 2 (since expScore ∈ [0,4])
        //    include YOE factor and divide by (2 * fYOECap) so even max is bounded in [0,1]
        let sExp = clamp01((sqrt(Double(inputs.expScore)) * fYOE) / (2.0 * params.fYOECap))

        // 3) Education score normalized to [0,1]
        //    simple: sqrt(eduScore) / 2  (since sqrt(4) = 2)
        let sEdu = clamp01(sqrt(Double(inputs.eduScore)) / 2.0)

        // 4) Education weight as a linear function of required YOE (then clamped)
        //    wEdu = clamp(wEduIntercept - wEduSlope * requiredYOE, wEduMin, wEduMax)
        let wEduRaw = params.wEduIntercept - params.wEduSlope * inputs.requiredYOE
        let wEdu = clamp(wEduRaw, params.wEduMin, params.wEduMax)

        // 5) Base blend (experience vs education), then clamp to [0,1]
        let sBase = clamp01((1.0 - wEdu) * sExp + wEdu * sEdu)

        // 6) Skills multiplier (penalty-only) in [skillFloor, skillFloor + skillSpan]
        //    M_skill = floor + span * (skill/4)
        let skillFrac = max(0.0, min(Double(inputs.skillScore) / 4.0, 1.0))
        let mSkill = params.skillFloor + params.skillSpan * skillFrac

        // 7) Final score in [0,1] and percent
        let final01 = clamp01(sBase * mSkill)
        let finalPercent = final01 * 100.0

        return ScoreBreakdown(
            fYOE: fYOE,
            sExp: sExp,
            sEdu: sEdu,
            wEdu: wEdu,
            sBase: sBase,
            mSkill: mSkill,
            final01: final01,
            finalPercent: finalPercent
        )
    }
    
    // MARK: - Input Normalization
    
    static func normalizeInputs(
        actualYOE: Double,
        requiredYOE: Double,
        expScore: Int,
        eduScore: Int,
        skillScore: Int
    ) -> EvaluationInputs {
        return EvaluationInputs(
            actualYOE: max(0, min(8, actualYOE)),
            requiredYOE: max(0, min(8, requiredYOE)),
            expScore: max(0, min(4, expScore)),
            eduScore: max(0, min(4, eduScore)),
            skillScore: max(0, min(4, skillScore))
        )
    }
    
    // MARK: - Main Scoring Function (Updated)
    
    /// Primary scoring function using improved Option B algorithm
    ///
    /// **Features:**
    /// • Enhanced education weighting with linear decay
    /// • Proper normalization preventing score inflation  
    /// • Skills penalty-only approach for realistic scoring
    ///
    /// - Parameters:
    ///   - actualYOE: Candidate's job-relevant years of experience (0-8)
    ///   - requiredYOE: Job's required years of experience (0-8)
    ///   - expScore: LLM experience relevance score (0-4)
    ///   - eduScore: LLM education relevance score (0-4)
    ///   - skillScore: LLM skills proficiency score (0-4)
    ///   - params: Scoring parameters for algorithm tuning
    /// - Returns: ScoringResult with detailed breakdown
    static func computeCandidateScore(
        actualYOE: Double,      // From resume parsing
        requiredYOE: Double,    // From job parsing  
        expScore: Int,          // From LLM (0-4)
        eduScore: Int,          // From LLM (0-4)
        skillScore: Int,        // From LLM (0-4)
        params: ScoringParameters = .default
    ) -> ScoringResult {
        
        // Normalize inputs
        let normalizedInputs = normalizeInputs(
            actualYOE: actualYOE,
            requiredYOE: requiredYOE,
            expScore: expScore,
            eduScore: eduScore,
            skillScore: skillScore
        )
        
        // Compute score using improved Option B algorithm
        let breakdown = scoreOptionB(inputs: normalizedInputs, params: params)
        
        return ScoringResult(
            score: breakdown.final01,
            score_percentage: Int(breakdown.finalPercent.rounded()),
            breakdown: breakdown,
            success: true,
            error: nil
        )
    }
    
    // MARK: - Rating Classification
    
    /// Convert percentage score to rating classification
    /// **Categories:** Good (93-100%), Maybe (85-92%), Poor (75-84%), Denied (<75%)
    static func specRating(for scorePct: Int) -> String {
        if scorePct < 75 { return "Denied" }
        if scorePct < 85 { return "Poor" }
        if scorePct < 93 { return "Maybe" }
        return "Good"
    }
}

// MARK: - Helper Functions

/// Clamp value to [0,1] range
@inline(__always)
private func clamp01(_ x: Double) -> Double {
    return min(max(x, 0.0), 1.0)
}

/// Clamp value to specified range
@inline(__always)
private func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
    return min(max(x, lo), hi)
}


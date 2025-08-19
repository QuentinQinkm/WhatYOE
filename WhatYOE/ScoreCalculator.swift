//
//  ScoreCalculator.swift
//  WhatYOE
//
//  Centralized scoring calculation to ensure consistency across the app
//

import Foundation

struct ScoreCalculator {
    // MARK: - Configuration
    static let fitMultiplier: Double = 1.8   // Give more weight to fit scores
    static let gapMultiplier: Double = 0.5   // Slightly reduce gap score impact
    
    // MARK: - Score Calculation
    static func calculateFinalScore(fitScores: [Double], gapScores: [Double]) -> Double {
        guard !fitScores.isEmpty && !gapScores.isEmpty else {
            return 0.0
        }
        
        let fitSum = fitScores.reduce(0.0, +)
        let gapSum = gapScores.reduce(0.0, +)
        let totalScores = Double(fitScores.count + gapScores.count)
        
        let finalScore = (fitSum * fitMultiplier + gapSum * gapMultiplier) / totalScores
        return finalScore
    }
    
    // Convenience method for integer arrays (from extension)
    static func calculateFinalScore(fitScores: [Int], gapScores: [Int]) -> Double {
        let doubleFitScores = fitScores.map { Double($0) }
        let doubleGapScores = gapScores.map { Double($0) }
        return calculateFinalScore(fitScores: doubleFitScores, gapScores: doubleGapScores)
    }
    
    // MARK: - Rating Scale (Updated to match user requirements)
    static func getRating(for finalScore: Double) -> String {
        switch finalScore {
        case 0.0..<1.3:
            return "Reject"
        case 1.3..<2.0:
            return "Poor"
        case 2.0..<2.7:
            return "Maybe"
        case 2.7...4.0:
            return "Good"
        default:
            return "Unknown"
        }
    }
    
    static func getRecommendation(for finalScore: Double) -> String {
        switch finalScore {
        case 0.0..<1.3:
            return "❌ Reject - Candidate does not meet minimum requirements"
        case 1.3..<2.0:
            return "📉 Poor - Significant gaps in qualifications"
        case 2.0..<2.7:
            return "⚠️ Maybe - Mixed qualifications, proceed with caution"
        case 2.7...4.0:
            return "✅ Good - Candidate meets most requirements and is qualified"
        default:
            return "❓ Unknown - Score out of expected range"
        }
    }
    
    // MARK: - Score Extraction (Centralized)
    
    /// Extract all scores from evaluation results
    static func extractAllScores(from results: [String]) -> (fitScores: [Double], gapScores: [Double]) {
        var fitScores: [Double] = []
        var gapScores: [Double] = []
        
        for result in results {
            let fitScore = extractScore(from: result, type: "Fit Score")
            let gapScore = extractScore(from: result, type: "Gap Score")
            fitScores.append(fitScore)
            gapScores.append(gapScore)
        }
        
        return (fitScores, gapScores)
    }
    
    /// Extract scores from a specific section
    static func extractScore(from text: String, type: String, section: String? = nil) -> Double {
        var searchText = text
        
        // If section is specified, find that section first
        if let section = section {
            let sectionPattern = "## \\d+\\. \(section.uppercased())"
            
            guard let sectionRange = text.range(of: sectionPattern, options: .regularExpression) else {
                return 0.0
            }
            
            // Get text from section start to next section or end
            let fromSectionStart = String(text[sectionRange.lowerBound...])
            let nextSectionPattern = "## \\d+\\."
            
            if let nextSectionRange = fromSectionStart.range(of: nextSectionPattern, options: .regularExpression, range: fromSectionStart.index(fromSectionStart.startIndex, offsetBy: 10)..<fromSectionStart.endIndex) {
                searchText = String(fromSectionStart[..<nextSectionRange.lowerBound])
            } else {
                searchText = fromSectionStart
            }
        }
        
        // Look for the score within the text
        let patterns = [
            "\\*\\*\(type):\\*\\*\\s*([0-9]+(?:\\.\\d+)?)",
            "\\*\\*\(type.lowercased()):\\*\\*\\s*([0-9]+(?:\\.\\d+)?)",
            "\(type):\\s*([0-9]+(?:\\.\\d+)?)",
            "\(type.lowercased()):\\s*([0-9]+(?:\\.\\d+)?)"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: searchText.utf16.count)
                
                if let match = regex.firstMatch(in: searchText, range: range) {
                    let scoreRange = match.range(at: 1)
                    if let range = Range(scoreRange, in: searchText) {
                        let scoreString = String(searchText[range])
                        if let score = Double(scoreString) {
                            return score
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        return 0.0
    }
    
    /// Extract final score from analysis results
    static func extractFinalScore(from text: String) -> Double {
        let patterns = [
            "\\*\\*Final Score:\\*\\*\\s*([0-9]+(?:\\.\\d+)?)",
            "Final Score:\\s*([0-9]+(?:\\.\\d+)?)",
            "\\*\\*final score:\\*\\*\\s*([0-9]+(?:\\.\\d+)?)",
            "final score:\\s*([0-9]+(?:\\.\\d+)?)"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: text.utf16.count)
                
                if let match = regex.firstMatch(in: text, range: range) {
                    let scoreRange = match.range(at: 1)
                    if let range = Range(scoreRange, in: text) {
                        let scoreString = String(text[range])
                        if let score = Double(scoreString) {
                            return score
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        return 0.0
    }
    
    // MARK: - Analysis Result Processing
    
    /// Process evaluation results and return formatted output with scores
    static func processEvaluationResults(results: [String]) -> (formattedOutput: String, fitScores: [Double], gapScores: [Double], finalScore: Double) {
        let yearsResult = results[0]
        let educationResult = results[1]
        let skillsResult = results[2]
        let experienceResult = results[3]
        
        let (fitScores, gapScores) = extractAllScores(from: results)
        let finalScore = calculateFinalScore(fitScores: fitScores, gapScores: gapScores)
        
        let totalFitScore = fitScores.reduce(0.0, +)
        let totalGapScore = gapScores.reduce(0.0, +)
        
        let formattedOutput = """
        # EVALUATION RESULTS
        
        ## 1. YEARS OF EXPERIENCE
        \(yearsResult)
        
        ## 2. EDUCATION
        \(educationResult)
        
        ## 3. TECHNICAL SKILLS
        \(skillsResult)
        
        ## 4. RELEVANT EXPERIENCE
        \(experienceResult)
        
        ## FINAL SCORE
        **Total Fit Score:** \(String(format: "%.1f", totalFitScore)) / 12
        **Total Gap Score:** \(String(format: "%.1f", totalGapScore)) / 12
        **Final Score:** \(String(format: "%.1f", finalScore)) (0-3 scale)
        
        ## RECOMMENDATION
        \(getRecommendation(for: finalScore))
        """
        
        return (formattedOutput, fitScores, gapScores, finalScore)
    }
}
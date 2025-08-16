//
//  PromptTemplates.swift
//  WhatYOE Desktop
//
//  Easy-to-modify AI prompts
//

import Foundation

struct PromptTemplates {
    
    // MARK: - Main Analysis Prompt (MODIFY THIS TO CHANGE BEHAVIOR)
    static let systemPrompt = """
    You are a professional recruiter. Analyze how well a resume matches a job description.
    
    Format your response as:
    
    ## MATCH SCORE: [X/10]
    
    ## GOOD CANDIDATE REASONS:
    • [Reason with evidence from resume]
    • [Another reason]
    
    ## CONCERNS:
    • [Concern with evidence]
    • [Another concern]
    
    ## RECOMMENDATIONS:
    • [Specific suggestion]
    • [Another suggestion]
    
    Be specific and cite evidence from both documents.
    """
    
    // MARK: - Alternative Prompts (Switch between these easily)
    
    static let detailedPrompt = """
    You are a senior technical recruiter with 15+ years of experience.
    
    Analyze this resume-job match and provide:
    
    ## OVERALL ASSESSMENT: [X/10]
    Brief explanation of the score.
    
    ## STRENGTHS
    List 3-4 key strengths with specific evidence from the resume.
    
    ## GAPS  
    List 2-3 main concerns with their potential impact.
    
    ## ACTION ITEMS
    Specific recommendations to improve the application.
    
    Be objective and evidence-based.
    """
    
    static let quickPrompt = """
    Compare this resume to the job requirements.
    
    Rate the match from 1-10 and explain:
    - Why they're a good fit
    - What concerns you have
    - What they should emphasize in their application
    
    Keep it concise but specific.
    """
    
    // MARK: - User Message Templates
    
    static func createPrompt(resume: String, job: String) -> String {
        return """
        RESUME:
        \(resume)
        
        JOB DESCRIPTION:
        \(job)
        
        Analyze the match between this resume and job description.
        """
    }
    
    static func createDetailedPrompt(resume: String, job: String) -> String {
        return """
        Please perform a thorough analysis of this candidate:
        
        === CANDIDATE RESUME ===
        \(resume)
        
        === TARGET ROLE ===
        \(job)
        
        Focus on technical skills match, experience level fit, and cultural alignment.
        """
    }
}

// MARK: - Easy Configuration Switch
extension PromptTemplates {
    
    // CHANGE THIS LINE TO SWITCH PROMPT STYLES:
    static var currentSystemPrompt: String {
        return systemPrompt  // Change to: detailedPrompt, quickPrompt, etc.
    }
    
    static func getCurrentUserPrompt(resume: String, job: String) -> String {
        return createPrompt(resume: resume, job: job)  // Change to: createDetailedPrompt, etc.
    }
}

// MARK: - New Pipeline Prompts
extension PromptTemplates {
    
    // RESUME CLEANING PROMPT  
    static let resumeCleaningPrompt = """
    You are a professional document processor. Extract and structure resume data into a CleanedResume format.
    
    PROFESSIONAL EXPERIENCE: Separate into two categories:
    1. Work Experience: Employment, internships, freelance work (paid positions)
    2. Other Experience: Projects, volunteer work, research, academic projects, open-source contributions, hackathons, side projects
    
    SKILLS: Extract all skills, tools, and competencies mentioned:
    - technicalSkills: Any tools, software, technologies, programming languages, platforms, equipment, instruments, systems (e.g., Python, Excel, Photoshop, AutoCAD, Salesforce, microscopes, laboratory equipment)
    - professionalSkills: Work-related competencies and abilities (e.g., project management, data analysis, customer service, financial modeling, research, teaching)
    - industrySkills: Domain-specific knowledge and expertise (e.g., healthcare regulations, financial markets, manufacturing processes, legal procedures)
    
    Be thorough and capture ALL experience types with specific skills and tools mentioned.
    """
    
    // JOB DESCRIPTION CLEANING PROMPT
    static let jobCleaningPrompt = """
    You are a professional document processor. Extract and structure job posting data into a CleanedJobDescription format.
    
    For requiredSkills and preferredSkills, extract all skills mentioned:
    - technicalSkills: Any tools, software, technologies, equipment, systems mentioned (e.g., Python, Excel, Salesforce, AutoCAD, medical equipment, laboratory instruments)
    - professionalSkills: Work competencies and abilities (e.g., project management, data analysis, customer service, teaching, research)
    - industrySkills: Domain-specific knowledge (e.g., healthcare compliance, financial regulations, manufacturing processes)
    
    Separate into required vs preferred based on language like:
    - Required: "must have", "required", "essential", "mandatory"
    - Preferred: "nice to have", "preferred", "bonus", "plus", "desired"
    
    Extract all skills, tools, and competencies for the role.
    """
    
    // Individual evaluation prompts for 4-round assessment
    static let yearsEvaluationPrompt = """
    Evaluate ONLY Years of Experience:
    
    **Why they fit:** [List relevant experience from resume]
    **Why they don't fit:** [Experience gaps, if any]
    **Fit Score:** [0-3]
    **Gap Score:** [0-3]
    
    FIT SCORING: 0=None, 1=Some, 2=Good, 3=Strong
    
    GAP SCORING (IMPORTANT - HIGHER SCORE = BETTER):
    0 = MAJOR gaps (significant deficiencies, many missing requirements)
    1 = MODERATE gaps (some concerns that need attention)
    2 = MINOR gaps (small concerns but manageable)
    3 = NO gaps (fully meets all requirements)
    
    Example: If candidate perfectly matches all requirements, give Gap Score: 3
    """
    
    static let educationEvaluationPrompt = """
    Evaluate ONLY Education:
    
    **Why they fit:** [Degrees and relevance to job]
    **Why they don't fit:** [Educational gaps, if any]
    **Fit Score:** [0-3]
    **Gap Score:** [0-3]
    
    FIT SCORING: 0=None, 1=Some, 2=Good, 3=Strong
    
    GAP SCORING (IMPORTANT - HIGHER SCORE = BETTER):
    0 = MAJOR gaps (significant deficiencies, many missing requirements)
    1 = MODERATE gaps (some concerns that need attention)
    2 = MINOR gaps (small concerns but manageable)
    3 = NO gaps (fully meets all requirements)
    
    Example: If candidate perfectly matches all requirements, give Gap Score: 3
    """
    
    static let technicalSkillsEvaluationPrompt = """
    Evaluate ONLY Technical Skills:
    
    **Why they fit:** [Technical skills that match requirements]
    **Why they don't fit:** [Missing technical skills, if any]
    **Fit Score:** [0-3]
    **Gap Score:** [0-3]
    
    FIT SCORING: 0=None, 1=Some, 2=Good, 3=Strong
    
    GAP SCORING (IMPORTANT - HIGHER SCORE = BETTER):
    0 = MAJOR gaps (significant deficiencies, many missing requirements)
    1 = MODERATE gaps (some concerns that need attention)
    2 = MINOR gaps (small concerns but manageable)
    3 = NO gaps (fully meets all requirements)
    
    Example: If candidate perfectly matches all requirements, give Gap Score: 3
    """
    
    static let relevantExperienceEvaluationPrompt = """
    Evaluate ONLY Relevant Experience:
    
    **Why they fit:** [Industry/role experience that aligns]
    **Why they don't fit:** [Relevant experience gaps, if any]
    **Fit Score:** [0-3]
    **Gap Score:** [0-3]
    
    FIT SCORING: 0=None, 1=Some, 2=Good, 3=Strong
    
    GAP SCORING (IMPORTANT - HIGHER SCORE = BETTER):
    0 = MAJOR gaps (significant deficiencies, many missing requirements)
    1 = MODERATE gaps (some concerns that need attention)
    2 = MINOR gaps (small concerns but manageable)
    3 = NO gaps (fully meets all requirements)
    
    Example: If candidate perfectly matches all requirements, give Gap Score: 3
    """
    
    // Helper function for Guided Generation
    static func createCleaningPrompt(text: String, isResume: Bool) -> String {
        let docType = isResume ? "RESUME" : "JOB DESCRIPTION"
        return """
        Extract and structure this \(docType.lowercased()) following the format requirements:
        
        === RAW \(docType) ===
        \(text)
        
        === END RAW \(docType) ===
        
        Provide complete structured data extraction.
        """
    }
    
    // MARK: - Single Run Comprehensive Evaluation
    static let comprehensiveEvaluationPrompt = """
    Evaluate this candidate comprehensively in a single analysis.
    
    JOB DESCRIPTION:
    {jobDescription}
    
    RESUME:
    {resume}
    
    SCORING SYSTEM (READ THIS FIRST):
    - Fit Score: 0=None, 1=Some, 2=Good, 3=Strong
    - Gap Score: 0=Major gaps, 1=Moderate gaps, 2=Minor gaps, 3=No gaps
    - Higher Gap Score = Better (fewer gaps)
    
    FIT SCORING: 0=None, 1=Some, 2=Good, 3=Strong
    
    GAP SCORING (IMPORTANT - HIGHER SCORE = BETTER):
    0 = MAJOR gaps (significant deficiencies, many missing requirements)
    1 = MODERATE gaps (some concerns that need attention)
    2 = MINOR gaps (small concerns but manageable)
    3 = NO gaps (fully meets all requirements)
    
    Example: If candidate perfectly matches all requirements, give Gap Score: 3
    
    Provide scores for ALL criteria in this exact format:
    
    IMPORTANT: Use the exact format below with **bold labels** and [bracketed placeholders].
    
    ## YEARS OF EXPERIENCE EVALUATION
    **Why they fit:** [List relevant experience from resume]
    **Why they don't fit:** [Experience gaps, if any]
    **Fit Score:** [0-3]
    **Gap Score:** [0-3]
    
    Evaluate ONLY Years of Experience using the scoring system above.
    
    ## EDUCATION EVALUATION  
    **Why they fit:** [Degrees and relevance to job]
    **Why they don't fit:** [Educational gaps, if any]
    **Fit Score:** [0-3]
    **Gap Score:** [0-3]
    
    Evaluate ONLY Education using the scoring system above.
    
    ## TECHNICAL SKILLS EVALUATION
    **Why they fit:** [Technical skills that match requirements]
    **Why they don't fit:** [Missing technical skills, if any]
    **Fit Score:** [0-3]
    **Gap Score:** [0-3]
    
    Evaluate ONLY Technical Skills using the scoring system above.
    
    ## RELEVANT EXPERIENCE EVALUATION
    **Why they fit:** [Industry/role experience that aligns]
    **Why they don't fit:** [Relevant experience gaps, if any]
    **Fit Score:** [0-3]
    **Gap Score:** [0-3]
    
    Evaluate ONLY Relevant Experience using the scoring system above.
    
    ## FINAL SUMMARY
    **Overall Fit Score:** [0-3]
    **Overall Gap Score:** [0-3]
    **Recommendation:** [Brief summary of candidate fit]
    
    Be specific and cite evidence from both documents.
    """
    
    static func createComprehensiveEvaluationPrompt(cleanedResume: String, cleanedJob: String) -> String {
        return comprehensiveEvaluationPrompt
            .replacingOccurrences(of: "{resume}", with: cleanedResume)
            .replacingOccurrences(of: "{jobDescription}", with: cleanedJob)
    }
    
    static func createYearsEvaluationPrompt(cleanedResume: String, cleanedJob: String) -> String {
        return """
        JOB:\n\(cleanedJob)\n\nRESUME:\n\(cleanedResume)\n\nEvaluate years of experience only.
        """
    }
    
    static func createEducationEvaluationPrompt(cleanedResume: String, cleanedJob: String) -> String {
        return """
        JOB:\n\(cleanedJob)\n\nRESUME:\n\(cleanedResume)\n\nEvaluate education only.
        """
    }
    
    static func createTechnicalSkillsEvaluationPrompt(cleanedResume: String, cleanedJob: String) -> String {
        return """
        JOB:\n\(cleanedJob)\n\nRESUME:\n\(cleanedResume)\n\nEvaluate technical skills only.
        """
    }
    
    static func createRelevantExperienceEvaluationPrompt(cleanedResume: String, cleanedJob: String) -> String {
        return """
        JOB:\n\(cleanedJob)\n\nRESUME:\n\(cleanedResume)\n\nEvaluate relevant experience only.
        """
    }
}

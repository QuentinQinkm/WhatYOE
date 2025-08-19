//
//  PromptTemplates.swift
//  WhatYOE Desktop
//
//  Easy-to-modify AI prompts
//

import Foundation

struct PromptTemplates {
    
    // (Legacy analysis prompts removed)
}

// (Legacy configuration switch removed)

// MARK: - New Pipeline Prompts
extension PromptTemplates {
    
    // RESUME CLEANING PROMPT  
    static let resumeCleaningPrompt = """
    Extract resume data into CleanedResume format.
    
    PROFESSIONAL EXPERIENCE: Separate into:
    1. Work Experience: Employment, internships, freelance work (paid positions)
    2. Other Experience: Projects, volunteer work, research, academic projects, open-source contributions, hackathons, side projects
    
    YEARS OF EXPERIENCE CALCULATION - CRITICAL:
    Calculate WORK YOE accurately by:
    1. Identify ONLY paid work: employment, internships, freelance jobs
    2. For each job, calculate duration in years (end date - start date)
    3. Sum all work durations
    4. If jobs overlap in time, count the overlapping period only ONCE
    5. Do NOT count: projects, volunteer work, education, unemployment gaps
    6. Be conservative - when in doubt, use the lower estimate
    7. Cap final result at 8.0 years maximum
    
    - workYOE: Total years of paid work experience (be precise, not inflated)
    - workYOECalculation: Show each job's duration calculation step-by-step
    - totalYOEIncludingProjects: Add project experience using conversions (6+ months = 1.0x, 2-6 months = 0.5x, <2 months = 0.1x)
    - excludedGaps: List unemployment periods that were excluded
    
    SKILLS: Extract all skills, tools, and competencies mentioned:
    - technicalSkills: Any tools, software, technologies, programming languages, platforms, equipment, instruments, systems
    - professionalSkills: Work-related competencies and abilities
    - industrySkills: Domain-specific knowledge and expertise
    
    Be thorough and capture ALL experience types with specific skills and tools mentioned.
    """
    
    // JOB DESCRIPTION CLEANING PROMPT
    static let jobCleaningPrompt = """
    Extract job posting data into CleanedJobDescription format.
    
    For requiredSkills and preferredSkills, extract all skills mentioned:
    - technicalSkills: Any tools, software, technologies, equipment, systems mentioned
    - professionalSkills: Work competencies and abilities
    - industrySkills: Domain-specific knowledge
    
    Separate into required vs preferred based on language:
    - Required: "must have", "required", "essential", "mandatory"
    - Preferred: "nice to have", "preferred", "bonus", "plus", "desired"
    
    Extract all skills, tools, and competencies for the role.
    """
    
    // (Legacy 4-round section prompts removed)
    
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
    
    // (Legacy single-run comprehensive evaluation prompts removed)
    
    // (Legacy per-criterion creators removed)
}

// Legacy 4-variable system removed - now using unified 5-variable system

// MARK: - New 5-variable System Prompts
extension PromptTemplates {
    
    /// Single-round LLM evaluation for all 3 scoring dimensions
    static let fiveVariableLLMSystemPrompt = """
    Rate candidate on 3 dimensions (0-4 scale):

    ExpScore: Experience relevance to job's core tasks
    - 0: No relevant experience, 1: Minimal relevance, 2: Moderate relevance, 3: Strong relevance, 4: Excellent relevance

    EduScore: Education relevance to job requirements  
    - 0: No relevant education, 1: Some relevant coursework, 2: Related degree, 3: Required degree, 4: Advanced degree

    SkillScore: Overall proficiency in required skills
    - 0: Missing critical skills, 1: Some skills with gaps, 2: Meets basic requirements, 3: Strong match, 4: Excellent coverage

    Focus on RELEVANCE and QUALITY. Provide concise rationales (max 2-3 lines each).
    """
    
    static func createFiveVariableLLMPrompt(resume: String, job: String) -> String {
        return """
        === JOB DESCRIPTION ===
        \(job)

        === RESUME ===
        \(resume)
        """
    }
    
    /// Resume parsing for actual YOE extraction
    static let resumeYOEParsingSystemPrompt = """
    You are an expert resume parser. Extract and calculate total relevant years of experience from the resume.

    CALCULATION RULES:
    1. Extract work experience sections
    2. Calculate total relevant years (avoid double-counting overlaps)
    3. Include project experience using standard conversion:
       - Major projects (6+ months): count as work experience
       - Moderate projects (2-6 months): count as 0.5x
       - Minor projects (<2 months): count as 0.1x
    4. Cap at 8.0 years maximum
    5. Return confidence score (0-1) for validation
    6. Provide brief explanation of calculation

    Be systematic and thorough in your analysis.
    """
    
    static func createResumeYOEParsingPrompt(resume: String) -> String {
        return """
        === RESUME ===
        \(resume)
        
        Parse this resume and calculate the total relevant years of experience.
        """
    }
}

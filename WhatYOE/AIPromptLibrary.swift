//
//  AIPromptLibrary.swift
//  WhatYOE
//
//  AI Prompt Templates for 5-Variable Scoring System
//  Central repository for all AI prompts used in candidate evaluation
//

import Foundation

/// Central repository for all AI prompts used in the WhatYOE evaluation system
///
/// **System Architecture:**
/// • Resume Cleaning: Multi-step AI extraction (Contact → Experience → Education → Skills)  
/// • Job Cleaning: Single-step structured extraction of job requirements
/// • 5-Variable Evaluation: LLM scoring + YOE calculation for final candidate assessment
///
/// **Design Principles:**
/// • Separate AI calls for improved reliability and reduced hallucination
/// • Structured outputs using @Generable guided generation
/// • Job-specific YOE calculation (not resume-level)
struct AIPromptLibrary {}

// MARK: - Resume Cleaning Prompts

extension AIPromptLibrary {
    
    // MARK: Multi-Step Resume Cleaning Pipeline
    
    /// Master resume cleaning prompt - Used when doing single-step cleaning
    ///
    /// **Purpose:** Complete resume extraction in one AI call (fallback method)
    /// **Output:** CleanedResume structure
    /// **Usage:** Backup method when multi-step pipeline is not available
    /// **Note:** YOE calculation is intentionally skipped - calculated job-specifically
    static let resumeCleaningPrompt = """
    Extract resume data into CleanedResume format.
    
    PROFESSIONAL EXPERIENCE: Separate into:
    1. Work Experience: Employment, internships, freelance work (paid positions)
    2. Other Experience: Projects, volunteer work, research, academic projects, open-source contributions, hackathons, side projects
    
    YEARS OF EXPERIENCE CALCULATION - SKIP THIS SECTION:
    Do NOT calculate YOE during resume cleaning. 
    This will be calculated job-specifically during evaluation phase.
    Set all YOE fields to 0 and leave calculation strings empty.
    
    SKILLS: Extract all skills, tools, and competencies mentioned:
    - technicalSkills: Any tools, software, technologies, programming languages, platforms, equipment, instruments, systems
    - professionalSkills: Work-related competencies and abilities
    - industrySkills: Domain-specific knowledge and expertise
    
    Be thorough and capture ALL experience types with specific skills and tools mentioned.
    """
    
    // MARK: Step-by-Step Resume Cleaning Prompts
    
    /// Step 1: Contact Information and Summary Extraction
    ///
    /// **Purpose:** Extract basic contact details and professional summary
    /// **Output:** ContactAndSummaryExtraction structure
    /// **Next Step:** Professional experience extraction
    static let contactAndSummaryExtractionPrompt = """
    Extract contact information and professional summary from this resume.
    
    CONTACT INFORMATION:
    - Look in header, footer, and contact sections
    - Extract name, email, phone if available
    - Do not make assumptions if information is not clearly present
    
    PROFESSIONAL SUMMARY:
    - Extract summary, objective, or profile statement if present
    - Look at the top of resume after contact information
    - Leave null if no clear summary section exists
    
    Focus only on contact details and summary - ignore experience, education, and skills for this step.
    """
    
    /// Step 2: Professional Experience Extraction  
    ///
    /// **Purpose:** Extract and categorize all professional experience
    /// **Output:** ProfessionalExperience structure
    /// **Critical:** Proper categorization of paid vs unpaid experience
    static let professionalExperienceExtractionPrompt = """
    Extract professional experience from this resume, categorizing carefully:
    
    WORK EXPERIENCE (Paid positions only):
    - Employment (full-time, part-time, contract)
    - Internships (paid or unpaid internships)
    - Freelance work and consulting
    - Any position with a salary or compensation
    
    OTHER EXPERIENCE (Non-paid but relevant):
    - Personal projects and side projects
    - Volunteer work and community service  
    - Research projects (academic or independent)
    - Open-source contributions
    - Hackathons and competitions
    - Academic projects with practical applications
    
    For each entry, extract:
    - Accurate date ranges in YYYY-MM format
    - Key achievements and technologies used
    - Specific accomplishments and outcomes
    
    Be comprehensive - capture ALL relevant experience that demonstrates skills.
    """
    
    /// Step 3: Education Extraction
    ///
    /// **Purpose:** Extract educational background information  
    /// **Output:** EducationExtraction structure
    /// **Focus:** All formal education, certifications, and training
    static let educationExtractionPrompt = """
    Extract education information from this resume:
    
    EDUCATION ENTRIES TO FIND:
    - Degrees: Bachelor's, Master's, PhD, Associate, etc.
    - Certifications: Professional, technical, industry certifications
    - Training programs: Bootcamps, courses, workshops
    - Academic achievements: Dean's list, honors, awards
    
    For each entry, extract:
    - Institution name (university, college, training provider)
    - Degree or certification type
    - Field of study or specialization  
    - Graduation year or completion date
    
    Include both completed and in-progress education.
    """
    
    /// Step 4: Skills Extraction
    ///
    /// **Purpose:** Comprehensive skills categorization
    /// **Output:** Skills structure  
    /// **Critical:** Proper categorization for job matching accuracy
    static let skillsExtractionPrompt = """
    Extract all skills mentioned in this resume, categorizing them properly:
    
    TECHNICAL SKILLS:
    - Programming languages (Python, Java, JavaScript, etc.)
    - Software and tools (Excel, Photoshop, AutoCAD, etc.)
    - Platforms and frameworks (React, Django, AWS, etc.)
    - Databases and systems (MySQL, Salesforce, SAP, etc.)
    - Equipment and instruments (lab equipment, machinery, etc.)
    
    PROFESSIONAL SKILLS:
    - Leadership and management
    - Communication and presentation
    - Project management and organization
    - Problem-solving and analytical thinking
    - Teamwork and collaboration
    
    INDUSTRY SKILLS:
    - Domain-specific knowledge (financial modeling, clinical trials, etc.)
    - Regulatory knowledge (FDA, SOX, GDPR, etc.)
    - Industry methodologies (Agile, Six Sigma, etc.)
    - Sector expertise (healthcare, fintech, manufacturing, etc.)
    
    Extract ALL skills mentioned throughout the resume - in experience descriptions, skills sections, and project details.
    """
    
    // MARK: Generic Cleaning Helper
    
    /// Generic document cleaning prompt builder
    ///
    /// **Purpose:** Helper function for building cleaning prompts  
    /// **Usage:** Creates structured extraction prompts for any document type
    /// **Parameters:** text (document content), isResume (document type flag)
    static func createCleaningPrompt(text: String, isResume: Bool) -> String {
        let docType = isResume ? "RESUME" : "JOB DESCRIPTION"
        return """
        Extract and structure this \(docType.lowercased()) following the format requirements:
        
        === RAW \(docType) ===
        \(text)
        
        === END RAW \(docType) ===
        
        Provide complete structured data extraction according to the defined output format.
        """
    }
}

// MARK: - Job Description Cleaning Prompts

extension AIPromptLibrary {
    
    /// Job description cleaning and structuring prompt
    ///
    /// **Purpose:** Extract structured data from job postings
    /// **Output:** CleanedJobDescription structure
    /// **Critical:** Separate required vs preferred skills for accurate evaluation
    static let jobCleaningPrompt = """
    Extract job posting data into CleanedJobDescription format.
    
    SKILLS EXTRACTION - CRITICAL DISTINCTION:
    
    REQUIRED SKILLS (mandatory for the role):
    - Look for language: "must have", "required", "essential", "mandatory", "needed"
    - Extract technical, professional, and industry skills separately
    - These are skills without which the candidate would be rejected
    
    PREFERRED SKILLS (nice to have):  
    - Look for language: "nice to have", "preferred", "bonus", "plus", "desired", "preferred"
    - Extract technical, professional, and industry skills separately
    - These are skills that would make the candidate stand out
    
    EXPERIENCE REQUIREMENTS:
    - Extract minimum years of experience if specified
    - Determine experience level: Entry, Mid, Senior, Lead, Executive
    - Note any industry-specific experience requirements
    
    RESPONSIBILITIES:
    - Extract key duties and responsibilities
    - Focus on core job functions and expectations
    - Include both technical and soft skill requirements
    
    Be thorough and accurate - this data drives the entire evaluation process.
    """
}

// MARK: - 5-Variable Evaluation System Prompts  

extension AIPromptLibrary {
    
    // MARK: LLM Evaluation Prompts
    
    /// System prompt for 5-Variable LLM evaluation
    ///
    /// **Purpose:** AI scoring across 3 dimensions (Experience, Education, Skills)
    /// **Scale:** 0-4 for each dimension  
    /// **Output:** LLMScoringOutput with scores and rationales
    /// **Focus:** Relevance and quality over quantity
    static let fiveVariableLLMSystemPrompt = """
    You are an expert recruiter evaluating candidate fit for a specific job.
    Rate the candidate on 3 dimensions using a 0-4 scale:

    EXPERIENCE SCORE (0-4): Experience relevance to job's core tasks
    - 0: No relevant experience at all
    - 1: Minimal relevance - some transferable skills but not directly applicable  
    - 2: Moderate relevance - decent background but missing key areas
    - 3: Strong relevance - most experience aligns well with job requirements
    - 4: Excellent relevance - experience exceeds job requirements, perfect match

    EDUCATION SCORE (0-4): Education relevance to job requirements
    - 0: No relevant education or background
    - 1: Some relevant coursework or self-study
    - 2: Related degree but not exact match for job field
    - 3: Required degree obtained, matches job requirements
    - 4: Advanced degree exceeding requirements, specialized expertise

    SKILLS SCORE (0-4): Overall proficiency in required skills  
    - 0: Missing most critical skills needed for the role
    - 1: Has some required skills but major gaps in critical areas
    - 2: Meets basic requirements but has some gaps
    - 3: Strong skill match with only minor gaps
    - 4: Excellent skill coverage exceeding job requirements

    EVALUATION PRINCIPLES:
    - Focus on RELEVANCE and QUALITY, not just quantity
    - Consider transferable skills from adjacent fields
    - Weight recent and directly applicable experience more heavily
    - Provide concise rationales (max 2-3 lines each)
    - Be objective and consistent in scoring
    """
    
    /// User prompt builder for LLM evaluation with raw text
    ///
    /// **Purpose:** Creates evaluation prompt from raw resume + job text
    /// **Usage:** Primary evaluation method for raw document input
    /// **Output:** Formatted prompt for AI evaluation
    static func createFiveVariableLLMPrompt(resume: String, job: String) -> String {
        return """
        === JOB DESCRIPTION ===
        \(job)

        === CANDIDATE RESUME ===
        \(resume)
        
        Evaluate this candidate's fit for the job using the 3-dimension scoring system.
        """
    }
    
    // MARK: YOE Calculation Prompts
    
    /// System prompt for job-relevant YOE extraction
    ///
    /// **Purpose:** Calculate years of experience specifically relevant to target job
    /// **Output:** ResumeParsingResult with YOE calculation and confidence
    /// **Method:** Weighted calculation with work (1.0x) + projects (0.5x)
    static let resumeYOEParsingSystemPrompt = """
    You are an expert resume parser specializing in job-relevant experience calculation.
    Extract and calculate total relevant years of experience from the candidate's background.

    CALCULATION METHODOLOGY:
    
    1. WORK EXPERIENCE (1.0x weight):
       - Employment (full-time, part-time, contract)
       - Internships (paid or unpaid)
       - Freelance and consulting work
       - Any professional role with responsibilities
    
    2. PROJECT EXPERIENCE (weighted calculation):
       - Major projects (6+ months): count as 1.0x 
       - Moderate projects (2-6 months): count as 0.5x
       - Minor projects (<2 months): count as 0.1x
    
    3. OVERLAP HANDLING:
       - If experiences overlap in time, count the period only ONCE
       - Use the more relevant experience for overlapping periods
       - Be conservative with estimates
    
    4. RELEVANCE FILTERING:
       - Focus on experience relevant to typical professional roles
       - Include transferable skills from adjacent fields
       - Exclude pure academic study time (but include research with deliverables)
    
    5. CONSTRAINTS:
       - Cap final result at 8.0 years maximum
       - Provide confidence score (0-1) for your calculation accuracy
       - Explain your calculation step-by-step
    
    Be systematic, thorough, and conservative in your analysis.
    """
    
    /// User prompt builder for YOE calculation
    ///
    /// **Purpose:** Creates YOE calculation prompt from resume text
    /// **Usage:** YOE extraction for Variable 2 in scoring system
    static func createResumeYOEParsingPrompt(resume: String) -> String {
        return """
        === CANDIDATE RESUME ===
        \(resume)
        
        Analyze this resume and calculate the total job-relevant years of experience.
        Provide a detailed breakdown of your calculation methodology.
        """
    }
    
    // MARK: Required YOE Extraction (Variable 1)
    
    /// System prompt for Required YOE extraction from job descriptions (Variable 1)
    ///
    /// **Purpose:** Extract minimum required years of experience from job postings
    /// **Output:** RequiredYOEResult with extracted number + confidence + explanation
    /// **Usage:** Variable 1 extraction for 5-variable scoring system
    static let requiredYOEExtractionSystemPrompt = """
    You are an expert recruiter specializing in parsing job requirements.
    Your job is to extract the MINIMUM required years of experience from job descriptions.
    
    EXTRACTION GUIDELINES:
    1. LOOK FOR PHRASES:
       - "X+ years of experience"
       - "Minimum X years" 
       - "At least X years"
       - "X years required"
       - "X years minimum"
    
    2. EXPERIENCE LEVEL MAPPING (if no specific number):
       - Entry-level/Junior: 0 years
       - Mid-level/Intermediate: 3 years  
       - Senior: 5 years
       - Lead/Principal: 7 years
       - Executive/Director: 10 years
    
    3. EXTRACTION RULES:
       - If multiple numbers mentioned, use the MINIMUM requirement
       - Focus on general experience, not tool-specific (e.g., "5 years experience" not "2 years Python")
       - If range given (e.g., "3-5 years"), use the lower number (3)
       - Cap result at 8.0 years maximum
    
    4. CONFIDENCE SCORING:
       - 1.0: Explicit number stated clearly
       - 0.8: Clear level indicator (Senior, Mid-level)
       - 0.6: Implied from context/responsibilities  
       - 0.4: Uncertain/ambiguous posting
    
    Extract the number as accurately as possible with explanation of your reasoning.
    """
    
    // MARK: Advanced Job-Specific YOE Calculation
    
    /// System prompt for job-specific YOE calculation
    ///
    /// **Purpose:** Calculate YOE specifically relevant to a target job's requirements  
    /// **Output:** More precise YOE calculation considering job context
    /// **Usage:** Advanced evaluation pipeline for higher accuracy
    static let jobSpecificYOEParsingSystemPrompt = """
    You are an expert at calculating job-relevant experience for specific roles.
    Calculate years of experience specifically applicable to the target job requirements.

    JOB-SPECIFIC CALCULATION RULES:
    
    1. DIRECT RELEVANCE (1.0x weight):
       - Experience in same role or very similar positions
       - Direct use of required technologies and skills
       - Same industry or domain experience
    
    2. TRANSFERABLE RELEVANCE (0.7x weight):
       - Adjacent roles with overlapping responsibilities  
       - Related technologies or methodologies
       - Cross-industry but applicable skills
    
    3. PROJECT RELEVANCE (0.5x weight):
       - Projects using job-required technologies
       - Academic or personal projects with real-world application
       - Open-source contributions in relevant domains
    
    4. CONTEXT CONSIDERATIONS:
       - Weight recent experience more heavily
       - Consider the job's seniority level expectations
       - Account for technology evolution and relevance
    
    5. PRECISION REQUIREMENTS:
       - Be more selective than general YOE calculation
       - Focus on quality and direct applicability
       - Provide higher confidence for closely matched experience
    
    Calculate with job context in mind for maximum accuracy.
    """
    
    /// User prompt builder for job-specific YOE calculation
    ///
    /// **Purpose:** Creates job-aware YOE calculation prompt
    /// **Usage:** Advanced pipeline for job-specific experience assessment
    static func createJobSpecificYOEParsingPrompt(resume: String, jobContext: String) -> String {
        return """
        === TARGET JOB REQUIREMENTS ===
        \(jobContext)
        
        === CANDIDATE RESUME ===
        \(resume)
        
        Calculate years of experience specifically relevant to this job's requirements.
        Focus on directly applicable experience and transferable skills.
        """
    }
}

// MARK: - Prompt Template Usage Guide

extension AIPromptLibrary {
    
    /// Usage documentation for prompt templates
    ///
    /// **Purpose:** Developer reference for prompt template usage
    /// **Content:** Guidelines for proper prompt template selection and usage
    static let usageGuide = """
    PROMPT TEMPLATE USAGE GUIDE:
    
    RESUME CLEANING PIPELINE:
    1. Use contactAndSummaryExtractionPrompt for Step 1
    2. Use professionalExperienceExtractionPrompt for Step 2  
    3. Use educationExtractionPrompt for Step 3
    4. Use skillsExtractionPrompt for Step 4
    5. Fallback: Use resumeCleaningPrompt for single-step cleaning
    
    JOB DESCRIPTION CLEANING:
    - Use jobCleaningPrompt for all job description structuring
    
    CANDIDATE EVALUATION:
    - Use fiveVariableLLMSystemPrompt + createFiveVariableLLMPrompt() for scoring
    - Use resumeYOEParsingSystemPrompt + createResumeYOEParsingPrompt() for YOE
    - Advanced: Use job-specific YOE prompts for higher precision
    
    DESIGN PRINCIPLES:
    - Multiple AI calls = better reliability, less hallucination
    - Structured outputs ensure consistent data format
    - Job-specific calculations improve evaluation accuracy
    - Clear role separation prevents prompt confusion
    """
}
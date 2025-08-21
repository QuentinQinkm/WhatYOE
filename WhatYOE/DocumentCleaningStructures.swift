//
//  DocumentCleaningStructures.swift
//  WhatYOE
//
//  Data Structures for Resume and Job Description Cleaning
//  Multi-step AI extraction pipeline structures
//

import Foundation
import FoundationModels

// MARK: - File Overview
/*
 This file defines the data structures for the AI-powered document cleaning pipeline:
 
 RESUME CLEANING STRUCTURES:
 • CleanedResume - Final complete resume structure
 • ContactInfo, ProfessionalExperience, Education, Skills - Component structures
 • Multi-step extraction helpers for pipeline processing
 
 JOB DESCRIPTION STRUCTURES:
 • CleanedJobDescription - Final complete job posting structure  
 • ExperienceRequirements - Job experience requirements structure
 
 YOE CALCULATION STRUCTURES:
 • YearsOfExperienceCalculation - Resume-level YOE (intentionally skipped in cleaning)
 • JobRelevantYOECalculation - Job-specific YOE calculation
 
 Note: Resume cleaning intentionally skips YOE calculation - YOE is calculated job-specifically during evaluation
 */

// MARK: - Resume Cleaning Structures

/// Complete cleaned resume structure - Final output of multi-step resume cleaning pipeline
/// **Pipeline:** ContactInfo → Experience → Education → Skills → Final Assembly
/// **Used by:** Resume cleaning pipeline, candidate evaluation functions
@Generable
struct CleanedResume {
    @Guide(description: "Contact information: name, email, phone extracted from resume header/footer")
    let contactInfo: ContactInfo
    
    @Guide(description: "Professional summary or objective statement if present in resume")
    let summary: String?
    
    @Guide(description: "Professional experience categorized into work vs other experience types")
    let professionalExperience: ProfessionalExperience
    
    @Guide(description: "YOE calculation - NOTE: This is intentionally skipped during resume cleaning and calculated job-specifically during evaluation")
    let yearsOfExperience: YearsOfExperienceCalculation
    
    @Guide(description: "Educational background: degrees, institutions, graduation dates")
    let education: [Education]
    
    @Guide(description: "Comprehensive skills extraction categorized by type")
    let skills: Skills
    
    @Guide(description: "Professional certifications, licenses, and training programs")
    let certifications: [String]
}

// MARK: - Contact Information

/// Contact details extracted from resume header/footer
/// **Extraction Step:** 1 (First step in multi-step pipeline)
@Generable
struct ContactInfo {
    @Guide(description: "Full name as it appears on the resume")
    let name: String
    
    @Guide(description: "Email address if available in resume")
    let email: String?
    
    @Guide(description: "Phone number if available in resume")
    let phone: String?
}

// MARK: - Professional Experience Structures

/// Professional experience container separating work from other experience types
/// **Extraction Step:** 2 (Second step in multi-step pipeline)
/// **Critical Distinction:** Work experience (paid) vs Other experience (projects, volunteer, etc.)
@Generable
struct ProfessionalExperience {
    @Guide(description: "PAID work experience: employment, internships, freelance work, consulting")
    let workExperience: [WorkExperience]
    
    @Guide(description: "OTHER experience: projects, volunteer work, research, academic work, open-source contributions")
    let otherExperience: [OtherExperience]
}

/// Work experience entry - Paid professional positions only
@Generable
struct WorkExperience {
    @Guide(description: "Company, organization, or client name")
    let company: String
    
    @Guide(description: "Job title, role, or position held")
    let role: String
    
    @Guide(description: "Start date in YYYY-MM format for consistent parsing")
    let startDate: String
    
    @Guide(description: "End date in YYYY-MM format, or null if currently employed")
    let endDate: String?
    
    @Guide(description: "Key achievements, responsibilities, and accomplishments in this role")
    let keyAchievements: [String]
}

/// Other experience entry - Non-paid but relevant experience
@Generable
struct OtherExperience {
    @Guide(description: "Title/name of the experience: project name, volunteer role, research title")
    let title: String
    
    @Guide(description: "Context/organization: 'Personal Project', 'University Research', 'Volunteer at XYZ', etc.")
    let organization: String?
    
    @Guide(description: "Experience type: project, volunteer, research, freelance, academic, open-source, hackathon")
    let experienceType: String
    
    @Guide(description: "Start date in YYYY-MM format if available")
    let startDate: String?
    
    @Guide(description: "End date in YYYY-MM format, or null if ongoing")
    let endDate: String?
    
    @Guide(description: "Brief description of what was accomplished or learned")
    let description: String
    
    @Guide(description: "Technologies, tools, languages, frameworks used")
    let technologiesUsed: [String]
    
    @Guide(description: "Key outcomes, results, or deliverables achieved")
    let achievements: [String]
}

// MARK: - Education Structure

/// Educational background entry
/// **Extraction Step:** 3 (Third step in multi-step pipeline)
@Generable
struct Education {
    @Guide(description: "Name of educational institution, university, college, or school")
    let institution: String
    
    @Guide(description: "Degree type: Bachelor's, Master's, PhD, Certificate, Diploma, etc.")
    let degree: String
    
    @Guide(description: "Field of study, major, or specialization")
    let field: String?
    
    @Guide(description: "Graduation year or expected graduation year")
    let year: String?
}

// MARK: - Skills Structure

/// Comprehensive skills categorization
/// **Extraction Step:** 4 (Fourth step in multi-step pipeline)
/// **Purpose:** Categorize all skills for better job matching accuracy
@Generable
struct Skills {
    @Guide(description: "Technical skills: programming languages, software, tools, platforms, frameworks, databases, cloud services")
    let technicalSkills: [String]
    
    @Guide(description: "Professional skills: leadership, communication, project management, problem-solving, analytical thinking")
    let professionalSkills: [String]
    
    @Guide(description: "Industry/domain skills: financial modeling, clinical research, marketing strategy, legal compliance")
    let industrySkills: [String]
}

// MARK: - YOE Calculation Structures

/// Years of Experience calculation structure (INTENTIONALLY SKIPPED during resume cleaning)
/// **Important:** This structure exists for completeness but is not used during resume cleaning
/// **Reason:** YOE must be calculated job-specifically during evaluation phase for accuracy
@Generable
struct YearsOfExperienceCalculation {
    @Guide(description: "INTENTIONALLY EMPTY: YOE calculation is deferred to job-specific evaluation phase")
    let workYOE: Double
    
    @Guide(description: "INTENTIONALLY EMPTY: Detailed calculation will be done job-specifically")
    let workYOECalculation: String
    
    @Guide(description: "INTENTIONALLY EMPTY: Project experience assessment is job-dependent") 
    let totalYOEIncludingProjects: Double
    
    @Guide(description: "INTENTIONALLY EMPTY: Gap analysis is job-specific")
    let excludedGaps: [String]
}

/// Job-relevant YOE calculation (Used during evaluation phase)
/// **Purpose:** Calculate YOE specifically relevant to target job requirements
/// **Used by:** Job evaluation pipeline for precise experience assessment
@Generable
struct JobRelevantYOECalculation {
    @Guide(description: "Total job-relevant experience: Direct Work YOE + (Other Relevant YOE × 0.5)")
    let actualYOE: Double
    
    @Guide(description: "Detailed breakdown: 'Direct work: 2.0 years (Software Engineer roles). Other relevant: 1.5 years (coding projects). Final: 2.0 + (1.5 × 0.5) = 2.75 years'")
    let calculation: String
    
    @Guide(description: "Years of directly relevant work experience from similar roles and transferable positions")
    let relevantWorkYOE: Double
    
    @Guide(description: "Years of other experience demonstrating job-relevant skills (weighted at 0.5x)")
    let relevantOtherYOE: Double
}

// MARK: - Multi-Step Pipeline Helper Structures

/// Step 1: Contact and summary extraction helper
/// **Purpose:** First step in multi-step resume cleaning pipeline
@Generable
struct ContactAndSummaryExtraction {
    @Guide(description: "Contact information from resume header/contact section")
    let contactInfo: ContactInfo
    
    @Guide(description: "Professional summary, objective, or profile statement if present")
    let summary: String?
}

/// Step 3: Education extraction helper  
/// **Purpose:** Dedicated education extraction step for better accuracy
@Generable
struct EducationExtraction {
    @Guide(description: "All education entries found in resume education section")
    let education: [Education]
}

// MARK: - Job Description Structures

/// Complete cleaned job description structure
/// **Purpose:** Structured extraction of job posting requirements and details
/// **Used by:** Job cleaning pipeline, candidate evaluation functions
@Generable
struct CleanedJobDescription {
    @Guide(description: "Job title or position name as listed in posting")
    let title: String
    
    @Guide(description: "Hiring company or organization name")
    let company: String
    
    @Guide(description: "Experience requirements: years, level, industry context")
    let experienceRequired: ExperienceRequirements
    
    @Guide(description: "Required skills that are mandatory for the position")
    let requiredSkills: Skills
    
    @Guide(description: "Preferred skills that are nice-to-have but not mandatory")
    let preferredSkills: Skills?
    
    @Guide(description: "Primary responsibilities and duties for this role")
    let responsibilities: [String]
    
    @Guide(description: "Education requirements: degree level, field, certifications")
    let educationRequirements: String?
}

/// Job experience requirements structure
/// **Purpose:** Structured capture of job's experience expectations
@Generable
struct ExperienceRequirements {
    @Guide(description: "Minimum years of experience required (parsed from job posting)")
    let minimumYears: Int?
    
    @Guide(description: "Experience level: Entry-level, Mid-level, Senior, Lead, Executive")
    let level: String
    
    @Guide(description: "Industry or domain context: fintech, healthcare, e-commerce, etc.")
    let industryContext: String?
}
//
//  GuidedGenerationStructures.swift
//  WhatYOE
//
//  Guided Generation data structures for resume and job cleaning
//

import Foundation
import FoundationModels

// MARK: - Resume Structures

@Generable
struct CleanedResume {
    @Guide(description: "Contact information including name, email, phone")
    let contactInfo: ContactInfo
    
    @Guide(description: "Professional summary or objective statement")
    let summary: String?
    
    @Guide(description: "Professional experience including work and other relevant experience")
    let professionalExperience: ProfessionalExperience
    
    @Guide(description: "Educational background with degrees, institutions, and dates")
    let education: [Education]
    
    @Guide(description: "All skills, tools, and competencies")
    let skills: Skills
    
    @Guide(description: "Professional certifications and training")
    let certifications: [String]
}

@Generable
struct ContactInfo {
    @Guide(description: "Full name of the person")
    let name: String
    
    @Guide(description: "Email address if available")
    let email: String?
    
    @Guide(description: "Phone number if available")
    let phone: String?
}

@Generable
struct ProfessionalExperience {
    @Guide(description: "Work experience including employment, internships, freelance work")
    let workExperience: [WorkExperience]
    
    @Guide(description: "Other relevant experience including projects, volunteer work, research")
    let otherExperience: [OtherExperience]
}

@Generable
struct WorkExperience {
    @Guide(description: "Company or organization name")
    let company: String
    
    @Guide(description: "Job title or role")
    let role: String
    
    @Guide(description: "Start date in YYYY-MM format")
    let startDate: String
    
    @Guide(description: "End date in YYYY-MM format, or null if current")
    let endDate: String?
    
    @Guide(description: "Key achievements and responsibilities")
    let keyAchievements: [String]
}

@Generable
struct OtherExperience {
    @Guide(description: "Title or name of the experience (project name, volunteer role, research title)")
    let title: String
    
    @Guide(description: "Organization, institution, or context (e.g., 'Personal Project', 'University Research', 'Volunteer at XYZ')")
    let organization: String?
    
    @Guide(description: "Type of experience: project, volunteer, research, freelance, academic, etc.")
    let experienceType: String
    
    @Guide(description: "Start date in YYYY-MM format")
    let startDate: String?
    
    @Guide(description: "End date in YYYY-MM format, or null if ongoing")
    let endDate: String?
    
    @Guide(description: "Brief description of the experience")
    let description: String
    
    @Guide(description: "Technologies and tools used")
    let technologiesUsed: [String]
    
    @Guide(description: "Key achievements and outcomes")
    let achievements: [String]
}

@Generable
struct Education {
    @Guide(description: "Educational institution name")
    let institution: String
    
    @Guide(description: "Degree or qualification obtained")
    let degree: String
    
    @Guide(description: "Field of study or major")
    let field: String?
    
    @Guide(description: "Graduation year")
    let year: String?
}


@Generable
struct Skills {
    @Guide(description: "All technical skills, tools, software, and technologies mentioned")
    let technicalSkills: [String]
    
    @Guide(description: "Professional skills and competencies")
    let professionalSkills: [String]
    
    @Guide(description: "Industry-specific knowledge and expertise")
    let industrySkills: [String]
}


// MARK: - Job Description Structures

@Generable
struct CleanedJobDescription {
    @Guide(description: "Job title or position name")
    let title: String
    
    @Guide(description: "Company or organization name")
    let company: String
    
    @Guide(description: "Experience requirements for the role")
    let experienceRequired: ExperienceRequirements
    
    @Guide(description: "Required skills, tools, and competencies")
    let requiredSkills: Skills
    
    @Guide(description: "Preferred skills that are nice to have")
    let preferredSkills: Skills?
    
    
    @Guide(description: "Key responsibilities and duties")
    let responsibilities: [String]
    
    @Guide(description: "Education requirements if specified")
    let educationRequirements: String?
}

@Generable
struct ExperienceRequirements {
    @Guide(description: "Minimum years of experience required")
    let minimumYears: Int?
    
    @Guide(description: "Experience level (Entry, Mid, Senior, etc.)")
    let level: String
    
    @Guide(description: "Industry or domain context needed")
    let industryContext: String?
}
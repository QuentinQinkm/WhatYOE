//
//  ResumeManager.swift
//  WhatYOE
//
//  Resume storage and management functionality
//

import Foundation

struct ResumeItem {
    let id: String
    let name: String
    let cleanedText: String
    let dateCreated: Date
    
    init(name: String, cleanedText: String) {
        self.id = UUID().uuidString
        self.name = name
        self.cleanedText = cleanedText
        self.dateCreated = Date()
    }
}

class ResumeManager {
    static let shared = ResumeManager()
    
    private let resumesKey = "savedResumes"
    private let userDefaults: UserDefaults
    
    private init() {
        // Use shared app group container
        if let sharedDefaults = UserDefaults(suiteName: "group.com.apple.WhatYOE.shared") {
            self.userDefaults = sharedDefaults
        } else {
            // Fallback to standard UserDefaults if app group not available
            self.userDefaults = UserDefaults.standard
        }
    }
    
    func saveResume(_ resume: ResumeItem) {
        var resumes = getAllResumes()
        
        // Remove any existing resume with the same name
        resumes.removeAll { $0.name == resume.name }
        
        // Add the new resume
        resumes.append(resume)
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(resumes) {
            userDefaults.set(data, forKey: resumesKey)
        }
        
        // Also save the latest as the default for extension
        userDefaults.set(resume.cleanedText, forKey: "cleanedResumeData")
    }
    
    func getAllResumes() -> [ResumeItem] {
        guard let data = userDefaults.data(forKey: resumesKey),
              let resumes = try? JSONDecoder().decode([ResumeItem].self, from: data) else {
            return []
        }
        return resumes.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    func deleteResume(withId id: String) {
        var resumes = getAllResumes()
        resumes.removeAll { $0.id == id }
        
        if let data = try? JSONEncoder().encode(resumes) {
            userDefaults.set(data, forKey: resumesKey)
        }
    }
    
    func getResume(withId id: String) -> ResumeItem? {
        return getAllResumes().first { $0.id == id }
    }
    
    func setActiveResume(_ resume: ResumeItem) {
        userDefaults.set(resume.cleanedText, forKey: "cleanedResumeData")
        userDefaults.set(resume.id, forKey: "activeResumeId")
    }
    
    func getActiveResumeId() -> String? {
        return userDefaults.string(forKey: "activeResumeId")
    }
}

extension ResumeItem: Codable {}
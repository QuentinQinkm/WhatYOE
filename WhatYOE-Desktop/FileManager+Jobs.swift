import Foundation

extension FileManager {
    /// Get the base directory for job storage
    /// Structure: ~/Library/Group Containers/group.com.kuangming.WhatYOE.shared/Jobs/
    static func getJobsBaseDirectory() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kuangming.WhatYOE.shared") else {
            print("❌ [Desktop FileManager] Could not get app group container")
            return nil
        }
        
        let jobsDir = containerURL.appendingPathComponent("Jobs")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: jobsDir, withIntermediateDirectories: true)
        
        return jobsDir
    }
    
    /// Get directory for a specific resume's jobs
    /// Structure: ~/Documents/WhatYOE/Jobs/ResumeID/
    static func getResumeJobsDirectory(resumeId: String) -> URL? {
        guard let baseDir = getJobsBaseDirectory() else { return nil }
        
        let resumeDir = baseDir.appendingPathComponent(resumeId)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: resumeDir, withIntermediateDirectories: true)
        
        return resumeDir
    }
    
    /// Get file path for a specific job
    /// Structure: ~/Documents/WhatYOE/Jobs/ResumeID/JobID.json
    static func getJobFilePath(resumeId: String, jobId: String) -> URL? {
        guard let resumeDir = getResumeJobsDirectory(resumeId: resumeId) else { return nil }
        
        return resumeDir.appendingPathComponent("\(jobId).json")
    }
    
    /// Get all resume IDs that have jobs
    static func getAllResumeIdsWithJobs() -> [String] {
        guard let baseDir = getJobsBaseDirectory() else { 
            print("❌ [FileManager] Could not get jobs base directory")
            return [] 
        }
        
        print("🔍 [FileManager] Jobs base directory: \(baseDir.path)")
        print("🔍 [FileManager] Directory exists: \(FileManager.default.fileExists(atPath: baseDir.path))")
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: baseDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )
            
            print("🔍 [FileManager] Found \(contents.count) items in jobs directory")
            
            let resumeIds = contents.compactMap { url in
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    print("🔍 [FileManager] Found resume directory: \(url.lastPathComponent)")
                    return url.lastPathComponent
                }
                return nil
            }
            
            print("🔍 [FileManager] Resume IDs found: \(resumeIds)")
            return resumeIds
        } catch {
            print("❌ Error reading resume directories: \(error)")
            return []
        }
    }
    
    /// Get all job IDs for a specific resume
    static func getJobIds(forResumeId resumeId: String) -> [String] {
        guard let resumeDir = getResumeJobsDirectory(resumeId: resumeId) else { return [] }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: resumeDir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            
            return contents.compactMap { url in
                if url.pathExtension == "json" {
                    return url.deletingPathExtension().lastPathComponent
                }
                return nil
            }
        } catch {
            print("❌ Error reading job files for resume \(resumeId): \(error)")
            return []
        }
    }
}
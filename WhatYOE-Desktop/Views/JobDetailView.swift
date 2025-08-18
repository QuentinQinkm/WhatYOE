import SwiftUI
import AppKit

struct JobDetailView: View {
    let job: JobItem?
    let horizontalPadding: CGFloat
    let jobs: [JobItem]
    
    var body: some View {
        if let job = job {
            ResumeContentView(
                text: formatJobContent(job),
                bottomLabel: "",
                horizontalPadding: horizontalPadding,
                overlayButtons: {
                    AnyView(
                        VStack(spacing: 0) {
                            // Top row - Edit button position  
                            HStack {
                                Spacer()
                                
                                // Star button (replaces edit position)
                                GlassIconButton(
                                    icon: "star",
                                    color: Color(red: 255/255, green: 193/255, blue: 0/255),
                                    state: .default,
                                    action: {
                                        // Function placeholder - will be added later
                                        print("Star tapped for job: \(job.jobTitle)")
                                    }
                                )
                            }
                            .padding(.bottom, 16)
                            
                            Spacer()
                            
                            // Bottom row - Cancel/Proceed button positions
                            HStack {
                                // Empty space (cancel position)
                                
                                Spacer()
                                
                                // LinkedIn button with icon + text (replaces proceed position)
                                GlassIconTextButton(
                                    icon: "link",
                                    title: "Open in LinkedIn",
                                    color: Color(red: 0/255, green: 119/255, blue: 181/255),
                                    state: .default,
                                    action: {
                                        openLinkedInJob(jobId: job.jobId)
                                    }
                                )
                            }
                        }
                    )
                }
            )
        } else {
            VStack(spacing: 16) {
                Image(systemName: "briefcase")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                if jobs.isEmpty {
                    Text("Please proceed job analysis via the Safari extension")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Select a job to continue")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func formatJobContent(_ job: JobItem) -> String {
        return """
        📊 **Job Analysis Report**
        
        🏢 **Company:** \(job.company)
        💼 **Position:** \(job.jobTitle)
        🔗 **LinkedIn Job ID:** \(job.jobId)
        📅 **Analyzed:** \(DateFormatter.shortDate.string(from: job.dateAnalyzed))
        
        🎯 **Final Score:** \(String(format: "%.1f", job.analysisScores.finalScore)) / 4.0
        
        📋 **Detailed Scores:**
        • Years of Experience: Fit \(String(format: "%.1f", job.analysisScores.yearsOfExperienceFit)) | Gap \(String(format: "%.1f", job.analysisScores.yearsOfExperienceGap))
        • Education: Fit \(String(format: "%.1f", job.analysisScores.educationFit)) | Gap \(String(format: "%.1f", job.analysisScores.educationGap))
        • Technical Skills: Fit \(String(format: "%.1f", job.analysisScores.technicalSkillsFit)) | Gap \(String(format: "%.1f", job.analysisScores.technicalSkillsGap))
        • Relevant Experience: Fit \(String(format: "%.1f", job.analysisScores.relevantExperienceFit)) | Gap \(String(format: "%.1f", job.analysisScores.relevantExperienceGap))
        
        📝 **Job Description:**
        \(job.cleanedJobDescription)
        
        🔍 **Analysis Result:**
        \(job.analysisResult)
        """
    }
    
    private func openLinkedInJob(jobId: String) {
        let linkedinUrl = "https://www.linkedin.com/jobs/view/\(jobId)"
        if let url = URL(string: linkedinUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}
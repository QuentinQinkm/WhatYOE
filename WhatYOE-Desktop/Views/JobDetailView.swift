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
        let score = job.analysisScores.finalScore
        let rating = getRating(for: score)
        
        let rawScoresSection = """
        📋 **5-Variable Scores:**
        • **Experience Score:** \(job.analysisScores.exp_score)/4
        • **Education Score:** \(job.analysisScores.edu_score)/4
        • **Skills Score:** \(job.analysisScores.skill_score)/4
        • **Actual YOE:** \(String(format: "%.1f", job.analysisScores.actual_yoe)) years
        • **Required YOE:** \(String(format: "%.1f", job.analysisScores.required_yoe)) years
        """
        
        return """
        📊 **Job Analysis Report**
        
        🏢 **Company:** \(job.company)
        💼 **Position:** \(job.jobTitle)
        🔗 **LinkedIn Job ID:** \(job.jobId)
        📅 **Analyzed:** \(DateFormatter.shortDate.string(from: job.dateAnalyzed))
        
        🎯 **Final Score:** \(String(format: "%.0f", score)) / 100
        📊 **Rating:** \(rating)
        
        \(rawScoresSection)
        
        📋 **Detailed Analysis:**
        \(job.analysisResult)
        
        📝 **Job Description:**
        \(job.cleanedJobDescription)
        """
    }
    
    private func getRating(for score: Double) -> String {
        if score < 75 { return "❌ Denied" }
        if score < 85 { return "📉 Poor" }
        if score < 93 { return "⚠️ Maybe" }
        return "✅ Good"
    }
    

    
    private func openLinkedInJob(jobId: String) {
        let linkedinUrl = "https://www.linkedin.com/jobs/view/\(jobId)"
        if let url = URL(string: linkedinUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}


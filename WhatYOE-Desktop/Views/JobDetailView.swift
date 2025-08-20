import SwiftUI
import AppKit

struct JobDetailView: View {
    let job: JobItem?
    let horizontalPadding: CGFloat
    let jobs: [JobItem]
    
    var body: some View {
        if let job = job {
            ZStack {
                // Main content with custom layout
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Two-column layout: Job details (left) and Scores/Rationale (right)
                        HStack(alignment: .top, spacing: 24) {
                            // Left column: Job details (stretches to fill available space)
                            VStack(alignment: .leading, spacing: 16) {
                                // Company name and position section
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(job.company)
                                        .font(.title2)
                                        .fontWeight(.light)
                                        .foregroundColor(.black)
                                    Text(job.jobTitle)
                                        .font(.body)
                                        .fontWeight(.light)
                                        .foregroundColor(.black)
                                }
                                
                                // LinkedIn and Like buttons below title, aligned to the left
                                HStack(spacing: 12) {
                                    GlassIconTextButton(
                                        icon: "link",
                                        title: "Open in LinkedIn",
                                        color: Color(red: 0/255, green: 119/255, blue: 181/255),
                                        state: .default,
                                        action: {
                                            openLinkedInJob(jobId: job.jobId)
                                        }
                                    )
                                    
                                    GlassIconButton(
                                        icon: "star",
                                        color: Color(red: 255/255, green: 193/255, blue: 0/255),
                                        state: .default,
                                        action: {
                                            // Function placeholder - will be added later
                                            print("Star tapped for job: \(job.jobTitle)")
                                        }
                                    )
                                    
                                    Spacer()
                                }
                                
                                // Job description
                                VStack(alignment: .leading, spacing: 16) {
                                    Text(job.cleanedJobDescription)
                                        .fontWeight(.light)
                                        .foregroundColor(.black)
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Right column: Scores and Rationale (fixed width)
                            VStack(alignment: .leading, spacing: 16) {
                                // Score section - all scores in one HStack
                                HStack(spacing: 16) {
                                    // Final score and rating
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(String(format: "%.0f", job.analysisScores.finalScore))")
                                            .font(.largeTitle)
                                            .fontWeight(.regular)
                                            .foregroundColor(colorForScore(job.analysisScores.finalScore))
                                        Text(getRating(for: job.analysisScores.finalScore))
                                            .font(.system(size: 12))
                                            .fontWeight(.light)
                                            .foregroundColor(.black)
                                    }
                                    
                                    // Required YOE
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Req.")
                                            .font(.system(size: 12))
                                            .fontWeight(.light)
                                            .foregroundColor(.black)
                                            .opacity(0.7)
                                        Text("\(String(format: "%.1f", job.analysisScores.required_yoe))y")
                                            .font(.title2)
                                            .fontWeight(.light)
                                            .foregroundColor(.black)
                                    }
                                    
                                    // Actual YOE
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Actual")
                                            .font(.system(size: 12))
                                            .fontWeight(.light)
                                            .foregroundColor(.black)
                                            .opacity(0.7)
                                        Text("\(String(format: "%.1f", job.analysisScores.actual_yoe))y")
                                            .font(.title2)
                                            .fontWeight(.light)
                                            .foregroundColor(.black)
                                    }
                                    
                                    // Experience score
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Exp.")
                                            .font(.system(size: 12))
                                            .fontWeight(.light)
                                            .foregroundColor(.black)
                                            .opacity(0.7)
                                        Text("\(job.analysisScores.exp_score)/4")
                                            .font(.title2)
                                            .fontWeight(.light)
                                            .foregroundColor(.black)
                                    }
                                    
                                    // Education score
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Edu.")
                                            .font(.system(size: 12))
                                            .fontWeight(.light)
                                            .foregroundColor(.black)
                                            .opacity(0.7)
                                        Text("\(job.analysisScores.edu_score)/4")
                                            .font(.title2)
                                            .fontWeight(.light)
                                            .foregroundColor(.black)
                                    }
                                    
                                    // Skill score
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Skills")
                                            .font(.system(size: 12))
                                            .fontWeight(.light)
                                            .foregroundColor(.black)
                                            .opacity(0.7)
                                        Text("\(job.analysisScores.skill_score)/4")
                                            .font(.title2)
                                            .fontWeight(.light)
                                            .foregroundColor(.black)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Divider
                                Divider()
                                
                                // Rationale section
                                VStack(alignment: .leading, spacing: 16) {
                                    Text(extractRationales(from: job.analysisResult))
                                        .fontWeight(.light)
                                        .foregroundColor(.black)
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(width: 280, alignment: .leading) // Fixed width for right column
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 16)
                        .padding(.bottom, 100) // Space for overlay buttons
                    }
                }
                
                // Overlay buttons - only star button remains
                VStack(spacing: 0) {
                    // Top row - Star button position  
                    HStack {
                        Spacer()
                        
                        // Star button removed from here since it's now with LinkedIn button
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 16)
                    
                    Spacer()
                }
            }
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
    
    
    private func getRating(for score: Double) -> String {
        if score < 75 { return "Denied" }
        if score < 85 { return "Poor" }
        if score < 93 { return "Maybe" }
        return "Good"
    }
    
    private func colorForScore(_ score: Double) -> Color {
        if score < 75 { return AppColors.rejectedBlack }
        if score < 85 { return AppColors.poorRed }
        if score < 93 { return AppColors.maybeYellow }
        return AppColors.goodGreen
    }
    
    private func extractRationales(from analysisResult: String) -> String {
        // Use regex to find text after "Rationales:"
        let pattern = "Rationales:\\s*(.*)"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(location: 0, length: analysisResult.utf16.count)
            if let match = regex.firstMatch(in: analysisResult, options: [], range: range) {
                let rationalesRange = match.range(at: 1)
                if let range = Range(rationalesRange, in: analysisResult) {
                    return String(analysisResult[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // Fallback: return the original text if regex fails
        return analysisResult
    }
    

    
    private func openLinkedInJob(jobId: String) {
        let linkedinUrl = "https://www.linkedin.com/jobs/view/\(jobId)"
        if let url = URL(string: linkedinUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}


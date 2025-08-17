import SwiftUI

struct ResumeDetailView: View {
    let resume: ResumeItem?
    let horizontalPadding: CGFloat
    let resumes: [ResumeItem]
    
    var body: some View {
        Group {
            if let resume = resume {
                ResumeContentView(
                    text: resume.cleanedText,
                    bottomLabel: "Cleaned Resume Content",
                    horizontalPadding: horizontalPadding
                )
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    if resumes.isEmpty {
                        Text("Please import a resume")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select a resume to start")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
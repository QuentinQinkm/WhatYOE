import SwiftUI

struct ResumeDetailView: View {
    let resume: ResumeItem?
    let horizontalPadding: CGFloat
    let resumes: [ResumeItem]
    
    @State private var formattedText: String = "Loading resume content..."
    
    var body: some View {
        Group {
            if let resume = resume {
                ResumeContentView(
                    text: formattedText,
                    bottomLabel: "Cleaned Resume Content",
                    horizontalPadding: horizontalPadding
                )
                .onAppear {
                    Task {
                        if let text = await ResumeManager.shared.getFormattedResumeText(for: resume.id) {
                            formattedText = text
                        } else {
                            formattedText = "No resume content available"
                        }
                    }
                }
                .onChange(of: resume.id) { _, newId in
                    formattedText = "Loading resume content..."
                    Task {
                        if let text = await ResumeManager.shared.getFormattedResumeText(for: newId) {
                            formattedText = text
                        } else {
                            formattedText = "No resume content available"
                        }
                    }
                }
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
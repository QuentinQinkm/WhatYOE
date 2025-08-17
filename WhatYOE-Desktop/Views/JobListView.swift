import SwiftUI

struct JobListView: View {
    let jobs: [JobItem]
    @Binding var selectedJob: JobItem?
    @Binding var selectedResumeId: String?
    let resumeOptions: [(id: String, name: String)]
    let onDelete: (JobItem) -> Void
    let onResumeSelectionChanged: (String?) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Resume Selector - aligned with tab picker
            HStack {
                Picker("", selection: $selectedResumeId) {
                    Text("All Resumes")
                        .font(.system(size: 12, weight: .light))
                        .tag(nil as String?)
                    ForEach(resumeOptions, id: \.id) { resume in
                        Text(resume.name)
                            .font(.system(size: 12, weight: .light))
                            .tag(resume.id as String?)
                    }
                }
                .labelsHidden()
                .font(.system(size: 12, weight: .light))
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: .infinity, style: .continuous))
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .onChange(of: selectedResumeId) { newValue in
                onResumeSelectionChanged(newValue)
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            Group {
                if jobs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "briefcase")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No analyzed jobs")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Use the Safari extension to analyze jobs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(jobs, id: \.jobId) { job in
                                GenericRowView(
                                    item: job,
                                    isSelected: selectedJob?.jobId == job.jobId
                                )
                                .onTapGesture {
                                    selectedJob = job
                                }
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        onDelete(job)
                                    }
                                    Button("Like") {
                                        print("Like job: \(job.jobTitle)")
                                    }
                                    Button("View on LinkedIn") {
                                        if let url = URL(string: "https://www.linkedin.com/jobs/view/\(job.jobId)") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.bottom, 16)
        }
    }
}

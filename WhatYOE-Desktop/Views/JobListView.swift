import SwiftUI

struct JobListView: View {
    let jobs: [JobItem]
    @Binding var selectedJob: JobItem?
    let onDelete: (JobItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if jobs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "briefcase")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No analyzed jobs")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Use the Safari extension to analyze jobs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
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
            
            HStack {
                Spacer()
                
                Button(action: {
                    // No action for jobs - they come from Safari extension
                }) {
                    Image(systemName: "briefcase.badge.plus")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(true)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }
}
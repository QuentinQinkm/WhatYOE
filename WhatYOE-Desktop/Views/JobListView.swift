import SwiftUI

// Import the sort order enum
extension JobSortOrder: Identifiable {
    var id: String { rawValue }
}

// MARK: - Job Group Structure
private struct JobGroup {
    let category: String
    let color: Color
    let jobs: [JobItem]
    let sortOrder: Int
}

struct JobListView: View {
    let jobs: [JobItem]
    @Binding var selectedJob: JobItem?
    @Binding var selectedResumeId: String?
    let resumeOptions: [(id: String, name: String)]
    let onDelete: (JobItem) -> Void
    let onResumeSelectionChanged: (String?) -> Void
    let onRefresh: (() -> Void)?
    let hasNewJobs: Bool
    let sortOrder: JobSortOrder
    let onSortOrderChanged: (JobSortOrder) -> Void
    let onJumpToResume: (String) -> Void
    let allResumes: [ResumeItem]
    
    // State for collapsible sections
    @State private var collapsedSections: Set<String> = []
    @State private var sortIconHovered = false
    @State private var refreshIconHovered = false
    @State private var jumpIconHovered = false
    
    // MARK: - Computed Properties
    private var shouldShowJumpIcon: Bool {
        selectedResumeId != nil
    }
    
    private var resumeExists: Bool {
        guard let selectedId = selectedResumeId else { return false }
        return allResumes.contains { $0.id == selectedId }
    }
    
    private var jumpIconOpacity: Double {
        guard shouldShowJumpIcon else { return 0 }
        if !resumeExists { return 0.3 }
        return jumpIconHovered ? 0.7 : 0.5
    }
    
    
    private var groupedJobs: [JobGroup] {
        let grouped = Dictionary(grouping: jobs) { job in
            AppColors.categoryForScore(job.analysisScores.finalScore)
        }
        
        let groups = [
            JobGroup(category: "Good", color: AppColors.goodGreen, jobs: grouped["Good"] ?? [], sortOrder: 0),
            JobGroup(category: "Maybe", color: AppColors.maybeYellow, jobs: grouped["Maybe"] ?? [], sortOrder: 1),
            JobGroup(category: "Poor", color: AppColors.poorRed, jobs: grouped["Poor"] ?? [], sortOrder: 2),
            JobGroup(category: "Rejected", color: AppColors.rejectedBlack, jobs: grouped["Rejected"] ?? [], sortOrder: 3)
        ]
        
        return groups
            .filter { !$0.jobs.isEmpty }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { group in
                let sortedJobs: [JobItem]
                switch sortOrder {
                case .time:
                    sortedJobs = group.jobs.sorted { $0.dateAnalyzed > $1.dateAnalyzed }
                case .score:
                    sortedJobs = group.jobs.sorted { $0.analysisScores.finalScore > $1.analysisScores.finalScore }
                }
                
                return JobGroup(
                    category: group.category,
                    color: group.color,
                    jobs: sortedJobs,
                    sortOrder: group.sortOrder
                )
            }
    }
    
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
                
                // Jump to resume icon
                if shouldShowJumpIcon {
                    Button(action: {
                        if resumeExists, let selectedId = selectedResumeId {
                            onJumpToResume(selectedId)
                        }
                    }) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .opacity(jumpIconOpacity)
                    }
                    .buttonStyle(.plain)
                    .disabled(!resumeExists)
                    .onHover { isHovered in
                        jumpIconHovered = isHovered
                    }
                }
                
                Spacer()
                
                // Sort dropdown
                Menu {
                    ForEach(JobSortOrder.allCases, id: \.self) { order in
                        Button(order.rawValue) {
                            onSortOrderChanged(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .opacity(sortIconHovered ? 0.7 : 0.5)
                }
                .buttonStyle(.plain)
                .help("Sort jobs by \(sortOrder.rawValue.lowercased())")
                .onHover { isHovered in
                    sortIconHovered = isHovered
                }
                
                // Refresh button with notification dot
                if let onRefresh = onRefresh {
                    ZStack {
                        Button(action: onRefresh) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                                .opacity(refreshIconHovered ? 0.7 : 0.5)
                        }
                        .buttonStyle(.plain)
                        .help("Refresh job list")
                        .onHover { isHovered in
                            refreshIconHovered = isHovered
                        }
                        
                        // Green notification dot
                        if hasNewJobs {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                        }
                    }
                }
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
                            ForEach(groupedJobs, id: \.category) { group in
                                // Section Header with stroke styling and collapse functionality
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(group.color)
                                        .frame(width: 5)
                                    
                                    HStack {
                                        Image(systemName: collapsedSections.contains(group.category) ? "chevron.right" : "chevron.down")
                                            .font(.system(size: 10, weight: .light))
                                            .foregroundColor(.black)
                                            .animation(.easeInOut(duration: 0.2), value: collapsedSections.contains(group.category))
                                        
                                        Text(group.category)
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(.black)
                                        
                                        Spacer()
                                        
                                        Text("\(group.jobs.count)")
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(.black)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                                .background(Color.black.opacity(0.05))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if collapsedSections.contains(group.category) {
                                            collapsedSections.remove(group.category)
                                        } else {
                                            collapsedSections.insert(group.category)
                                        }
                                    }
                                }
                                
                                // Jobs in this category (only show if not collapsed)
                                if !collapsedSections.contains(group.category) {
                                    ForEach(group.jobs, id: \.jobId) { job in
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
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.bottom, 16)
        }
    }
}

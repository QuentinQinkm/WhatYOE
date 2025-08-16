/*
SwiftUI Desktop Interface for WhatYOE
Provides resume management and analysis functionality
*/

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    // MARK: - Background Opacity Constants
    private let leftListOpacity: Double = 0.65
    private let rightSectionOpacity: Double = 0.8
    
    // MARK: - Padding Constants
    private let rightSectionPadding: CGFloat = 20
    
    // MARK: - Color Constants
    private let buttonBackgroundColor = Color(red: 235/255, green: 235/255, blue: 235/255)
    
    @State private var resumes: [ResumeItem] = []
    @State private var selectedResume: ResumeItem?
    @State private var selectedTab = 0 // Jobs tab by default
    @State private var isImporting = false
    @State private var pendingResumeData: PendingResumeData?
    @State private var jobs: [JobItem] = []
    @State private var selectedJob: JobItem? = nil
    @State private var renamingResume: ResumeItem?
    @State private var renameText = ""
    private let resumeManager = ResumeManager.shared
    private let jobManager = JobManager.shared
    
    struct PendingResumeData {
        let fileName: String
        let rawText: String
        let url: URL
        var cleanedText: String?
        var isProcessing: Bool = false
    }
    
    var body: some View {
        ZStack {
            // Popover blurred background for entire window
            VisualEffectView()
                .ignoresSafeArea(.all)
            
            // Content with specific opacity backgrounds
            HStack(spacing: 0) {
                // Left Panel - Conditional list based on selected tab
                Group {
                    if selectedTab == 0 {
                        // Jobs List
                        JobListView(
                            jobs: jobs,
                            selectedJob: $selectedJob,
                            onDelete: deleteJob
                        )
                    } else {
                        // Resume List (default for Resume and Analysis tabs)
                        ResumeListView(
                            resumes: resumes,
                            selectedResume: $selectedResume,
                            onImport: importResume,
                            onDelete: deleteResume,
                            onRename: startRename
                        )
                    }
                }
                .frame(width: 250)
                .padding(.top, 42) // Align with right panel content area (16 + 16 = 32 to account for 12px text padding)
                .background(Color.white.opacity(leftListOpacity)) // List background: white 0.5 opacity
                
                Divider()
                    .background(Color.white.opacity(0.5))
                
                // Right Panel - Always show tabs interface
                VStack(spacing: 0) {
                    // Top section with tab picker and label
                    HStack {
                        // Custom Tab Picker - positioned at the top
                        CustomTabPicker(selectedTab: $selectedTab)
                            .padding(.leading, rightSectionPadding)
                        
                        Spacer()
                        
                        // Gray label centered with tab picker on Y axis
                        Text(getLabelText())
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: .infinity, style: .continuous))
                            .opacity(0.8)
                            .padding(.trailing, rightSectionPadding)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    
                    // Tab Content - takes remaining space with 16px bottom padding
                    Group {
                        if selectedTab == 0 {
                            JobDetailView(job: selectedJob, horizontalPadding: rightSectionPadding, jobs: jobs)
                        } else if selectedTab == 1 {
                            if let pendingData = pendingResumeData {
                                PendingResumeView(
                                    pendingData: pendingData,
                                    onProceed: proceedWithLLM,
                                    onSave: saveProcessedResume,
                                    onCancel: cancelImport,
                                    horizontalPadding: rightSectionPadding,
                                    buttonBackgroundColor: buttonBackgroundColor
                                )
                            } else {
                                ResumeDetailView(resume: selectedResume, horizontalPadding: rightSectionPadding, resumes: resumes)
                            }
                        } else {
                            AnalysisView(selectedResume: selectedResume)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 16)
                }
                .background(Color.white.opacity(rightSectionOpacity)) // Right control panel: white 0.8 opacity
            }
        }
        .sheet(item: $renamingResume) { resume in
            RenameDialog(
                currentName: resume.name,
                renameText: $renameText,
                onSave: saveRename,
                onCancel: cancelRename
            )
        }
        .onAppear {
            loadResumes()
            loadJobs()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("JobsUpdated"))) { _ in
            loadJobs()
        }
    }
    
    // MARK: - Methods
    private func loadResumes() {
        resumes = resumeManager.getAllResumes()
    }
    
    private func getLabelText() -> String {
        switch selectedTab {
        case 0:
            return selectedJob != nil ? "Job Analysis Report" : ""
        case 1:
            return pendingResumeData != nil ? "Raw Resume Content" : (selectedResume != nil ? "Cleaned Resume Content" : "")
        case 2:
            return "Analysis Results"
        default:
            return ""
        }
    }
    
    private func loadJobs() {
        jobs = jobManager.getAllJobs()
        if selectedJob == nil && !jobs.isEmpty {
            selectedJob = jobs.first
        }
    }
    
    
    private func importResume() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Resume"
        openPanel.allowedContentTypes = [.pdf]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK {
            guard let url = openPanel.url else { return }
            
            Task {
                do {
                    let rawText = try resumeManager.extractTextFromPDF(url: url)
                    let fileName = url.deletingPathExtension().lastPathComponent
                    
                    await MainActor.run {
                        pendingResumeData = PendingResumeData(
                            fileName: fileName,
                            rawText: rawText,
                            url: url
                        )
                        selectedTab = 1 // Switch to Resume tab to show the import
                    }
                } catch {
                    print("❌ Failed to extract text from PDF: \(error)")
                }
            }
        }
    }
    
    private func proceedWithLLM() {
        guard var pendingData = pendingResumeData else { return }
        
        pendingData.isProcessing = true
        pendingResumeData = pendingData
        
        Task {
            do {
                let cleanedText = try await resumeManager.cleanResumeText(pendingData.rawText)
                
                await MainActor.run {
                    var updatedData = pendingData
                    updatedData.cleanedText = cleanedText
                    updatedData.isProcessing = false
                    pendingResumeData = updatedData
                }
            } catch {
                await MainActor.run {
                    var updatedData = pendingData
                    updatedData.isProcessing = false
                    pendingResumeData = updatedData
                    print("❌ Failed to clean resume text: \(error)")
                }
            }
        }
    }
    
    private func saveProcessedResume() {
        guard let pendingData = pendingResumeData,
              let cleanedText = pendingData.cleanedText else { return }
        
        let resume = ResumeItem(
            name: pendingData.fileName,
            cleanedText: cleanedText
        )
        
        resumeManager.saveResume(resume)
        loadResumes()
        
        // Clear pending data and select the new resume
        pendingResumeData = nil
        selectedResume = resume
    }
    
    private func cancelImport() {
        pendingResumeData = nil
    }
    
    private func deleteResume(_ resume: ResumeItem) {
        resumeManager.deleteResume(withId: resume.id)
        loadResumes()
    }
    
    private func startRename(_ resume: ResumeItem) {
        renamingResume = resume
        renameText = resume.name
    }
    
    private func saveRename() {
        guard let resume = renamingResume else { return }
        
        let updatedResume = ResumeItem(
            id: resume.id,
            name: renameText.trimmingCharacters(in: .whitespacesAndNewlines),
            cleanedText: resume.cleanedText,
            dateCreated: resume.dateCreated
        )
        
        resumeManager.updateResume(updatedResume)
        loadResumes()
        
        // Update selected resume if it was the one being renamed
        if selectedResume?.id == resume.id {
            selectedResume = updatedResume
        }
        
        renamingResume = nil
        renameText = ""
    }
    
    private func cancelRename() {
        renamingResume = nil
        renameText = ""
    }
    
    private func deleteJob(_ job: JobItem) {
        jobManager.deleteJob(withId: job.jobId)
        loadJobs()
        
        // Clear selection if deleted job was selected
        if selectedJob?.jobId == job.jobId {
            selectedJob = jobs.first
        }
    }
}


// MARK: - Pending Resume View
struct PendingResumeView: View {
    let pendingData: ContentView.PendingResumeData
    let onProceed: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let horizontalPadding: CGFloat
    let buttonBackgroundColor: Color
    
    var body: some View {
        ResumeContentView(
            text: displayText,
            bottomLabel: "Raw Resume Content",
            horizontalPadding: horizontalPadding,
            overlayButtons: {
                AnyView(
                    VStack(spacing: 0) {
                        // Edit button positioned 16px above proceed button
                        HStack {
                            Spacer()
                            
                            GlassIconButton(
                                icon: "pencil",
                                color: .black,
                                state: pendingData.isProcessing ? .disabled : .default,
                                action: {
                                    // Edit action placeholder
                                    print("Edit tapped")
                                }
                            )
                        }
                        .padding(.bottom, 16)
                        
                        // Bottom row - Cancel and Proceed aligned
                        HStack {
                            // Cancel button - bottom left
                            GlassButton(
                                title: "Cancel",
                                color: Color(red: 110/255, green: 0/255, blue: 0/255),
                                state: pendingData.isProcessing ? .disabled : .default,
                                action: onCancel
                            )
                            
                            Spacer()
                            
                            // Process button - bottom right
                            if pendingData.isProcessing {
                                GlassButton(
                                    title: "Processing...",
                                    color: Color(red: 0/255, green: 0/255, blue: 115/255),
                                    state: .running,
                                    action: {}
                                )
                            } else if pendingData.cleanedText != nil {
                                GlassButton(
                                    title: "Save",
                                    color: Color(red: 0/255, green: 0/255, blue: 115/255),
                                    state: .default,
                                    action: buttonAction
                                )
                            } else {
                                GlassButton(
                                    title: "Proceed with LLM",
                                    color: Color(red: 0/255, green: 0/255, blue: 115/255),
                                    state: .default,
                                    action: buttonAction
                                )
                            }
                        }
                    }
                )
            }
        )
    }
    
    private var statusText: String {
        if pendingData.isProcessing {
            return "Processing with AI..."
        } else if pendingData.cleanedText != nil {
            return "Ready to save"
        } else {
            return "Raw PDF text extracted"
        }
    }
    
    private var displayText: String {
        return pendingData.cleanedText ?? pendingData.rawText
    }
    
    private var buttonAction: () -> Void {
        if pendingData.cleanedText != nil {
            return onSave
        } else {
            return onProceed
        }
    }
}

// MARK: - Resume List View
struct ResumeListView: View {
    let resumes: [ResumeItem]
    @Binding var selectedResume: ResumeItem?
    let onImport: () -> Void
    let onDelete: (ResumeItem) -> Void
    let onRename: (ResumeItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Resume List - takes remaining space
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(resumes, id: \.id) { resume in
                        GenericRowView(
                            item: resume,
                            isSelected: selectedResume?.id == resume.id
                        )
                        .onTapGesture {
                            selectedResume = resume
                        }
                        .contextMenu {
                            Button("Rename") {
                                onRename(resume)
                            }
                            Button("Delete", role: .destructive) {
                                onDelete(resume)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Actions - aligned with right panel bottom
            HStack {
                Button(action: onImport) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Import Resume")
                
                Button(action: deleteSelectedResume) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selectedResume == nil ? .gray : .black)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(selectedResume == nil)
                .help("Delete Selected Resume")
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .padding(.bottom, 16)
            .background(Color.clear)
        }
    }
    
    private func deleteSelectedResume() {
        if let resume = selectedResume {
            onDelete(resume)
        }
    }
}


// MARK: - Shared Resume Content View
struct ResumeContentView: View {
    let text: String
    let bottomLabel: String
    let horizontalPadding: CGFloat
    let overlayButtons: (() -> AnyView)?
    
    init(text: String, bottomLabel: String, horizontalPadding: CGFloat, overlayButtons: (() -> AnyView)? = nil) {
        self.text = text
        self.bottomLabel = bottomLabel
        self.horizontalPadding = horizontalPadding
        self.overlayButtons = overlayButtons
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Resume Content Area
            VStack(spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    ScrollView {
                        Text(text)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.black)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 12)
                            .padding(.bottom, 12)
                    }
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.05),
                                .init(color: .black, location: 0.95),
                                .init(color: .clear, location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Optional overlay buttons
                    if let overlayButtons = overlayButtons {
                        overlayButtons()
                            .padding(16)
                    }
                }
                //.padding(.top, 16)
                //.padding(.bottom, 16)
            }
        }
        .padding(.horizontal, horizontalPadding)
        // Removed redundant vertical padding since gradient fading handles spacing
    }
}

// MARK: - Resume Detail View
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

// MARK: - Analysis View
struct AnalysisView: View {
    let selectedResume: ResumeItem?
    @State private var jobDescription = ""
    @State private var analysisMethod = AnalysisMethod.fourRun
    @State private var isAnalyzing = false
    @State private var analysisResult = ""
    @State private var statusMessage = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Job Description Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Job Description")
                    .font(.headline)
                    .foregroundColor(.black)
                
                TextEditor(text: $jobDescription)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(8)
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
                    .frame(minHeight: 120)
            }
            
            // Analysis Method Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Analysis Method")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Picker("Method", selection: $analysisMethod) {
                    ForEach(AnalysisMethod.allCases, id: \.self) { method in
                        Text(method.title)
                            .foregroundColor(.black)
                            .tag(method)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Analyze Button
            Button(action: performAnalysis) {
                HStack {
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isAnalyzing ? "Analyzing..." : "Analyze Match")
                }
                .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAnalyzing || jobDescription.isEmpty || selectedResume == nil)
            
            // Status Message
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundColor(statusMessage.contains("Error") ? .red : .black.opacity(0.6))
                    .padding(.horizontal)
            }
            
            // Analysis Results
            if !analysisResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Analysis Results")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    ScrollView {
                        Text(analysisResult)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.black)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func performAnalysis() {
        guard let resume = selectedResume else { return }
        
        isAnalyzing = true
        statusMessage = "Starting analysis..."
        analysisResult = ""
        
        Task {
            do {
                let result = try await AnalysisManager.shared.performAnalysis(
                    resume: resume,
                    jobDescription: jobDescription,
                    method: analysisMethod
                )
                
                await MainActor.run {
                    analysisResult = result
                    statusMessage = "Analysis completed successfully"
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Error: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - Date Formatters
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    static let longDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()
}

// MARK: - Custom Tab Picker
struct CustomTabPicker: View {
    @Binding var selectedTab: Int
    @State private var hoveringTab: Int? = nil
    
    private let tabs = [
        (index: 0, title: "Jobs"),
        (index: 1, title: "Resume"),
        (index: 2, title: "Analysis")
    ]
    
    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            ForEach(tabs, id: \.index) { tab in
                HStack(spacing: 6) {
                    // Dot indicator for selected tab
                    if selectedTab == tab.index {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                    }
                    
                    Text(tab.title)
                        .font(.title)
                        .fontWeight(.light)
                        .foregroundColor(.black.opacity(textOpacity(for: tab.index)))
                        .animation(.easeInOut(duration: 0.15), value: selectedTab)
                        .animation(.easeInOut(duration: 0.1), value: hoveringTab)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTab = tab.index
                }
                .onHover { hovering in
                    hoveringTab = hovering ? tab.index : nil
                }
            }
            
            Spacer() // Push tabs to the left
        }
    }
    
    private func textOpacity(for tabIndex: Int) -> Double {
        if selectedTab == tabIndex {
            return 1.0 // Selected: full opacity
        } else if hoveringTab == tabIndex {
            return 0.7 // Hovering unselected: 0.7 opacity
        } else {
            return 0.5 // Unselected: 0.5 opacity
        }
    }
}

// MARK: - Rename Dialog
struct RenameDialog: View {
    let currentName: String
    @Binding var renameText: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Popover blur background
            VisualEffectView()
                .cornerRadius(12)
            
            // Content with semi-transparent overlay
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rename Resume")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    TextField("Resume name", text: $renameText)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .onAppear {
                            // Select all text when dialog appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if let textField = NSApplication.shared.keyWindow?.firstResponder as? NSTextField {
                                    textField.selectText(nil)
                                }
                            }
                        }
                }
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save") {
                        if !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSave()
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
        }
        .frame(width: 350)
        .shadow(radius: 10)
    }
}

// MARK: - Reusable Glass Button
enum ButtonState {
    case `default`
    case pressed
    case running
    case disabled
}

struct GlassButtonConfig {
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    let fontSize: CGFloat
    
    static let textButton = GlassButtonConfig(
        cornerRadius: 15,
        padding: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16),
        fontSize: 14
    )
    
    static let iconButton = GlassButtonConfig(
        cornerRadius: 20,
        padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
        fontSize: 16
    )
}

struct GlassButtonStyle {
    static func textColor(for state: ButtonState, baseColor: Color, isPressed: Bool) -> Color {
        let currentState = isPressed ? .pressed : state
        switch currentState {
        case .default:
            return baseColor.opacity(0.8)
        case .pressed:
            return .white
        case .running:
            return baseColor.opacity(0.8)
        case .disabled:
            return baseColor.opacity(0.5)
        }
    }
    
    static func backgroundFill(for state: ButtonState, baseColor: Color, isPressed: Bool) -> Color {
        let currentState = isPressed ? .pressed : state
        switch currentState {
        case .default:
            return Color.white.opacity(0.8)
        case .pressed:
            return baseColor.opacity(0.8)
        case .running:
            return baseColor.opacity(0.8)
        case .disabled:
            return Color.white.opacity(0.8)
        }
    }
}

struct GlassButton: View {
    let title: String
    let color: Color
    let state: ButtonState
    let action: () -> Void
    @State private var isPressed = false
    
    private let config = GlassButtonConfig.textButton
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: config.fontSize, weight: .light))
                .foregroundColor(GlassButtonStyle.textColor(for: state, baseColor: color, isPressed: isPressed))
                .padding(config.padding)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                            .fill(GlassButtonStyle.backgroundFill(for: state, baseColor: color, isPressed: isPressed))
                            .blendMode(.screen)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(state == .disabled)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct GlassIconButton: View {
    let icon: String
    let color: Color
    let state: ButtonState
    let action: () -> Void
    @State private var isPressed = false
    
    private let config = GlassButtonConfig.iconButton
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: config.fontSize, weight: .light))
                .foregroundColor(GlassButtonStyle.textColor(for: state, baseColor: color, isPressed: isPressed))
                .padding(config.padding)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                            .fill(GlassButtonStyle.backgroundFill(for: state, baseColor: color, isPressed: isPressed))
                            .blendMode(.screen)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(state == .disabled)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Visual Effect View
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        return effectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // No updates needed
    }
}

// MARK: - Generic List Protocol
protocol ListRowData {
    var id: String { get }
    var primaryText: String { get }
    var secondaryText: String { get }
}

extension JobItem: ListRowData {
    var id: String { jobId }
    var primaryText: String { jobTitle }
    var secondaryText: String { company }
}

extension ResumeItem: ListRowData {
    var primaryText: String { name }
    var secondaryText: String { DateFormatter.shortDate.string(from: dateCreated) }
}

// MARK: - Generic Row View
struct GenericRowView<T: ListRowData>: View {
    let item: T
    let isSelected: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Colored left border based on job rating
            Rectangle()
                .fill(getBorderColor())
                .frame(width: getBorderWidth())
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            
            // Content with padding
            VStack(alignment: .leading, spacing: 4) {
                Text(item.primaryText)
                    .font(isSelected ? .title2 : .headline)
                    .fontWeight(.light)
                    .foregroundColor(.black.opacity(isSelected ? 1.0 : (isHovered ? 1.0 : 0.5)))
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                
                Text(item.secondaryText)
                    .font(isSelected ? .body : .caption)
                    .fontWeight(.light)
                    .foregroundColor(.black.opacity(isSelected ? 1.0 : (isHovered ? 1.0 : 0.5)))
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .background(Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private func getBorderColor() -> Color {
        // Get the base color based on job rating
        let baseColor = getRatingColor()
        
        // Apply opacity based on state
        if isSelected || isHovered {
            return baseColor.opacity(1.0) // 100% opacity on hover/selection
        } else {
            return baseColor.opacity(0.6) // 60% opacity by default
        }
    }
    
    private func getRatingColor() -> Color {
        // Cast to JobItem to access analysisScores
        guard let jobItem = item as? JobItem else {
            return .gray // Fallback for non-job items
        }
        
        let finalScore = jobItem.analysisScores.finalScore
        
        // Color coding based on final score (0-4 scale)
        if finalScore >= 0 && finalScore < 1.3 {
            return .red // Reject
        } else if finalScore >= 1.3 && finalScore < 2.0 {
            return .orange // Poor
        } else if finalScore >= 2.0 && finalScore < 2.7 {
            return .yellow // Maybe
        } else if finalScore >= 2.7 {
            return .green // Good
        } else {
            return .gray // Unknown/Error
        }
    }
    
    private func getBorderWidth() -> CGFloat {
        return isSelected ? 8 : 5
    }
}

// MARK: - Job List View
struct JobListView: View {
    let jobs: [JobItem]
    @Binding var selectedJob: JobItem?
    let onDelete: (JobItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Job List - takes remaining space
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
                                    // TODO: Implement like functionality
                                    print("Like job: \(job.jobTitle)")
                                }
                                Button("View on LinkedIn") {
                                    // Open LinkedIn job page using stored job ID
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
            
            // Bottom Actions - aligned with right panel bottom
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
                .disabled(true) // Jobs are added via Safari extension
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }
}


// MARK: - Job Detail View
struct JobDetailView: View {
    let job: JobItem?
    let horizontalPadding: CGFloat
    let jobs: [JobItem]
    
    var body: some View {
        if let job = job {
            ResumeContentView(
                text: formatJobContent(job),
                bottomLabel: "",
                horizontalPadding: horizontalPadding
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
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}

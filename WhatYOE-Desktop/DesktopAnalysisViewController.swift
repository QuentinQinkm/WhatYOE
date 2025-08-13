/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Desktop Analysis View Controller - handles local analysis UI
*/
import Cocoa
import PDFKit
import Foundation
import os.log
import UniformTypeIdentifiers

class DesktopAnalysisViewController: NSViewController {
    
    // MARK: - UI Elements
    private var tabView: NSTabView!
    private var resumeTextView: NSTextView!
    private var jobDescriptionTextView: NSTextView!
    private var analysisResultsTextView: NSTextView!
    private var statusLabel: NSTextField!
    private var analyzeButton: NSButton!
    private var importResumeButton: NSButton!
    private var resumeManagerScrollView: NSScrollView!
    private var resumeTableView: NSTableView!
    
    // MARK: - Properties
    private var resumeManager = ResumeManager.shared
    private var isAnalyzing = false
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🖥️ Desktop Analysis View Controller loaded")
        setupUI()
        loadResumeManager()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Create tab view
        tabView = NSTabView()
        tabView.tabViewType = .topTabsBezelBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)
        
        // Setup tabs
        setupResumeManagerTab()
        setupAnalysisTab()
        
        // Tab view constraints
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
        
        print("✅ Desktop UI setup complete")
    }
    
    private func setupResumeManagerTab() {
        let resumeTab = NSTabViewItem()
        resumeTab.label = "Resume Manager"
        
        let resumeView = NSView()
        resumeView.translatesAutoresizingMaskIntoConstraints = false
        
        // Import Resume Button
        importResumeButton = NSButton(title: "Import New Resume", target: self, action: #selector(importResume))
        importResumeButton.translatesAutoresizingMaskIntoConstraints = false
        importResumeButton.bezelStyle = .rounded
        resumeView.addSubview(importResumeButton)
        
        // Resume Table View
        resumeTableView = NSTableView()
        resumeTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileName")))
        resumeTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DateImported")))
        resumeTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Status")))
        
        resumeTableView.tableColumns[0].title = "Resume File"
        resumeTableView.tableColumns[1].title = "Date Imported"
        resumeTableView.tableColumns[2].title = "Status"
        
        resumeTableView.dataSource = self
        resumeTableView.delegate = self
        
        resumeManagerScrollView = NSScrollView()
        resumeManagerScrollView.documentView = resumeTableView
        resumeManagerScrollView.hasVerticalScroller = true
        resumeManagerScrollView.translatesAutoresizingMaskIntoConstraints = false
        resumeView.addSubview(resumeManagerScrollView)
        
        // Layout with flexible constraints
        let buttonTopConstraint = importResumeButton.topAnchor.constraint(equalTo: resumeView.topAnchor, constant: 20)
        let buttonLeadingConstraint = importResumeButton.leadingAnchor.constraint(equalTo: resumeView.leadingAnchor, constant: 20)
        let buttonWidthConstraint = importResumeButton.widthAnchor.constraint(equalToConstant: 160)
        
        let scrollTopConstraint = resumeManagerScrollView.topAnchor.constraint(equalTo: importResumeButton.bottomAnchor, constant: 20)
        let scrollLeadingConstraint = resumeManagerScrollView.leadingAnchor.constraint(equalTo: resumeView.leadingAnchor, constant: 20)
        let scrollTrailingConstraint = resumeManagerScrollView.trailingAnchor.constraint(equalTo: resumeView.trailingAnchor, constant: -20)
        let scrollBottomConstraint = resumeManagerScrollView.bottomAnchor.constraint(equalTo: resumeView.bottomAnchor, constant: -20)
        
        // Set lower priority for scroll view constraints to avoid conflicts
        scrollTopConstraint.priority = .defaultHigh
        scrollLeadingConstraint.priority = .defaultHigh
        scrollTrailingConstraint.priority = .defaultHigh
        scrollBottomConstraint.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            buttonTopConstraint,
            buttonLeadingConstraint,
            buttonWidthConstraint,
            scrollTopConstraint,
            scrollLeadingConstraint,
            scrollTrailingConstraint,
            scrollBottomConstraint
        ])
        
        resumeTab.view = resumeView
        tabView.addTabViewItem(resumeTab)
    }
    
    private func setupAnalysisTab() {
        let analysisTab = NSTabViewItem()
        analysisTab.label = "Job Analysis"
        
        let analysisView = NSView()
        analysisView.translatesAutoresizingMaskIntoConstraints = false
        
        // Resume Content Display
        let resumeLabel = NSTextField(labelWithString: "Active Resume:")
        resumeLabel.translatesAutoresizingMaskIntoConstraints = false
        analysisView.addSubview(resumeLabel)
        
        let resumeScrollView = NSScrollView()
        resumeScrollView.translatesAutoresizingMaskIntoConstraints = false
        resumeScrollView.hasVerticalScroller = true
        resumeScrollView.borderType = .lineBorder
        
        resumeTextView = NSTextView()
        resumeTextView.isEditable = false
        resumeTextView.font = NSFont.systemFont(ofSize: 12)
        resumeScrollView.documentView = resumeTextView
        analysisView.addSubview(resumeScrollView)
        
        // Job Description Input
        let jobLabel = NSTextField(labelWithString: "Job Description:")
        jobLabel.translatesAutoresizingMaskIntoConstraints = false
        analysisView.addSubview(jobLabel)
        
        let jobScrollView = NSScrollView()
        jobScrollView.translatesAutoresizingMaskIntoConstraints = false
        jobScrollView.hasVerticalScroller = true
        jobScrollView.borderType = .lineBorder
        
        jobDescriptionTextView = NSTextView()
        jobDescriptionTextView.isRichText = false
        jobDescriptionTextView.font = NSFont.systemFont(ofSize: 12)
        jobScrollView.documentView = jobDescriptionTextView
        analysisView.addSubview(jobScrollView)
        
        // Analyze Button
        analyzeButton = NSButton(title: "Analyze Match", target: self, action: #selector(analyzeMatch))
        analyzeButton.translatesAutoresizingMaskIntoConstraints = false
        analyzeButton.bezelStyle = .rounded
        analyzeButton.isEnabled = false
        analysisView.addSubview(analyzeButton)
        
        // Status Label
        statusLabel = NSTextField(labelWithString: "Ready to analyze")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = NSColor.secondaryLabelColor
        analysisView.addSubview(statusLabel)
        
        // Results Display
        let resultsLabel = NSTextField(labelWithString: "Analysis Results:")
        resultsLabel.translatesAutoresizingMaskIntoConstraints = false
        analysisView.addSubview(resultsLabel)
        
        let resultsScrollView = NSScrollView()
        resultsScrollView.translatesAutoresizingMaskIntoConstraints = false
        resultsScrollView.hasVerticalScroller = true
        resultsScrollView.borderType = .lineBorder
        
        analysisResultsTextView = NSTextView()
        analysisResultsTextView.isEditable = false
        analysisResultsTextView.font = NSFont.systemFont(ofSize: 12)
        resultsScrollView.documentView = analysisResultsTextView
        analysisView.addSubview(resultsScrollView)
        
        // Layout with flexible constraints
        let resumeLabelTop = resumeLabel.topAnchor.constraint(equalTo: analysisView.topAnchor, constant: 20)
        let resumeLabelLeading = resumeLabel.leadingAnchor.constraint(equalTo: analysisView.leadingAnchor, constant: 20)
        
        let resumeScrollTop = resumeScrollView.topAnchor.constraint(equalTo: resumeLabel.bottomAnchor, constant: 5)
        let resumeScrollLeading = resumeScrollView.leadingAnchor.constraint(equalTo: analysisView.leadingAnchor, constant: 20)
        let resumeScrollTrailing = resumeScrollView.trailingAnchor.constraint(equalTo: analysisView.trailingAnchor, constant: -20)
        let resumeScrollHeight = resumeScrollView.heightAnchor.constraint(equalToConstant: 120)
        
        let jobLabelTop = jobLabel.topAnchor.constraint(equalTo: resumeScrollView.bottomAnchor, constant: 20)
        let jobLabelLeading = jobLabel.leadingAnchor.constraint(equalTo: analysisView.leadingAnchor, constant: 20)
        
        let jobScrollTop = jobScrollView.topAnchor.constraint(equalTo: jobLabel.bottomAnchor, constant: 5)
        let jobScrollLeading = jobScrollView.leadingAnchor.constraint(equalTo: analysisView.leadingAnchor, constant: 20)
        let jobScrollTrailing = jobScrollView.trailingAnchor.constraint(equalTo: analysisView.trailingAnchor, constant: -20)
        let jobScrollHeight = jobScrollView.heightAnchor.constraint(equalToConstant: 120)
        
        let analyzeButtonTop = analyzeButton.topAnchor.constraint(equalTo: jobScrollView.bottomAnchor, constant: 10)
        let analyzeButtonCenterX = analyzeButton.centerXAnchor.constraint(equalTo: analysisView.centerXAnchor)
        
        let statusLabelTop = statusLabel.topAnchor.constraint(equalTo: analyzeButton.bottomAnchor, constant: 10)
        let statusLabelCenterX = statusLabel.centerXAnchor.constraint(equalTo: analysisView.centerXAnchor)
        
        let resultsLabelTop = resultsLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20)
        let resultsLabelLeading = resultsLabel.leadingAnchor.constraint(equalTo: analysisView.leadingAnchor, constant: 20)
        
        let resultsScrollTop = resultsScrollView.topAnchor.constraint(equalTo: resultsLabel.bottomAnchor, constant: 5)
        let resultsScrollLeading = resultsScrollView.leadingAnchor.constraint(equalTo: analysisView.leadingAnchor, constant: 20)
        let resultsScrollTrailing = resultsScrollView.trailingAnchor.constraint(equalTo: analysisView.trailingAnchor, constant: -20)
        let resultsScrollBottom = resultsScrollView.bottomAnchor.constraint(equalTo: analysisView.bottomAnchor, constant: -20)
        
        // Set lower priority for scroll view constraints to avoid conflicts
        resumeScrollTop.priority = .defaultHigh
        resumeScrollLeading.priority = .defaultHigh
        resumeScrollTrailing.priority = .defaultHigh
        jobScrollTop.priority = .defaultHigh
        jobScrollLeading.priority = .defaultHigh
        jobScrollTrailing.priority = .defaultHigh
        resultsScrollTop.priority = .defaultHigh
        resultsScrollLeading.priority = .defaultHigh
        resultsScrollTrailing.priority = .defaultHigh
        resultsScrollBottom.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            resumeLabelTop, resumeLabelLeading,
            resumeScrollTop, resumeScrollLeading, resumeScrollTrailing, resumeScrollHeight,
            jobLabelTop, jobLabelLeading,
            jobScrollTop, jobScrollLeading, jobScrollTrailing, jobScrollHeight,
            analyzeButtonTop, analyzeButtonCenterX,
            statusLabelTop, statusLabelCenterX,
            resultsLabelTop, resultsLabelLeading,
            resultsScrollTop, resultsScrollLeading, resultsScrollTrailing, resultsScrollBottom
        ])
        
        analysisTab.view = analysisView
        tabView.addTabViewItem(analysisTab)
    }
    
    // MARK: - Data Management
    
    private func loadResumeManager() {
        resumeTableView?.reloadData()
        loadActiveResumeContent()
    }
    
    private func loadActiveResumeContent() {
        if let activeResume = resumeManager.activeResume {
            resumeTextView?.string = activeResume.cleanedText
            print("📄 Loaded active resume: \(activeResume.name)")
        } else {
            resumeTextView?.string = "No resume selected. Please import and select a resume from the Resume Manager tab."
        }
    }
    
    // MARK: - Actions
    
    @objc private func importResume() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.pdf]
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Select Resume PDF"
        openPanel.message = "Choose your resume PDF file to import"
        
        openPanel.begin { [weak self] result in
            if result == .OK, let url = openPanel.url {
                self?.handleResumeImport(url: url)
            }
        }
    }
    
    private func handleResumeImport(url: URL) {
        statusLabel.stringValue = "Importing resume..."
        
        Task {
            do {
                let success = try await self.resumeManager.importResume(from: url)
                
                await MainActor.run {
                    if success {
                        self.statusLabel.stringValue = "Resume imported successfully"
                        self.loadResumeManager()
                        print("✅ Resume imported: \(url.lastPathComponent)")
                    } else {
                        self.statusLabel.stringValue = "Failed to import resume"
                        print("❌ Failed to import resume: \(url.lastPathComponent)")
                    }
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.stringValue = "Import error: \(error.localizedDescription)"
                    print("❌ Import error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func analyzeMatch() {
        guard !isAnalyzing else { return }
        
        let jobDescription = jobDescriptionTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !jobDescription.isEmpty else {
            statusLabel.stringValue = "Please enter a job description"
            return
        }
        
        guard let activeResume = resumeManager.activeResume else {
            statusLabel.stringValue = "Please select a resume first"
            return
        }
        
        isAnalyzing = true
        analyzeButton.title = "Analyzing..."
        analyzeButton.isEnabled = false
        statusLabel.stringValue = "Running analysis..."
        analysisResultsTextView.string = ""
        
        // Simple analysis for now - just show the inputs
        let results = """
        📊 RESUME-JOB MATCH ANALYSIS
        ═══════════════════════════════════════════════════════
        
        📄 RESUME:
        \(activeResume.cleanedText.prefix(200))...
        
        💼 JOB DESCRIPTION:
        \(jobDescription.prefix(200))...
        
        🔍 ANALYSIS:
        This is a placeholder analysis. The full AI analysis system will be implemented in the next phase.
        
        Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))
        """
        
        analysisResultsTextView.string = results
        statusLabel.stringValue = "Analysis complete (placeholder)"
        
        isAnalyzing = false
        analyzeButton.title = "Analyze Match"
        analyzeButton.isEnabled = true
    }
    
    func selectTab(_ index: Int) {
        guard index < tabView.numberOfTabViewItems else { return }
        tabView.selectTabViewItem(at: index)
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate
extension DesktopAnalysisViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return resumeManager.getAllResumes().count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let resume = resumeManager.getAllResumes()[row]
        
        switch tableColumn?.identifier.rawValue {
        case "FileName":
            let name = resume.name
            return resume.isActive ? "⭐ \(name)" : name
        case "DateImported":
            return DateFormatter.localizedString(from: resume.dateCreated, dateStyle: .short, timeStyle: .none)
        case "Status":
            return resume.isActive ? "Active" : "Available"
        default:
            return nil
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = resumeTableView.selectedRow
        if selectedRow >= 0 && selectedRow < resumeManager.getAllResumes().count {
            let selectedResume = resumeManager.getAllResumes()[selectedRow]
            resumeManager.setActiveResume(selectedResume)
            loadActiveResumeContent()
            resumeTableView.reloadData()
            print("📄 Selected resume: \(selectedResume.name)")
        }
    }
}
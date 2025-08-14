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
    
    // MARK: - UI Components
    private var tabView: NSTabView!
    private var resumeManagerScrollView: NSScrollView!
    private var analysisView: NSView!
    
    // Resume Manager Tab
    private var workflowContainerView: NSView!
    private var reviewTextView: NSTextView!
    private var proceedButton: NSButton!
    private var nameTextField: NSTextField!
    private var saveButton: NSButton!
    private var cancelButton: NSButton!
    
    // Analysis Tab
    private var resumeLabel: NSTextField!
    private var resumeScrollView: NSScrollView!
    private var resumeTextView: NSTextView!
    private var jobLabel: NSTextField!
    private var jobScrollView: NSScrollView!
    private var jobDescriptionTextView: NSTextView!
    private var methodLabel: NSTextField!
    private var methodSegmentedControl: NSSegmentedControl!
    private var analyzeButton: NSButton!
    private var statusLabel: NSTextField!
    private var analysisResultsTextView: NSTextView!
    
    // Resume Manager Properties
    private var resumeTableView: NSTableView!
    private var importResumeButton: NSButton!
    private var deleteResumeButton: NSButton!
    private var workflowScrollView: NSScrollView!
    
    // MARK: - Properties
    private var resumeManager = ResumeManager.shared
    private var isAnalyzing = false
    private var pendingResumeData: (url: URL, extractedText: String)?
    
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
        updateAnalyzeButtonState()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        updateAnalyzeButtonState()
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
        print("🔧 Setting up Resume Manager tab with workflow UI")
        let resumeTab = NSTabViewItem()
        resumeTab.label = "Resume Manager"
        
        let resumeView = NSView()
        resumeView.translatesAutoresizingMaskIntoConstraints = false
        
        // Import Resume Button
        importResumeButton = NSButton(title: "Import New Resume - NEW UI", target: self, action: #selector(importResume))
        importResumeButton.translatesAutoresizingMaskIntoConstraints = false
        importResumeButton.bezelStyle = .rounded
        resumeView.addSubview(importResumeButton)
        
        // Delete Resume Button
        deleteResumeButton = NSButton(title: "Delete Selected", target: self, action: #selector(deleteSelectedResume))
        deleteResumeButton.translatesAutoresizingMaskIntoConstraints = false
        deleteResumeButton.bezelStyle = .rounded
        deleteResumeButton.isEnabled = false
        resumeView.addSubview(deleteResumeButton)
        
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
        
        // Add context menu
        let contextMenu = NSMenu()
        let deleteItem = NSMenuItem(title: "Delete Resume", action: #selector(deleteSelectedResume), keyEquivalent: "")
        let renameItem = NSMenuItem(title: "Rename Resume", action: #selector(renameSelectedResume), keyEquivalent: "")
        let viewItem = NSMenuItem(title: "View Details", action: #selector(viewResumeDetails), keyEquivalent: "")
        
        contextMenu.addItem(viewItem)
        contextMenu.addItem(renameItem)
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(deleteItem)
        
        resumeTableView.menu = contextMenu
        
        resumeManagerScrollView = NSScrollView()
        resumeManagerScrollView.documentView = resumeTableView
        resumeManagerScrollView.hasVerticalScroller = true
        resumeManagerScrollView.translatesAutoresizingMaskIntoConstraints = false
        resumeView.addSubview(resumeManagerScrollView)
        
        // Layout with flexible constraints
        let buttonTopConstraint = importResumeButton.topAnchor.constraint(equalTo: resumeView.topAnchor, constant: 20)
        let buttonLeadingConstraint = importResumeButton.leadingAnchor.constraint(equalTo: resumeView.leadingAnchor, constant: 20)
        let buttonWidthConstraint = importResumeButton.widthAnchor.constraint(equalToConstant: 160)
        
        let deleteButtonTopConstraint = deleteResumeButton.topAnchor.constraint(equalTo: resumeView.topAnchor, constant: 20)
        let deleteButtonLeadingConstraint = deleteResumeButton.leadingAnchor.constraint(equalTo: importResumeButton.trailingAnchor, constant: 10)
        let deleteButtonWidthConstraint = deleteResumeButton.widthAnchor.constraint(equalToConstant: 120)
        
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
            deleteButtonTopConstraint,
            deleteButtonLeadingConstraint,
            deleteButtonWidthConstraint,
            scrollTopConstraint,
            scrollLeadingConstraint,
            scrollTrailingConstraint,
            scrollBottomConstraint
        ])
        
        // Create workflow container view (initially hidden)
        workflowContainerView = NSView()
        workflowContainerView.translatesAutoresizingMaskIntoConstraints = false
        workflowContainerView.isHidden = true
        resumeView.addSubview(workflowContainerView)
        
        // Create workflow components
        setupWorkflowComponents()
        print("✅ Workflow components created")
        
        // Workflow container constraints (higher priority when shown)
        let workflowTopConstraint = workflowContainerView.topAnchor.constraint(equalTo: importResumeButton.bottomAnchor, constant: 20)
        let workflowLeadingConstraint = workflowContainerView.leadingAnchor.constraint(equalTo: resumeView.leadingAnchor, constant: 20)
        let workflowTrailingConstraint = workflowContainerView.trailingAnchor.constraint(equalTo: resumeView.trailingAnchor, constant: -20)
        let workflowBottomConstraint = workflowContainerView.bottomAnchor.constraint(equalTo: resumeView.bottomAnchor, constant: -20)
        
        // Set high priority for workflow when it's shown
        workflowTopConstraint.priority = .required
        workflowLeadingConstraint.priority = .required
        workflowTrailingConstraint.priority = .required
        workflowBottomConstraint.priority = .required
        
        NSLayoutConstraint.activate([
            workflowTopConstraint,
            workflowLeadingConstraint,
            workflowTrailingConstraint,
            workflowBottomConstraint
        ])
        
        resumeTab.view = resumeView
        tabView.addTabViewItem(resumeTab)
    }
    
    private func setupWorkflowComponents() {
        // Review text view with scroll view
        workflowScrollView = NSScrollView()
        workflowScrollView.translatesAutoresizingMaskIntoConstraints = false
        workflowScrollView.hasVerticalScroller = true
        workflowScrollView.borderType = .lineBorder
        
        reviewTextView = NSTextView()
        reviewTextView.isEditable = false
        reviewTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        reviewTextView.textColor = NSColor.textColor
        workflowScrollView.documentView = reviewTextView
        workflowContainerView.addSubview(workflowScrollView)
        
        // Proceed button
        proceedButton = NSButton(title: "Proceed (Clean with AI)", target: self, action: #selector(proceedWithCleaning))
        proceedButton.translatesAutoresizingMaskIntoConstraints = false
        proceedButton.bezelStyle = .rounded
        proceedButton.isEnabled = false
        workflowContainerView.addSubview(proceedButton)
        
        // Name text field with label
        let nameLabel = NSTextField(labelWithString: "Resume Name:")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        workflowContainerView.addSubview(nameLabel)
        
        nameTextField = NSTextField()
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.placeholderString = "Enter resume name"
        workflowContainerView.addSubview(nameTextField)
        
        // Save and Cancel buttons
        saveButton = NSButton(title: "Save Resume", target: self, action: #selector(saveProcessedResume))
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.bezelStyle = .rounded
        saveButton.isEnabled = false
        workflowContainerView.addSubview(saveButton)
        
        cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelWorkflow))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        workflowContainerView.addSubview(cancelButton)
        
        // Layout workflow components
        NSLayoutConstraint.activate([
            // Review text area
            workflowScrollView.topAnchor.constraint(equalTo: workflowContainerView.topAnchor, constant: 10),
            workflowScrollView.leadingAnchor.constraint(equalTo: workflowContainerView.leadingAnchor),
            workflowScrollView.trailingAnchor.constraint(equalTo: workflowContainerView.trailingAnchor),
            workflowScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            
            // Proceed button
            proceedButton.topAnchor.constraint(equalTo: workflowScrollView.bottomAnchor, constant: 10),
            proceedButton.centerXAnchor.constraint(equalTo: workflowContainerView.centerXAnchor),
            proceedButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            
            // Name input
            nameLabel.topAnchor.constraint(equalTo: proceedButton.bottomAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: workflowContainerView.leadingAnchor),
            
            nameTextField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
            nameTextField.leadingAnchor.constraint(equalTo: workflowContainerView.leadingAnchor),
            nameTextField.trailingAnchor.constraint(equalTo: workflowContainerView.trailingAnchor),
            
            // Action buttons
            saveButton.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 15),
            saveButton.leadingAnchor.constraint(equalTo: workflowContainerView.leadingAnchor),
            saveButton.bottomAnchor.constraint(equalTo: workflowContainerView.bottomAnchor, constant: -10),
            
            cancelButton.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 15),
            cancelButton.trailingAnchor.constraint(equalTo: workflowContainerView.trailingAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: workflowContainerView.bottomAnchor, constant: -10),
            
            // Button spacing
            cancelButton.leadingAnchor.constraint(greaterThanOrEqualTo: saveButton.trailingAnchor, constant: 20)
        ])
    }
    
    private func setupAnalysisTab() {
        let analysisTab = NSTabViewItem()
        analysisTab.label = "Job Analysis"
        
        analysisView = NSView()
        analysisView.translatesAutoresizingMaskIntoConstraints = false
        
        // Resume Content Display
        resumeLabel = NSTextField(labelWithString: "Active Resume:")
        resumeLabel.translatesAutoresizingMaskIntoConstraints = false
        analysisView.addSubview(resumeLabel)
        
        resumeScrollView = NSScrollView()
        resumeScrollView.translatesAutoresizingMaskIntoConstraints = false
        resumeScrollView.hasVerticalScroller = true
        resumeScrollView.borderType = .lineBorder
        
        resumeTextView = NSTextView()
        resumeTextView.isEditable = false
        resumeTextView.font = NSFont.systemFont(ofSize: 12)
        resumeScrollView.documentView = resumeTextView
        analysisView.addSubview(resumeScrollView)
        
        // Job Description Input
        jobLabel = NSTextField(labelWithString: "Job Description:")
        jobLabel.translatesAutoresizingMaskIntoConstraints = false
        analysisView.addSubview(jobLabel)
        
        jobScrollView = NSScrollView()
        jobScrollView.translatesAutoresizingMaskIntoConstraints = false
        jobScrollView.hasVerticalScroller = true
        jobScrollView.borderType = .lineBorder
        
        jobDescriptionTextView = NSTextView()
        jobDescriptionTextView.isRichText = false
        jobDescriptionTextView.font = NSFont.systemFont(ofSize: 12)
        jobScrollView.documentView = jobDescriptionTextView
        analysisView.addSubview(jobScrollView)
        
        // Set up text change monitoring for job description
        jobDescriptionTextView.delegate = self
        
        // Analysis Method Selector
        methodLabel = NSTextField(labelWithString: "Analysis Method:")
        methodLabel.translatesAutoresizingMaskIntoConstraints = false
        analysisView.addSubview(methodLabel)
        
        methodSegmentedControl = NSSegmentedControl(labels: ["4-Run Analysis", "Single-Run Analysis"], trackingMode: .selectOne, target: self, action: #selector(analysisMethodChanged))
        methodSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        methodSegmentedControl.selectedSegment = 0 // Default to 4-run
        analysisView.addSubview(methodSegmentedControl)
        
        // Analyze Button
        analyzeButton = NSButton(title: "Analyze Match", target: self, action: #selector(analyzeMatch))
        analyzeButton.translatesAutoresizingMaskIntoConstraints = false
        analyzeButton.bezelStyle = .rounded
        analyzeButton.isEnabled = false
        analysisView.addSubview(analyzeButton)
        
        // Status Label
        statusLabel = NSTextField(labelWithString: "Ready to analyze using 4-Run Analysis")
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
        
        let methodLabelTop = methodLabel.topAnchor.constraint(equalTo: jobScrollView.bottomAnchor, constant: 20)
        let methodLabelLeading = methodLabel.leadingAnchor.constraint(equalTo: analysisView.leadingAnchor, constant: 20)
        
        let methodControlTop = methodSegmentedControl.topAnchor.constraint(equalTo: methodLabel.bottomAnchor, constant: 5)
        let methodControlLeading = methodSegmentedControl.leadingAnchor.constraint(equalTo: analysisView.leadingAnchor, constant: 20)
        let methodControlTrailing = methodSegmentedControl.trailingAnchor.constraint(equalTo: analysisView.trailingAnchor, constant: -20)
        
        let analyzeButtonTop = analyzeButton.topAnchor.constraint(equalTo: methodSegmentedControl.bottomAnchor, constant: 10)
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
        methodLabelTop.priority = .defaultHigh
        methodControlTop.priority = .defaultHigh
        methodControlTrailing.priority = .defaultHigh
        analyzeButtonTop.priority = .defaultHigh
        statusLabelTop.priority = .defaultHigh
        resultsScrollTop.priority = .defaultHigh
        resultsScrollLeading.priority = .defaultHigh
        resultsScrollTrailing.priority = .defaultHigh
        resultsScrollBottom.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            resumeLabelTop, resumeLabelLeading,
            resumeScrollTop, resumeScrollLeading, resumeScrollTrailing, resumeScrollHeight,
            jobLabelTop, jobLabelLeading,
            jobScrollTop, jobScrollLeading, jobScrollTrailing, jobScrollHeight,
            methodLabelTop, methodLabelLeading,
            methodControlTop, methodControlLeading, methodControlTrailing,
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
        updateDeleteButtonState()
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
        statusLabel.stringValue = "Extracting text from PDF..."
        
        Task {
            do {
                // Step 1: Extract text from PDF only
                let extractedText = try await self.resumeManager.extractTextFromPDF(url: url)
                
                await MainActor.run {
                    // Step 2: Store pending data and show workflow UI
                    self.pendingResumeData = (url: url, extractedText: extractedText)
                    self.showResumeWorkflow(extractedText: extractedText, fileName: url.deletingPathExtension().lastPathComponent)
                    self.statusLabel.stringValue = "Ready to process resume. Click 'Proceed' to clean with AI."
                    print("✅ Text extracted from: \(url.lastPathComponent)")
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.stringValue = "Import error: \(error.localizedDescription)"
                    print("❌ Import error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showResumeWorkflow(extractedText: String, fileName: String) {
        // Hide table view and show workflow UI
        resumeManagerScrollView.isHidden = true
        workflowContainerView.isHidden = false
        
        // Show the extracted text for review
        reviewTextView.string = extractedText
        
        // Pre-populate the name field with the filename
        nameTextField.stringValue = fileName
        
        // Enable proceed button
        proceedButton.isEnabled = true
        proceedButton.title = "Proceed (Clean with AI)"
        
        // Reset other buttons
        saveButton.isEnabled = false
        saveButton.title = "Save Resume"
    }
    
    @objc private func proceedWithCleaning() {
        guard let pendingData = pendingResumeData else { return }
        
        proceedButton.isEnabled = false
        proceedButton.title = "Processing..."
        statusLabel.stringValue = "Cleaning resume with AI..."
        
        Task {
            do {
                // Step 3: Clean the text using the background server
                let cleanedText = try await self.resumeManager.cleanResumeText(pendingData.extractedText)
                
                await MainActor.run {
                    // Step 4: Show cleaned text for review
                    self.reviewTextView.string = cleanedText
                    self.proceedButton.title = "✅ Cleaning Complete"
                    self.saveButton.isEnabled = true
                    self.statusLabel.stringValue = "Review the cleaned resume and click Save to store it."
                    print("✅ Resume cleaned with AI")
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.stringValue = "Cleaning error: \(error.localizedDescription)"
                    self.proceedButton.isEnabled = true
                    self.proceedButton.title = "Retry Cleaning"
                    print("❌ Cleaning error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func saveProcessedResume() {
        guard let pendingData = pendingResumeData else { return }
        
        let name = nameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusLabel.stringValue = "Please enter a name for the resume"
            return
        }
        
        let cleanedText = reviewTextView.string
        guard !cleanedText.isEmpty else {
            statusLabel.stringValue = "No cleaned text to save"
            return
        }
        
        // Step 5: Create and save the resume
        let resume = ResumeItem(name: name, cleanedText: cleanedText)
        resumeManager.saveResume(resume)
        resumeManager.setActiveResume(resume)
        
        // Step 6: Hide workflow and refresh UI
        hideResumeWorkflow()
        loadResumeManager()
        statusLabel.stringValue = "Resume '\(name)' saved successfully!"
        
        // Clear pending data
        pendingResumeData = nil
        
        print("✅ Resume saved: \(name)")
    }
    
    @objc private func cancelWorkflow() {
        hideResumeWorkflow()
        pendingResumeData = nil
        statusLabel.stringValue = "Resume import cancelled"
        print("❌ Resume workflow cancelled")
    }
    
    private func hideResumeWorkflow() {
        workflowContainerView.isHidden = true
        resumeManagerScrollView.isHidden = false
        reviewTextView.string = ""
        nameTextField.stringValue = ""
        proceedButton.isEnabled = false
        saveButton.isEnabled = false
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
        
        let analysisMethod = getCurrentAnalysisMethod()
        let methodName = analysisMethod == .fourRun ? "4-Run Analysis" : "Single-Run Analysis"
        
        isAnalyzing = true
        analyzeButton.title = "Analyzing..."
        analyzeButton.isEnabled = false
        statusLabel.stringValue = "Running \(methodName)..."
        analysisResultsTextView.string = "🔍 Starting \(methodName)...\n\nSending request to WhatYOE background server for processing..."
        
        Task {
            do {
                let results = try await requestAnalysisFromMainApp(
                    resumeText: activeResume.cleanedText,
                    jobDescription: jobDescription,
                    method: analysisMethod
                )
                
                await MainActor.run {
                    self.analysisResultsTextView.string = results
                    self.statusLabel.stringValue = "\(methodName) complete"
                    self.isAnalyzing = false
                    self.analyzeButton.title = "Analyze Match"
                    self.analyzeButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    self.analysisResultsTextView.string = "❌ \(methodName) failed: \(error.localizedDescription)"
                    self.statusLabel.stringValue = "Analysis failed"
                    self.isAnalyzing = false
                    self.analyzeButton.title = "Analyze Match"
                    self.analyzeButton.isEnabled = true
                }
            }
        }
    }
    
    @objc private func analysisMethodChanged() {
        let selectedMethod = methodSegmentedControl.selectedSegment
        let methodName = selectedMethod == 0 ? "4-Run Analysis" : "Single-Run Analysis"
        print("🔄 Analysis method changed to: \(methodName)")
        
        // Update status to show selected method
        statusLabel.stringValue = "Ready to analyze using \(methodName)"
        statusLabel.textColor = NSColor.secondaryLabelColor
    }
    
    // MARK: - Analysis Methods
    
    private func getCurrentAnalysisMethod() -> AnalysisMethod {
        return methodSegmentedControl.selectedSegment == 0 ? .fourRun : .singleRun
    }
    
    private enum AnalysisMethod {
        case fourRun
        case singleRun
    }
    
    private func requestAnalysisFromMainApp(resumeText: String, jobDescription: String, method: AnalysisMethod) async throws -> String {
        // Create analysis request
        let request = AnalysisRequest(
            id: UUID().uuidString,
            resumeText: resumeText,
            jobDescription: jobDescription,
            timestamp: Date()
        )
        
        // Store request and method in shared defaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        if let requestData = try? JSONEncoder().encode(request) {
            sharedDefaults.set(requestData, forKey: "analysisRequest")
            sharedDefaults.set(method == .fourRun ? "fourRun" : "singleRun", forKey: "analysisMethod")
            sharedDefaults.set("pending", forKey: "analysisStatus")
        }
        
        // Launch main app to process the request
        try await launchMainAppForAnalysis()
        
        // Wait for response
        return try await waitForAnalysisResponse(requestId: request.id)
    }
    
    private func launchMainAppForAnalysis() async throws {
        let bundleIdentifier = "com.kuangming.WhatYOE"
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw NSError(domain: "AppLaunch", code: 1, userInfo: [NSLocalizedDescriptionKey: "WhatYOE main app not found"])
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--job-analysis"]
        
        try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        print("🔍 Launched WhatYOE main app for job analysis")
    }
    
    private func waitForAnalysisResponse(requestId: String) async throws -> String {
        let sharedDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
        let maxWaitTime: TimeInterval = 60.0 // 60 seconds timeout for analysis
        let checkInterval: TimeInterval = 0.5 // Check every 500ms
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxWaitTime {
            // Check if response is ready
            if let responseData = sharedDefaults.data(forKey: "analysisResponse"),
               let response = try? JSONDecoder().decode(AnalysisResponse.self, from: responseData),
               response.requestId == requestId {
                
                // Clean up
                sharedDefaults.removeObject(forKey: "analysisRequest")
                sharedDefaults.removeObject(forKey: "analysisResponse")
                sharedDefaults.removeObject(forKey: "analysisStatus")
                
                if let error = response.error {
                    throw NSError(domain: "Analysis", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
                }
                
                return response.results ?? ""
            }
            
            // Wait before checking again
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
        
        throw NSError(domain: "Analysis", code: 3, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for analysis response from main app"])
    }
    
    func selectTab(_ index: Int) {
        guard index < tabView.numberOfTabViewItems else { return }
        tabView.selectTabViewItem(at: index)
    }
    
    private func updateAnalyzeButtonState() {
        let jobDescription = jobDescriptionTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasResume = resumeManager.activeResume != nil
        
        analyzeButton.isEnabled = !isAnalyzing && !jobDescription.isEmpty && hasResume
        
        if analyzeButton.isEnabled {
            let methodName = getCurrentAnalysisMethod() == .fourRun ? "4-Run Analysis" : "Single-Run Analysis"
            statusLabel.stringValue = "Ready to analyze using \(methodName)"
            statusLabel.textColor = NSColor.secondaryLabelColor
        } else {
            statusLabel.stringValue = "Please select a resume and enter a job description to analyze."
            statusLabel.textColor = NSColor.systemGray
        }
    }
    
    @objc private func deleteSelectedResume() {
        let selectedRow = resumeTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < resumeManager.getAllResumes().count else { return }
        
        let selectedResume = resumeManager.getAllResumes()[selectedRow]
        
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Delete Resume"
        alert.informativeText = "Are you sure you want to delete '\(selectedResume.name)'? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Delete the resume
            resumeManager.deleteResume(withId: selectedResume.id)
            
            // If it was the active resume, clear the active resume
            if selectedResume.isActive {
                // Clear the active resume by setting it to nil (no active resume)
                let userDefaults = UserDefaults(suiteName: "group.com.kuangming.WhatYOE.shared") ?? UserDefaults.standard
                userDefaults.removeObject(forKey: "activeResumeId")
                userDefaults.removeObject(forKey: "cleanedResumeData")
                loadActiveResumeContent()
            }
            
            // Refresh the UI
            loadResumeManager()
            updateDeleteButtonState()
            updateAnalyzeButtonState()
            
            statusLabel.stringValue = "Resume '\(selectedResume.name)' deleted successfully!"
            print("🗑️ Deleted resume: \(selectedResume.name)")
        }
    }
    
    private func updateDeleteButtonState() {
        let selectedRow = resumeTableView.selectedRow
        deleteResumeButton.isEnabled = selectedRow >= 0 && selectedRow < resumeManager.getAllResumes().count
    }
    
    @objc private func renameSelectedResume() {
        let selectedRow = resumeTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < resumeManager.getAllResumes().count else { return }
        
        let selectedResume = resumeManager.getAllResumes()[selectedRow]
        
        // Show rename dialog
        let alert = NSAlert()
        alert.messageText = "Rename Resume"
        alert.informativeText = "Enter a new name for '\(selectedResume.name)':"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = selectedResume.name
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty && newName != selectedResume.name {
                // Create new resume with new name (will get new ID)
                let renamedResume = ResumeItem(name: newName, cleanedText: selectedResume.cleanedText)
                
                // Delete old and save new
                resumeManager.deleteResume(withId: selectedResume.id)
                resumeManager.saveResume(renamedResume)
                
                // If it was active, set the renamed one as active
                if selectedResume.isActive {
                    resumeManager.setActiveResume(renamedResume)
                }
                
                // Refresh UI
                loadResumeManager()
                statusLabel.stringValue = "Resume renamed to '\(newName)' successfully!"
                print("✏️ Renamed resume from '\(selectedResume.name)' to '\(newName)'")
            }
        }
    }
    
    @objc private func viewResumeDetails() {
        let selectedRow = resumeTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < resumeManager.getAllResumes().count else { return }
        
        let selectedResume = resumeManager.getAllResumes()[selectedRow]
        
        // Show resume details in a new window
        let detailWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        detailWindow.title = "Resume Details - \(selectedResume.name)"
        detailWindow.center()
        
        let detailView = NSView()
        detailView.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = NSTextField(labelWithString: "Name: \(selectedResume.name)")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let dateLabel = NSTextField(labelWithString: "Created: \(DateFormatter.localizedString(from: selectedResume.dateCreated, dateStyle: .medium, timeStyle: .short))")
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let statusLabel = NSTextField(labelWithString: "Status: \(selectedResume.isActive ? "Active" : "Available")")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let contentLabel = NSTextField(labelWithString: "Content:")
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let contentScrollView = NSScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.borderType = .lineBorder
        
        let contentTextView = NSTextView()
        contentTextView.isEditable = false
        contentTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        contentTextView.string = selectedResume.cleanedText
        contentScrollView.documentView = contentTextView
        
        detailView.addSubview(nameLabel)
        detailView.addSubview(dateLabel)
        detailView.addSubview(statusLabel)
        detailView.addSubview(contentLabel)
        detailView.addSubview(contentScrollView)
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: detailView.topAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 20),
            
            dateLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            dateLabel.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 20),
            
            statusLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 20),
            
            contentLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            contentLabel.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 20),
            
            contentScrollView.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 10),
            contentScrollView.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 20),
            contentScrollView.trailingAnchor.constraint(equalTo: detailView.trailingAnchor, constant: -20),
            contentScrollView.bottomAnchor.constraint(equalTo: detailView.bottomAnchor, constant: -20)
        ])
        
        detailWindow.contentView = detailView
        detailWindow.makeKeyAndOrderFront(nil)
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
        updateAnalyzeButtonState()
        updateDeleteButtonState()
    }
}

extension DesktopAnalysisViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        updateAnalyzeButtonState()
    }
}

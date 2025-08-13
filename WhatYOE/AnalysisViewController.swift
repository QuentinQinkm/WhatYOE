//
//  AnalysisViewController.swift
//  WhatYOE
//
//  Main view controller with tabbed interface for Resume management and Local analysis
//

import Cocoa
import PDFKit
import Foundation
import System
import FoundationModels
import os.log

class AnalysisViewController: NSViewController {
    
    // MARK: - UI Elements
    private var tabView: NSTabView!
    private var resumeViewController: ResumeViewController!
    private var localAnalysisViewController: LocalAnalysisViewController!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Create tab view
        tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)
        
        // Create Resume tab
        resumeViewController = ResumeViewController()
        let resumeTabItem = NSTabViewItem(viewController: resumeViewController)
        resumeTabItem.label = "Resume"
        tabView.addTabViewItem(resumeTabItem)
        
        // Create Local Analysis tab
        localAnalysisViewController = LocalAnalysisViewController()
        let localTabItem = NSTabViewItem(viewController: localAnalysisViewController)
        localTabItem.label = "Local Analysis"
        tabView.addTabViewItem(localTabItem)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func selectTab(_ index: Int) {
        guard index >= 0 && index < tabView.numberOfTabViewItems else { return }
        tabView.selectTabViewItem(at: index)
    }
}

// MARK: - Resume Tab View Controller
class ResumeViewController: NSViewController {
    
    // MARK: - UI Elements
    private var splitView: NSSplitView!
    private var leftPanel: NSView!
    private var rightPanel: NSView!
    private var resumeListView: NSTableView!
    private var scrollView: NSScrollView!
    private var addButton: NSButton!
    private var deleteButton: NSButton!
    private var proceedButton: NSButton!
    private var pdfTextView: NSTextView!
    private var cleanedTextView: NSTextView!
    private var saveButton: NSButton!
    private var nameTextField: NSTextField!
    
    // MARK: - Data
    private var resumes: [ResumeItem] = []
    private var selectedResume: ResumeItem?
    private var extractedText: String = ""
    private var cleanedText: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resumes = ResumeManager.shared.getAllResumes()
        setupUI()
        
        // Set initial state
        pdfTextView.string = "📂 Select 'Add' to import a PDF resume"
        cleanedTextView.string = "🤖 AI cleaned text will appear here after processing"
        saveButton.isEnabled = false
        proceedButton.isEnabled = false
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Create split view
        splitView = NSSplitView()
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        view.addSubview(splitView)
        
        // Left panel
        leftPanel = NSView()
        leftPanel.translatesAutoresizingMaskIntoConstraints = false
        
        // Resume list
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder
        
        resumeListView = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Saved Resumes"
        column.width = 200
        resumeListView.addTableColumn(column)
        resumeListView.headerView = NSTableHeaderView()
        resumeListView.dataSource = self
        resumeListView.delegate = self
        
        scrollView.documentView = resumeListView
        leftPanel.addSubview(scrollView)
        
        // Buttons
        let buttonStack = NSStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 10
        
        addButton = NSButton(title: "Add", target: self, action: #selector(addResume))
        deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteResume))
        deleteButton.isEnabled = false
        
        buttonStack.addArrangedSubview(addButton)
        buttonStack.addArrangedSubview(deleteButton)
        leftPanel.addSubview(buttonStack)
        
        // Right panel
        rightPanel = NSView()
        rightPanel.translatesAutoresizingMaskIntoConstraints = false
        
        proceedButton = NSButton(title: "Clean with AI", target: self, action: #selector(proceedAnalysis))
        proceedButton.translatesAutoresizingMaskIntoConstraints = false
        proceedButton.isEnabled = false
        rightPanel.addSubview(proceedButton)
        
        // PDF Text view (original extracted text)
        let pdfLabel = NSTextField(labelWithString: "PDF Extracted Text:")
        pdfLabel.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(pdfLabel)
        
        let pdfScrollView = NSScrollView()
        pdfScrollView.translatesAutoresizingMaskIntoConstraints = false
        pdfScrollView.hasVerticalScroller = true
        pdfScrollView.borderType = .lineBorder
        
        pdfTextView = NSTextView()
        pdfTextView.isEditable = false
        pdfTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        pdfScrollView.documentView = pdfTextView
        rightPanel.addSubview(pdfScrollView)
        
        // Cleaned text view (AI processed)
        let cleanedLabel = NSTextField(labelWithString: "AI Cleaned Text:")
        cleanedLabel.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(cleanedLabel)
        
        let cleanedScrollView = NSScrollView()
        cleanedScrollView.translatesAutoresizingMaskIntoConstraints = false
        cleanedScrollView.hasVerticalScroller = true
        cleanedScrollView.borderType = .lineBorder
        
        cleanedTextView = NSTextView()
        cleanedTextView.isEditable = false
        cleanedTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        cleanedScrollView.documentView = cleanedTextView
        rightPanel.addSubview(cleanedScrollView)
        
        // Save section
        let saveLabel = NSTextField(labelWithString: "Name (optional):")
        saveLabel.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(saveLabel)
        
        nameTextField = NSTextField()
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.placeholderString = "Resume name..."
        rightPanel.addSubview(nameTextField)
        
        saveButton = NSButton(title: "Save", target: self, action: #selector(saveCleanedResume))
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.isEnabled = false
        rightPanel.addSubview(saveButton)
        
        // Add panels to split view
        splitView.addArrangedSubview(leftPanel)
        splitView.addArrangedSubview(rightPanel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            
            // Left panel constraints
            scrollView.topAnchor.constraint(equalTo: leftPanel.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -10),
            
            buttonStack.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: leftPanel.bottomAnchor),
            buttonStack.heightAnchor.constraint(equalToConstant: 30),
            
            // Right panel constraints
            proceedButton.topAnchor.constraint(equalTo: rightPanel.topAnchor),
            proceedButton.centerXAnchor.constraint(equalTo: rightPanel.centerXAnchor),
            proceedButton.heightAnchor.constraint(equalToConstant: 30),
            
            pdfLabel.topAnchor.constraint(equalTo: proceedButton.bottomAnchor, constant: 10),
            pdfLabel.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            
            pdfScrollView.topAnchor.constraint(equalTo: pdfLabel.bottomAnchor, constant: 5),
            pdfScrollView.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            pdfScrollView.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),
            pdfScrollView.heightAnchor.constraint(equalTo: rightPanel.heightAnchor, multiplier: 0.3),
            
            cleanedLabel.topAnchor.constraint(equalTo: pdfScrollView.bottomAnchor, constant: 10),
            cleanedLabel.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            
            cleanedScrollView.topAnchor.constraint(equalTo: cleanedLabel.bottomAnchor, constant: 5),
            cleanedScrollView.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            cleanedScrollView.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),
            cleanedScrollView.bottomAnchor.constraint(equalTo: saveLabel.topAnchor, constant: -10),
            
            saveLabel.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            saveLabel.bottomAnchor.constraint(equalTo: nameTextField.topAnchor, constant: -5),
            
            nameTextField.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            nameTextField.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -10),
            nameTextField.bottomAnchor.constraint(equalTo: rightPanel.bottomAnchor),
            nameTextField.heightAnchor.constraint(equalToConstant: 25),
            
            saveButton.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),
            saveButton.bottomAnchor.constraint(equalTo: rightPanel.bottomAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 25),
            saveButton.widthAnchor.constraint(equalToConstant: 60)
        ])
        
        // Set split view proportions
        splitView.setPosition(250, ofDividerAt: 0)
    }
    
    @objc private func addResume() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.pdf]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.begin { [weak self] result in
            if result == .OK, let url = openPanel.url {
                self?.processResumePDF(url)
            }
        }
    }
    
    @objc private func deleteResume() {
        guard let selectedResume = selectedResume else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Resume"
        alert.informativeText = "Are you sure you want to delete '\(selectedResume.name)'?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            ResumeManager.shared.deleteResume(withId: selectedResume.id)
            resumes = ResumeManager.shared.getAllResumes()
            resumeListView.reloadData()
            self.selectedResume = nil
            updateButtonStates()
        }
    }
    
    @objc private func proceedAnalysis() {
        guard !extractedText.isEmpty else { return }
        
        proceedButton.title = "Cleaning with AI..."
        proceedButton.isEnabled = false
        cleanedTextView.string = "🤖 AI is cleaning the resume text...\n\nThis may take a few moments."
        
        Task {
            do {
                let cleanedText = try await cleanText(extractedText)
                self.cleanedText = cleanedText
                
                await MainActor.run {
                    self.cleanedTextView.string = cleanedText
                    self.saveButton.isEnabled = true
                    self.proceedButton.title = "Clean with AI"
                    self.proceedButton.isEnabled = true
                    
                    // Auto-fill name field
                    if self.nameTextField.stringValue.isEmpty {
                        let baseName = "Resume_\(Int(Date().timeIntervalSince1970))"
                        self.nameTextField.stringValue = baseName
                    }
                }
            } catch {
                await MainActor.run {
                    self.cleanedTextView.string = "❌ Error cleaning text: \(error.localizedDescription)\n\nOriginal text:\n\(self.extractedText)"
                    self.proceedButton.title = "Clean with AI"
                    self.proceedButton.isEnabled = true
                }
            }
        }
    }
    
    @objc private func saveCleanedResume() {
        guard !cleanedText.isEmpty else { return }
        
        let name = nameTextField.stringValue.isEmpty ? "Cleaned_Resume_\(Date().timeIntervalSince1970)" : nameTextField.stringValue
        let resume = ResumeItem(name: name, cleanedText: cleanedText)
        
        ResumeManager.shared.saveResume(resume)
        resumes = ResumeManager.shared.getAllResumes()
        resumeListView.reloadData()
        
        saveButton.isEnabled = false
        nameTextField.stringValue = ""
        
        let alert = NSAlert()
        alert.messageText = "Resume Saved"
        alert.informativeText = "Resume '\(name)' has been saved successfully."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func processResumePDF(_ url: URL) {
        proceedButton.isEnabled = false
        saveButton.isEnabled = false
        pdfTextView.string = "📄 Extracting text from PDF..."
        cleanedTextView.string = ""
        cleanedText = ""
        
        Task {
            do {
                let extractedText = try await extractTextFromPDF(url)
                self.extractedText = extractedText
                
                await MainActor.run {
                    self.pdfTextView.string = extractedText
                    self.proceedButton.isEnabled = true
                    self.nameTextField.stringValue = url.deletingPathExtension().lastPathComponent
                    self.cleanedTextView.string = "👆 Click 'Clean with AI' to process the extracted text"
                }
            } catch {
                await MainActor.run {
                    self.pdfTextView.string = "❌ Error processing PDF: \(error.localizedDescription)"
                    self.cleanedTextView.string = ""
                }
            }
        }
    }
    
    private func updateButtonStates() {
        deleteButton.isEnabled = selectedResume != nil
        proceedButton.isEnabled = !extractedText.isEmpty
        saveButton.isEnabled = !cleanedText.isEmpty
    }
    
    private func extractTextFromPDF(_ url: URL) async throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw NSError(domain: "PDFError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load PDF document"])
        }
        
        var extractedText = ""
        let pageCount = pdfDocument.pageCount
        
        for i in 0..<pageCount {
            if let page = pdfDocument.page(at: i) {
                if let pageContent = page.string {
                    extractedText += pageContent + "\n"
                }
            }
        }
        
        return extractedText
    }
    
    private func cleanText(_ text: String) async throws -> String {
        let session = LanguageModelSession(instructions: PromptTemplates.resumeCleaningPrompt)
        let prompt = PromptTemplates.resumeCleaningPrompt + "\n\nText to clean:\n\(text)"
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - TableView DataSource & Delegate
extension ResumeViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return resumes.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("ResumeCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = NSColor.clear
            textField.isEditable = false
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(textField)
            cell?.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -5),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
            
            cell?.identifier = cellIdentifier
        }
        
        cell?.textField?.stringValue = resumes[row].name
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = resumeListView.selectedRow
        if selectedRow >= 0 && selectedRow < resumes.count {
            selectedResume = resumes[selectedRow]
            ResumeManager.shared.setActiveResume(resumes[selectedRow])
            
            // Display the selected resume's cleaned text
            extractedText = ""
            cleanedText = selectedResume!.cleanedText
            pdfTextView.string = "📄 Previously processed resume\n(PDF text no longer available)"
            cleanedTextView.string = selectedResume!.cleanedText
            nameTextField.stringValue = selectedResume!.name
            
        } else {
            selectedResume = nil
            extractedText = ""
            cleanedText = ""
            pdfTextView.string = ""
            cleanedTextView.string = ""
            nameTextField.stringValue = ""
        }
        updateButtonStates()
    }
}

// MARK: - Local Analysis Tab View Controller
class LocalAnalysisViewController: NSViewController {
    
    // MARK: - UI Elements
    private var resumeSelector: NSPopUpButton!
    private var jobTextView: NSTextView!
    private var analyzeButton: NSButton!
    private var resultsTextView: NSTextView!
    private var noResumeLabel: NSTextField!
    
    // MARK: - Data
    private var selectedResumeId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        refreshResumeList()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        refreshResumeList()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Resume selector
        let selectorLabel = NSTextField(labelWithString: "Select Resume:")
        selectorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectorLabel)
        
        resumeSelector = NSPopUpButton()
        resumeSelector.translatesAutoresizingMaskIntoConstraints = false
        resumeSelector.target = self
        resumeSelector.action = #selector(resumeSelectionChanged)
        view.addSubview(resumeSelector)
        
        // No resume message
        noResumeLabel = NSTextField(labelWithString: "Please import a resume in the Resume tab")
        noResumeLabel.translatesAutoresizingMaskIntoConstraints = false
        noResumeLabel.textColor = NSColor.secondaryLabelColor
        noResumeLabel.isHidden = true
        view.addSubview(noResumeLabel)
        
        // Job description input
        let jobLabel = NSTextField(labelWithString: "Job Description:")
        jobLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(jobLabel)
        
        let jobScrollView = NSScrollView()
        jobScrollView.translatesAutoresizingMaskIntoConstraints = false
        jobScrollView.hasVerticalScroller = true
        jobScrollView.borderType = .lineBorder
        
        jobTextView = NSTextView()
        jobTextView.isRichText = false
        jobTextView.font = NSFont.systemFont(ofSize: 12)
        jobTextView.delegate = self
        jobScrollView.documentView = jobTextView
        view.addSubview(jobScrollView)
        
        // Analyze button
        analyzeButton = NSButton(title: "Analyze Match", target: self, action: #selector(analyzeMatch))
        analyzeButton.translatesAutoresizingMaskIntoConstraints = false
        analyzeButton.isEnabled = false
        view.addSubview(analyzeButton)
        
        // Results
        let resultsLabel = NSTextField(labelWithString: "Analysis Results:")
        resultsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultsLabel)
        
        let resultsScrollView = NSScrollView()
        resultsScrollView.translatesAutoresizingMaskIntoConstraints = false
        resultsScrollView.hasVerticalScroller = true
        resultsScrollView.borderType = .lineBorder
        
        resultsTextView = NSTextView()
        resultsTextView.isEditable = false
        resultsTextView.font = NSFont.systemFont(ofSize: 12)
        resultsScrollView.documentView = resultsTextView
        view.addSubview(resultsScrollView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            selectorLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            selectorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            resumeSelector.topAnchor.constraint(equalTo: selectorLabel.bottomAnchor, constant: 5),
            resumeSelector.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resumeSelector.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            noResumeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noResumeLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            jobLabel.topAnchor.constraint(equalTo: resumeSelector.bottomAnchor, constant: 20),
            jobLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            jobScrollView.topAnchor.constraint(equalTo: jobLabel.bottomAnchor, constant: 5),
            jobScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            jobScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            jobScrollView.heightAnchor.constraint(equalToConstant: 120),
            
            analyzeButton.topAnchor.constraint(equalTo: jobScrollView.bottomAnchor, constant: 10),
            analyzeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            resultsLabel.topAnchor.constraint(equalTo: analyzeButton.bottomAnchor, constant: 20),
            resultsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            resultsScrollView.topAnchor.constraint(equalTo: resultsLabel.bottomAnchor, constant: 5),
            resultsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            resultsScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }
    
    private func refreshResumeList() {
        resumeSelector.removeAllItems()
        let resumes = ResumeManager.shared.getAllResumes()
        
        if resumes.isEmpty {
            noResumeLabel.isHidden = false
            resumeSelector.isHidden = true
            jobTextView.isEditable = false
            analyzeButton.isEnabled = false
        } else {
            noResumeLabel.isHidden = true
            resumeSelector.isHidden = false
            jobTextView.isEditable = true
            
            for resume in resumes {
                resumeSelector.addItem(withTitle: resume.name)
                resumeSelector.lastItem?.representedObject = resume.id
            }
            
            // Select active resume if available
            if let activeId = ResumeManager.shared.getActiveResumeId() {
                for i in 0..<resumeSelector.numberOfItems {
                    if resumeSelector.item(at: i)?.representedObject as? String == activeId {
                        resumeSelector.selectItem(at: i)
                        selectedResumeId = activeId
                        break
                    }
                }
            }
            
            updateAnalyzeButtonState()
        }
    }
    
    @objc private func resumeSelectionChanged() {
        selectedResumeId = resumeSelector.selectedItem?.representedObject as? String
        if let id = selectedResumeId,
           let resume = ResumeManager.shared.getResume(withId: id) {
            ResumeManager.shared.setActiveResume(resume)
        }
        updateAnalyzeButtonState()
    }
    
    @objc private func analyzeMatch() {
        guard let resumeId = selectedResumeId,
              let resume = ResumeManager.shared.getResume(withId: resumeId) else {
            return
        }
        
        let jobDescription = jobTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !jobDescription.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Missing Job Description"
            alert.informativeText = "Please enter a job description to analyze."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        analyzeButton.title = "Analyzing..."
        analyzeButton.isEnabled = false
        resultsTextView.string = "🔍 Analyzing resume-job match...\n\nPlease wait while the AI processes your documents."
        
        Task {
            do {
                let cleanedJob = await cleanJobDescription(jobDescription)
                let results = try await performFourRoundEvaluation(
                    resumeText: resume.cleanedText,
                    jobDescription: cleanedJob
                )
                
                let combinedResults = combineEvaluationResults(results: results)
                
                await MainActor.run {
                    self.resultsTextView.string = combinedResults
                    self.analyzeButton.title = "Analyze Match"
                    self.analyzeButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    self.resultsTextView.string = "Analysis failed: \(error.localizedDescription)"
                    self.analyzeButton.title = "Analyze Match"
                    self.analyzeButton.isEnabled = true
                }
            }
        }
    }
    
    private func updateAnalyzeButtonState() {
        let hasResume = selectedResumeId != nil
        let hasJobDescription = !jobTextView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        analyzeButton.isEnabled = hasResume && hasJobDescription
    }
    
    // MARK: - AI Analysis Methods
    private func cleanJobDescription(_ jobText: String) async -> String {
        do {
            let session = LanguageModelSession(instructions: PromptTemplates.jobCleaningPrompt)
            let prompt = "Clean this job description:\n\n\(jobText)"
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            return jobText
        }
    }
    
    private func performFourRoundEvaluation(resumeText: String, jobDescription: String) async throws -> [String] {
        let model = SystemLanguageModel.default
        
        guard case .available = model.availability else {
            throw NSError(domain: "AI", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI not available"])
        }
        
        let prompts = [
            PromptTemplates.yearsEvaluationPrompt,
            PromptTemplates.educationEvaluationPrompt,
            PromptTemplates.technicalSkillsEvaluationPrompt,
            PromptTemplates.relevantExperienceEvaluationPrompt
        ]
        
        var results: [String] = []
        
        for prompt in prompts {
            let session = LanguageModelSession(instructions: prompt)
            let fullPrompt = prompt + "\n\nResume:\n\(resumeText)\n\nJob Description:\n\(jobDescription)"
            let response = try await session.respond(to: fullPrompt)
            results.append(response.content)
        }
        
        return results
    }
    
    private func combineEvaluationResults(results: [String]) -> String {
        let yearsResult = results[0]
        let educationResult = results[1]
        let skillsResult = results[2]
        let experienceResult = results[3]
        
        let (fitScores, gapScores) = extractScoresFromResults(
            years: yearsResult,
            education: educationResult,
            skills: skillsResult,
            experience: experienceResult
        )
        
        let totalFitScore = fitScores.reduce(0.0, +)
        let totalGapScore = gapScores.reduce(0.0, +)
        let finalScore = (totalFitScore + totalGapScore) / 8.0
        
        return """
        # EVALUATION RESULTS
        
        ## 1. YEARS OF EXPERIENCE
        \(yearsResult)
        
        ## 2. EDUCATION
        \(educationResult)
        
        ## 3. TECHNICAL SKILLS
        \(skillsResult)
        
        ## 4. RELEVANT EXPERIENCE
        \(experienceResult)
        
        ## FINAL SCORE
        **Total Fit Score:** \(String(format: "%.1f", totalFitScore)) / 12
        **Total Gap Score:** \(String(format: "%.1f", totalGapScore)) / 12
        **Final Score:** \(String(format: "%.1f", finalScore)) (0-3 scale)
        
        ## RECOMMENDATION
        \(getRecommendation(finalScore: finalScore))
        """
    }
    
    private func extractScoresFromResults(years: String, education: String, skills: String, experience: String) -> (fitScores: [Double], gapScores: [Double]) {
        let results = [years, education, skills, experience]
        var fitScores: [Double] = []
        var gapScores: [Double] = []
        
        for result in results {
            fitScores.append(extractScore(from: result, type: "Fit Score"))
            gapScores.append(extractScore(from: result, type: "Gap Score"))
        }
        
        return (fitScores, gapScores)
    }
    
    private func extractScore(from text: String, type: String) -> Double {
        let patterns = [
            "\\*\\*\(type):\\*\\*\\s*([0-9]+(?:\\.\\d+)?)",
            "\\*\\*\(type.lowercased()):\\*\\*\\s*([0-9]+(?:\\.\\d+)?)",
            "\(type):\\s*([0-9]+(?:\\.\\d+)?)",
            "\(type.lowercased()):\\s*([0-9]+(?:\\.\\d+)?)"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: text.utf16.count)
                
                if let match = regex.firstMatch(in: text, range: range) {
                    let scoreRange = match.range(at: 1)
                    if let range = Range(scoreRange, in: text) {
                        let scoreString = String(text[range])
                        if let score = Double(scoreString) {
                            return score
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        return 0.0
    }
    
    private func getRecommendation(finalScore: Double) -> String {
        switch finalScore {
        case 0.0..<1.0:
            return "❌ Poor Match - Candidate does not meet minimum requirements"
        case 1.0..<2.0:
            return "⚠️ Weak Match - Candidate has some gaps but may be considered"
        case 2.0..<2.5:
            return "✅ Good Match - Candidate meets most requirements"
        case 2.5...3.0:
            return "🎯 Excellent Match - Candidate is highly qualified"
        default:
            return "❓ Unknown - Score out of expected range"
        }
    }
}

extension LocalAnalysisViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        updateAnalyzeButtonState()
    }
}
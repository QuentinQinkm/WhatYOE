/*
SwiftUI Desktop Interface for WhatYOE
Provides resume management and analysis functionality
*/

import SwiftUI

struct ContentView: View {
    // MARK: - Constants
    private let leftListOpacity: Double = 0.65
    private let rightSectionOpacity: Double = 0.8
    private let rightSectionPadding: CGFloat = 20
    private let buttonBackgroundColor = Color(red: 235/255, green: 235/255, blue: 235/255)
    
    // MARK: - ViewModel
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        ZStack {
            // Popover blurred background for entire window
            VisualEffectView()
                .ignoresSafeArea(.all)
            
            // Content with specific opacity backgrounds
            HStack(spacing: 0) {
                // Left Panel - Conditional list based on selected tab
                Group {
                    if viewModel.selectedTab == 0 {
                        JobListView(
                            jobs: viewModel.jobs,
                            selectedJob: $viewModel.selectedJob,
                            onDelete: viewModel.deleteJob
                        )
                    } else {
                        ResumeListView(
                            resumes: viewModel.resumes,
                            selectedResume: $viewModel.selectedResume,
                            onImport: viewModel.importResume,
                            onDelete: viewModel.deleteResume,
                            onRename: viewModel.startRename
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
                        CustomTabPicker(selectedTab: $viewModel.selectedTab)
                            .padding(.leading, rightSectionPadding)
                        
                        Spacer()
                        
                        Text(viewModel.getLabelText())
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
                    
                    Group {
                        if viewModel.selectedTab == 0 {
                            JobDetailView(
                                job: viewModel.selectedJob,
                                horizontalPadding: rightSectionPadding,
                                jobs: viewModel.jobs
                            )
                        } else if viewModel.selectedTab == 1 {
                            if let pendingData = viewModel.pendingResumeData {
                                PendingResumeView(
                                    pendingData: pendingData,
                                    onProceed: viewModel.proceedWithLLM,
                                    onSave: viewModel.saveProcessedResume,
                                    onCancel: viewModel.cancelImport,
                                    horizontalPadding: rightSectionPadding,
                                    buttonBackgroundColor: buttonBackgroundColor
                                )
                            } else {
                                ResumeDetailView(
                                    resume: viewModel.selectedResume,
                                    horizontalPadding: rightSectionPadding,
                                    resumes: viewModel.resumes
                                )
                            }
                        } else {
                            AnalysisView(selectedResume: viewModel.selectedResume)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 16)
                }
                .background(Color.white.opacity(rightSectionOpacity)) // Right control panel: white 0.8 opacity
            }
        }
        .sheet(item: $viewModel.renamingResume) { resume in
            RenameDialog(
                currentName: resume.name,
                renameText: $viewModel.renameText,
                onSave: viewModel.saveRename,
                onCancel: viewModel.cancelRename
            )
        }
    }
    
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}

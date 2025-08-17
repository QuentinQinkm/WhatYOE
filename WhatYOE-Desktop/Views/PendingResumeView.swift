import SwiftUI

struct PendingResumeData {
    let fileName: String
    let rawText: String
    let url: URL
    var cleanedText: String?
    var isProcessing: Bool = false
}

struct PendingResumeView: View {
    let pendingData: PendingResumeData
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
                        HStack {
                            Spacer()
                            
                            GlassIconButton(
                                icon: "pencil",
                                color: .black,
                                state: pendingData.isProcessing ? .disabled : .default,
                                action: {
                                    print("Edit tapped")
                                }
                            )
                        }
                        .padding(.bottom, 16)
                        
                        HStack {
                            GlassButton(
                                title: "Cancel",
                                color: Color(red: 110/255, green: 0/255, blue: 0/255),
                                state: pendingData.isProcessing ? .disabled : .default,
                                action: onCancel
                            )
                            
                            Spacer()
                            
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
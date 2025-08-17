import SwiftUI

struct AnalysisView: View {
    let selectedResume: ResumeItem?
    @State private var jobDescription = ""
    @State private var analysisMethod = AnalysisMethod.fourRun
    @State private var isAnalyzing = false
    @State private var analysisResult = ""
    @State private var statusMessage = ""
    
    var body: some View {
        VStack(spacing: 16) {
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
            
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundColor(statusMessage.contains("Error") ? .red : .black.opacity(0.6))
                    .padding(.horizontal)
            }
            
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
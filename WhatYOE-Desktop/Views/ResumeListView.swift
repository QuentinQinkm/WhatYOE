import SwiftUI

struct ResumeListView: View {
    let resumes: [ResumeItem]
    @Binding var selectedResume: ResumeItem?
    let onImport: () -> Void
    let onDelete: (ResumeItem) -> Void
    let onRename: (ResumeItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
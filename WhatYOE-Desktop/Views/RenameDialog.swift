import SwiftUI

struct RenameDialog: View {
    let currentName: String
    @Binding var renameText: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            VisualEffectView()
                .cornerRadius(12)
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rename Resume")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    TextField("Resume name", text: $renameText)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .onAppear {
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
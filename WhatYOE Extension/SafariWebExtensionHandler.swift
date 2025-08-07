/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Communicates with the extension running in Safari.
*/
import SafariServices
import os.log
import FoundationModels

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    
    // System language model for analysis
    private let model = SystemLanguageModel.default

    // Receive a message from the JavaScript component of the Web Extension.
    // Unpack the message, and then wrap in an object to send as the response.
	func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems[0] as? NSExtensionItem
        let message = item?.userInfo?[SFExtensionMessageKey]
        
        // Log that the NATIVE APP handler is being called
        os_log(.default, "🔥 NATIVE APP HANDLER CALLED - SafariWebExtensionHandler.beginRequest()")
        os_log(.default, "📨 Raw message received: %@", String(describing: message))
        
        // Check for page analysis messages
        if let messageDict = message as? [String: Any],
           let messageContent = messageDict["message"] as? String {
            if messageContent == "pageAnalysis" {
                if let data = messageDict["data"] as? [String: Any] {
                    let characterCount = data["characterCount"] as? Int ?? 0
                    let wordCount = data["wordCount"] as? Int ?? 0
                    let title = data["title"] as? String ?? "Unknown"
                    let pageText = data["pageText"] as? String ?? ""
                    
                    os_log(.default, "📊 NATIVE APP: PAGE ANALYSIS RECEIVED!")
                    os_log(.default, "📊 NATIVE APP: Character count: %d", characterCount)
                    os_log(.default, "📝 NATIVE APP: Word count: %d", wordCount)
                    os_log(.default, "📄 NATIVE APP: Page title: %@", title)
                    
                    // Analyze with Foundation Model
                    analyzeJobDescription(pageText: pageText, context: context)
                    return // Don't send immediate response, wait for AI analysis
                }
            }
        }

        os_log(.default, "📤 NATIVE APP: Sending response back to extension")
        let response = NSExtensionItem()
        response.userInfo = [ SFExtensionMessageKey: [ "Response to": message ] ]
        
        context.completeRequest(returningItems: [response], completionHandler: nil)
        os_log(.default, "✅ NATIVE APP: Response sent successfully")
    }
    
    // MARK: - Foundation Model Analysis
    private func analyzeJobDescription(pageText: String, context: NSExtensionContext) {
        // Check if models are available
        guard case .available = model.availability else {
            os_log(.default, "⚠️ NATIVE APP: Foundation Models not available, sending basic response")
            sendResponse(aiResponse: "Foundation Models unavailable", context: context)
            return
        }
        
        Task {
            do {
                os_log(.default, "🤖 NATIVE APP: Starting AI analysis...")
                
                // Create session with instructions
                let session = LanguageModelSession(instructions: """
                    How many years of experience is required in this job description? 
                    If the requirement is not specified, respond with "unspecified".
                    """
                )
                
                // Create prompt with specific question and format instruction
                let prompt = """
                What's the least required years of experience? Answer in format 'X years' only. If the requirement is not specified, respond with "unspecified".
                
                Job Description:
                \(pageText)
                """
                
                // Send prompt for analysis
                let response = try await session.respond(to: prompt)
                
                await MainActor.run {
                    // Extract just the content from the response
                    let aiAnswer = response.content
                    os_log(.default, "✅ NATIVE APP: AI Response: %@", aiAnswer)
                    self.sendResponse(aiResponse: aiAnswer, context: context)
                }
                
            } catch {
                await MainActor.run {
                    os_log(.error, "❌ NATIVE APP: AI analysis failed: %@", error.localizedDescription)
                    self.sendResponse(aiResponse: "AI analysis failed: \(error.localizedDescription)", context: context)
                }
            }
        }
    }
    
    private func sendResponse(aiResponse: String, context: NSExtensionContext) {
        let response = NSExtensionItem()
        response.userInfo = [ SFExtensionMessageKey: [ 
            "aiAnalysis": aiResponse,
            "status": "success"
        ]]
        
        context.completeRequest(returningItems: [response], completionHandler: nil)
        os_log(.default, "✅ NATIVE APP: AI analysis response sent to extension")
    }
    
}

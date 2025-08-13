/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Script that makes up the extension's background page.
*/

// Listen for messages from popup script and content script
browser.runtime.onMessage.addListener(function(message, sender, sendResponse) {
    if (message.action === "sendPageData") {
        const characterCount = message.data.characterCount || 0;
        const wordCount = message.data.wordCount || 0;
        
        console.log("📊 [BACKGROUND] Character count from content script:", characterCount);
        console.log("📝 [BACKGROUND] Word count from content script:", wordCount);
        console.log("📄 [BACKGROUND] Page title:", message.data.title);
        
        // Forward page data to native app for AI analysis
        browser.runtime.sendNativeMessage("application.id", {
            message: "pageAnalysis",
            data: message.data
        }, function(response) {
            console.log("📨 [BACKGROUND] Received AI response from native app:");
            console.log(response);
            
            // Extract AI analysis from response
            const aiAnalysis = response?.aiAnalysis || "No AI response received";
            console.log("🤖 [BACKGROUND] AI Analysis:", aiAnalysis);
            
            // The AI response should already be a processed score (0.0-3.0)
            // from the 4-round evaluation in SafariWebExtensionHandler
            let formattedResult = aiAnalysis;
            
            console.log("✨ [BACKGROUND] Final result for extension:", formattedResult);
            
            // Send back to content script with formatted response
            sendResponse({
                success: true,
                aiAnalysis: formattedResult,
                rawAiResponse: aiAnalysis,
                characterCount: characterCount,
                wordCount: wordCount,
                originalResponse: response
            });
        });
        return true; // Keep message channel open for async response
    }
});
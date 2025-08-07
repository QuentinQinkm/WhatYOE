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
            
            // Check for unspecified responses first, then extract numbers
            let formattedResult;
            if (aiAnalysis.toLowerCase().includes('unspecified') || 
                aiAnalysis.toLowerCase().includes('no specified') ||
                aiAnalysis.toLowerCase().includes('not specified')) {
                formattedResult = "Unspecified";
                console.log("📝 [BACKGROUND] Detected unspecified experience");
            } else {
                // Extract number using regex and format as "X Year"
                const numberMatch = aiAnalysis.match(/\d+/);
                const extractedNumber = numberMatch ? numberMatch[0] : "0";
                formattedResult = `${extractedNumber} Year`;
                console.log("🔢 [BACKGROUND] Extracted number:", extractedNumber);
            }
            
            console.log("✨ [BACKGROUND] Formatted result:", formattedResult);
            
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


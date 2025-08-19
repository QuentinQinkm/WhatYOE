/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Script that makes up the extension's background page.
*/

// Listen for messages from popup script and content script
browser.runtime.onMessage.addListener(function(message, sender, sendResponse) {
    if (message.action === "startFourCycleAnalysis") {
        // Single request for 4-cycle analysis
        startFourCycleAnalysis(message.data, sendResponse);
        return true; // Keep message channel open
    }
    
    // Legacy handlers removed - now using unified fourCycleAnalysis
});

async function startFourCycleAnalysis(data, sendResponse) {
    try {
        // Extract JobID from URL or title for tracking
        const jobId = extractJobId(data);
        console.log("🚀 [BACKGROUND] Starting Single Request 4-Cycle Analysis for Job:", jobId);
        console.log("📋 [BACKGROUND] Job Details - Title:", data.jobTitle || "Unknown", "Company:", data.company || "Unknown");
        
        // Store job metadata in UserDefaults for the native app to access
        if (data.jobTitle && data.company) {
            try {
                await browser.runtime.sendNativeMessage("com.kuangming.WhatYOE", {
                    message: "storeJobMetadata",
                    data: {
                        jobTitle: data.jobTitle,
                        company: data.company,
                        linkedinJobId: data.linkedinJobId, // Add LinkedIn job ID
                        pageUrl: data.url || "unknown"
                    }
                });
                console.log("💾 [BACKGROUND] Job metadata stored in UserDefaults");
            } catch (error) {
                console.warn("⚠️ [BACKGROUND] Failed to store job metadata:", error);
            }
        }
        
        const response = await browser.runtime.sendNativeMessage("com.kuangming.WhatYOE", {
            message: "fourCycleAnalysis",
            data: data
        });
        
        // Log final 0–100 score if available (fit/gap deprecated)
        if (response && response.scores) {
            const { finalScore } = response.scores;
            console.log("📊 [BACKGROUND] Final Score (0–100) for Job:", jobId, finalScore);
        } else {
            console.log("⚠️ [BACKGROUND] No scores found for Job:", jobId);
            console.log("🔍 [BACKGROUND] Response structure:", response);
            console.log("🔍 [BACKGROUND] Response keys:", response ? Object.keys(response) : "No response");
            console.log("ℹ️ [BACKGROUND] No fallback to old scores - waiting for fresh analysis results");
        }
        
        // Include scores in the response if available
        let responseWithScores = {
            success: true,
            result: response
        };
        
        // If we have scores, include them at the top level for content script access
        if (response && response.scores) {
            responseWithScores.scores = response.scores;
            responseWithScores.aiAnalysis = response.scores.finalScore.toString();
        }
        // Removed fallback to old scores - each job should get fresh results
        
        sendResponse(responseWithScores);
    } catch (error) {
        console.error("❌ [BACKGROUND] 4-Cycle Analysis failed for Job:", extractJobId(data), "Error:", error);
        sendResponse({
            success: false,
            error: error.message
        });
    }
}

// Helper function to extract Job ID from data
function extractJobId(data) {
    if (data.url) {
        // Try to extract job ID from LinkedIn URL
        const match = data.url.match(/jobs\/view\/(\d+)/);
        if (match) return match[1];
        
        // Try to extract from currentJobId parameter
        const urlParams = new URLSearchParams(new URL(data.url).search);
        const jobId = urlParams.get('currentJobId');
        if (jobId) return jobId;
    }
    
    // Fallback to timestamp or title
    return data.timestamp || data.title?.substring(0, 30) || "Unknown";
}

// Legacy phase functions removed - all analysis now handled by startFourCycleAnalysis
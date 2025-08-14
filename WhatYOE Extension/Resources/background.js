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
    
    // Keep legacy phase methods for backward compatibility if needed
    if (message.action === "startPhase1") {
        // Phase 1: YOE Analysis
        startPhase1(message.data, sendResponse);
        return true; // Keep message channel open
    }
    
    if (message.action === "startPhase2") {
        // Phase 2: Education Analysis
        startPhase2(message.data, sendResponse);
        return true;
    }
    
    if (message.action === "startPhase3") {
        // Phase 3: Skills Analysis
        startPhase3(message.data, sendResponse);
        return true;
    }
    
    if (message.action === "startPhase4") {
        // Phase 4: Experience Analysis
        startPhase4(message.data, sendResponse);
        return true;
    }
    
    // Legacy support for old sendPageData action
    if (message.action === "sendPageData") {
        startPhase1(message.data, sendResponse);
        return true;
    }
});

async function startFourCycleAnalysis(data, sendResponse) {
    try {
        // Extract JobID from URL or title for tracking
        const jobId = extractJobId(data);
        console.log("🚀 [BACKGROUND] Starting Single Request 4-Cycle Analysis for Job:", jobId);
        
        const response = await browser.runtime.sendNativeMessage("com.kuangming.WhatYOE", {
            message: "fourCycleAnalysis",
            data: data
        });
        
        // Log the 8 scores if available
        if (response && response.scores) {
            const { fitScores, gapScores, finalScore } = response.scores;
            console.log("📊 [BACKGROUND] Analysis Scores Breakdown for Job:", jobId);
            console.log("   📈 Fit Scores (YOE, Education, Skills, Experience):", fitScores);
            console.log("   📉 Gap Scores (YOE, Education, Skills, Experience):", gapScores);
            console.log("   🎯 Final Score:", finalScore);
            console.log("   🧮 Calculation: (Fit sum: " + (fitScores?.reduce((a,b) => a+b, 0) || 0) + 
                         " + Gap sum: " + (gapScores?.reduce((a,b) => a+b, 0) || 0) + ") / 8 = " + finalScore);
        } else {
            console.log("⚠️ [BACKGROUND] No scores found for Job:", jobId);
        }
        
        sendResponse({
            success: true,
            result: response
        });
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

async function startPhase1(data, sendResponse) {
    try {
        console.log("🚀 [BACKGROUND] Starting Phase 1: YOE Analysis");
        
        const response = await browser.runtime.sendNativeMessage("com.kuangming.WhatYOE", {
            message: "phase1Analysis",
            data: data
        });
        
        sendResponse({
            success: true,
            phase: "phase1",
            result: response
        });
    } catch (error) {
        console.error("❌ [BACKGROUND] Phase 1 failed:", error);
        sendResponse({
            success: false,
            phase: "phase1",
            error: error.message
        });
    }
}

async function startPhase2(data, sendResponse) {
    try {
        console.log("🚀 [BACKGROUND] Starting Phase 2: Education Analysis");
        
        const response = await browser.runtime.sendNativeMessage("com.kuangming.WhatYOE", {
            message: "phase2Analysis",
            data: data
        });
        
        sendResponse({
            success: true,
            phase: "phase2",
            result: response
        });
    } catch (error) {
        console.error("❌ [BACKGROUND] Phase 2 failed:", error);
        sendResponse({
            success: false,
            phase: "phase2",
            error: error.message
        });
    }
}

async function startPhase3(data, sendResponse) {
    try {
        console.log("🚀 [BACKGROUND] Starting Phase 3: Skills Analysis");
        
        const response = await browser.runtime.sendNativeMessage("com.kuangming.WhatYOE", {
            message: "phase3Analysis",
            data: data
        });
        
        sendResponse({
            success: true,
            phase: "phase3",
            result: response
        });
    } catch (error) {
        console.error("❌ [BACKGROUND] Phase 3 failed:", error);
        sendResponse({
            success: false,
            phase: "phase3",
            error: error.message
        });
    }
}

async function startPhase4(data, sendResponse) {
    try {
        console.log("🚀 [BACKGROUND] Starting Phase 4: Experience Analysis");
        
        const response = await browser.runtime.sendNativeMessage("com.kuangming.WhatYOE", {
            message: "phase4Analysis",
            data: data
        });
        
        sendResponse({
            success: true,
            phase: "phase4",
            result: response
        });
    } catch (error) {
        console.error("❌ [BACKGROUND] Phase 4 failed:", error);
        sendResponse({
            success: false,
            phase: "phase4",
            error: error.message
        });
    }
}
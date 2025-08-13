// YOE AI Analyzer - Content Script for LinkedIn Jobs
if (window.location.hostname.includes('linkedin.com') && window.top === window) {
    console.log('🚀 [YOE AI] Starting AI-powered job analyzer...');

    class YOEAIAnalyzer {
        constructor() {
            this.isAnalyzing = false;
            this.lastUrl = location.href;
            this.analysisResults = new Map();
            this.init();
        }

        async init() {
            console.log('🚀 [YOE AI] Initializing...');
            this.setupUrlObserver();
        }

        setupUrlObserver() {
            const observer = new MutationObserver(() => {
                if (location.href !== this.lastUrl) {
                    const oldUrl = new URL(this.lastUrl);
                    const newUrl = new URL(location.href);

                    const pageChanged = oldUrl.searchParams.get('start') !== newUrl.searchParams.get('start');
                    const filtersChanged = oldUrl.searchParams.get('keywords') !== newUrl.searchParams.get('keywords');
                    
                    this.lastUrl = location.href;

                    if (pageChanged || filtersChanged) {
                        console.log('🔄 [YOE AI] Page change detected.');
                    }
                }
            });
            observer.observe(document.body, { childList: true, subtree: true });
        }

        getJobCards() {
            return Array.from(document.querySelectorAll('.job-card-container, .jobs-search-results__list-item'));
        }
        
        getCardId(card) {
            const realJobId = card.getAttribute('data-job-id');
            if (realJobId) return realJobId;
            
            const link = card.querySelector('a[href*="/jobs/view/"]');
            const linkId = link?.href.match(/\/jobs\/view\/(\d+)/)?.[1];
            if (linkId) return linkId;
            
            console.warn('⚠️ [YOE AI] Could not find ID for card.', card);
            return null;
        }

        applyHighlight(card, result) {
            // Clear previous styles first
            card.style.position = ''; // Reset position
            card.querySelector('.yoe-ai-label')?.remove();

            // Determine color and text for the label based on AI score
            let text, color;
            if (typeof result.score === 'number') {
                if (result.score <= 1.0) {
                    text = `Reject: ${result.score}`;
                    color = '#dc3545'; // Red
                } else if (result.score <= 2.0) {
                    text = `Low: ${result.score}`;
                    color = '#fd7e14'; // Orange
                } else if (result.score <= 2.5) {
                    text = `Maybe: ${result.score}`;
                    color = '#ffc107'; // Yellow
                } else {
                    text = `High: ${result.score}`;
                    color = '#28a745'; // Green
                }
            } else {
                text = 'Unknown';
                color = '#6c757d'; // Gray
            }

            // Create and style the label (exactly like old working version)
            const label = document.createElement('div');
            label.className = 'yoe-ai-label';
            label.textContent = text;
            
            label.style.cssText = `
                position: absolute;
                bottom: 5px;
                right: 5px;
                background-color: ${color};
                color: white;
                padding: 3px 6px;
                font-size: 12px;
                font-weight: bold;
                z-index: 1000;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            `;

            // Add label to card without colored border (exactly like old version)
            card.style.position = 'relative';
            card.appendChild(label);
            
            console.log(`[YOE AI] Applied label "${text}" to card (no border).`);
        }
        
        // NEW: Apply progress labels during analysis
        applyProgressLabel(card, message, color = '#6c757d') {
            // Clear previous progress label
            card.querySelector('.yoe-progress-label')?.remove();
            
            // Create progress label
            const label = document.createElement('div');
            label.className = 'yoe-progress-label';
            label.textContent = message;
            
            label.style.cssText = `
                position: absolute;
                bottom: 5px;
                right: 5px;
                background-color: ${color};
                color: white;
                padding: 3px 6px;
                font-size: 12px;
                font-weight: bold;
                z-index: 1000;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            `;
            
            // Add label to card
            card.style.position = 'relative';
            card.appendChild(label);
            
            console.log(`[YOE AI] Applied progress label: "${message}"`);
        }
        
        // NEW: Set up progress monitoring for a job card
        setupProgressMonitoring(card) {
            // Poll for progress updates every 500ms
            const progressInterval = setInterval(() => {
                browser.runtime.sendMessage({
                    action: "getProgress"
                }, (response) => {
                    if (response && response.type === "progress_update") {
                        // Update the progress label based on stage
                        let progressText, color;
                        
                        switch(response.stage) {
                            case "parsing_jd":
                                progressText = "Parsing JD";
                                color = "#17a2b8"; // Blue
                                break;
                            case "round_1":
                                progressText = "Phase 1: YOE";
                                color = "#6f42c1"; // Purple
                                break;
                            case "round_2":
                                progressText = "Phase 2: Education";
                                color = "#fd7e14"; // Orange
                                break;
                            case "round_3":
                                progressText = "Phase 3: Skills";
                                color = "#e83e8c"; // Pink
                                break;
                            case "round_4":
                                progressText = "Phase 4: Experience";
                                color = "#20c997"; // Teal
                                break;
                            case "final_score":
                                progressText = "Final Score";
                                color = "#28a745"; // Green
                                break;
                            default:
                                progressText = response.message;
                                color = "#6c757d"; // Gray
                        }
                        
                        this.applyProgressLabel(card, progressText, color);
                    }
                });
            }, 500);
            
            // Store interval ID to clear later
            card.progressInterval = progressInterval;
        }

        cleanText(text) {
            return text
                .split('\n')
                .map(line => line.trim())
                .filter(line => line.length > 0)
                .join('\n');
        }

        async getVerifiedJobDescription(card) {
            const targetJobId = this.getCardId(card);
            if (!targetJobId) {
                console.error('❌ [YOE AI] Could not get target ID for card.');
                return card.innerText;
            }

            console.log(`🎯 [YOE AI] Getting description for Job ID: ${targetJobId}`);
            
            // Wait for job details to be visible
            const startTime = Date.now();
            const timeout = 15000;

            while (Date.now() - startTime < timeout) {
                // Look for job details in different possible locations
                const detailsWrapper = document.querySelector('.jobs-search__job-details-wrapper, .jobs-search__right-rail, .scaffold-layout__detail, .jobs-search__content');
                if (detailsWrapper) {
                    const descriptionEl = detailsWrapper.querySelector('.jobs-description__content, .jobs-box__html-content, .jobs-description, .jobs-box__html-content');
                    
                    if (descriptionEl && descriptionEl.innerText.length > 50) {
                        console.log(`✅ [YOE AI] Description for ${targetJobId} loaded (${descriptionEl.innerText.length} chars).`);
                        return this.cleanText(descriptionEl.innerText);
                    }
                }
                await new Promise(resolve => setTimeout(resolve, 200));
            }

            console.warn(`⚠️ [YOE AI] Timeout getting description for ${targetJobId}.`);
            return this.cleanText(card.innerText);
        }
        
        getDisplayedJobId(detailsWrapper) {
            const urlParams = new URLSearchParams(window.location.search);
            const urlJobId = urlParams.get('currentJobId');
            if (urlJobId) return urlJobId;

            const wrapperJobId = detailsWrapper.getAttribute('data-job-id');
            if (wrapperJobId) return wrapperJobId;

            const childWithJobId = detailsWrapper.querySelector('[data-job-id]');
            if (childWithJobId) return childWithJobId.getAttribute('data-job-id');
            
            return null;
        }


        async startAnalysis() {
            if (this.isAnalyzing) {
                console.log('⚠️ [YOE AI] Analysis already in progress');
                return { success: false, message: 'Analysis already in progress' };
            }
            
            this.isAnalyzing = true;
            console.log(`🚀 [YOE AI] Starting systematic job analysis`);
            
            // Clear any previous analysis results for fresh start
            this.analysisResults.clear();
            
            try {
                await this.analyzeAllJobsSequentially();
            } catch (error) {
                console.error('❌ [YOE AI] Analysis error:', error);
            }
            
            this.isAnalyzing = false;
            console.log(`✅ [YOE AI] Analysis complete: ${this.analysisResults.size} jobs analyzed`);
            return { success: true, message: `Analysis completed - ${this.analysisResults.size} jobs analyzed` };
        }
        
        async analyzeAllJobsSequentially() {
            console.log(`🚀 [YOE AI] Starting continuous analysis loop`);
            
            let processedInThisRun = new Set();
            let stableScrolls = 0;
            let maxStableScrolls = 3; // Stop after 3 scrolls with no new jobs

            // Continuous loop to scroll, find new cards, and process them
            while (stableScrolls < maxStableScrolls && this.isAnalyzing) {
                const cardsOnPage = this.getJobCards();
                const newCards = cardsOnPage.filter(card => {
                    const jobId = this.getCardId(card);
                    return jobId && !this.analysisResults.has(jobId) && !processedInThisRun.has(jobId);
                });

                if (newCards.length > 0) {
                    console.log(`📊 [YOE AI] Found ${newCards.length} new jobs to process.`);
                    stableScrolls = 0; // Reset stable count because we found new work to do

                    for (const card of newCards) {
                        if (!this.isAnalyzing) break; // Check if analysis was stopped
                        
                        const jobId = this.getCardId(card);
                        if (!jobId) continue;

                        processedInThisRun.add(jobId);
                        console.log(`🎯 [YOE AI] Processing job: ${jobId}`);
                        
                        try {
                            // Click the job card to open details
                            card.scrollIntoView({ behavior: 'smooth', block: 'center' });
                            await new Promise(resolve => setTimeout(resolve, 500));
                            
                            const jobLink = card.querySelector('a[href*="/jobs/view/"]');
                            if (jobLink) {
                                jobLink.click();
                                console.log(`🖱️ [YOE AI] Clicked job card for ${jobId}`);
                            }
                            
                            // Wait for job details to load
                            await new Promise(resolve => setTimeout(resolve, 2000));
                            
                            // Get job description and analyze
                            const description = await this.getVerifiedJobDescription(card);
                            console.log(`🔍 [YOE AI] Got description for ${jobId}, sending to AI...`);
                            
                            // Show "Analyzing..." status
                            this.applyProgressLabel(card, "Analyzing...", "#6c757d");
                            
                            // Set up progress monitoring
                            this.setupProgressMonitoring(card);
                            
                            // Send to AI for analysis
                            const response = await new Promise((resolve) => {
                                browser.runtime.sendMessage({
                                    action: "sendPageData",
                                    data: {
                                        pageText: description,
                                        characterCount: description.length,
                                        wordCount: description.trim().split(/\s+/).filter(word => word.length > 0).length,
                                        foundSelector: "job-description",
                                        title: document.title,
                                        url: window.location.href,
                                        timestamp: Date.now()
                                    }
                                }, resolve);
                            });

                                                    // Parse score from AI response
                        const aiAnalysis = response?.aiAnalysis || "0.0";
                        // The score is already processed, just convert to number
                        const score = parseFloat(aiAnalysis) || 0;
                        
                        console.log(`🤖 [YOE AI] AI returned: "${aiAnalysis}" → score: ${score}`);
                        
                        // Clean up progress monitoring
                        if (card.progressInterval) {
                            clearInterval(card.progressInterval);
                            delete card.progressInterval;
                        }
                        
                        // Apply label to job card
                        if (score >= 0 && score <= 3) {
                            const result = { score: score };
                            this.analysisResults.set(jobId, result);
                            this.applyHighlight(card, result);
                            console.log(`✅ [YOE AI] Job ${jobId} labeled with score: ${score}`);
                        }
                            
                            // Close job details and return to list view
                            const closeButton = document.querySelector('button[aria-label="Dismiss"], .jobs-search__dismiss, .artdeco-modal__dismiss, .artdeco-modal__dismiss-button');
                            if (closeButton) {
                                closeButton.click();
                                console.log(`❌ [YOE AI] Closed job details for ${jobId}`);
                                await new Promise(resolve => setTimeout(resolve, 1500));
                            } else {
                                console.log(`⚠️ [YOE AI] No close button found for ${jobId}, trying alternative close method`);
                                // Try pressing Escape key as fallback
                                document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
                                await new Promise(resolve => setTimeout(resolve, 1000));
                            }
                            
                            // Wait before next job
                            await new Promise(resolve => setTimeout(resolve, 1500));
                            
                        } catch (error) {
                            console.error(`❌ [YOE AI] Error analyzing job ${jobId}:`, error);
                            
                            // Try to close job details if there was an error
                            const closeButton = document.querySelector('button[aria-label="Dismiss"], .jobs-search__dismiss, .artdeco-modal__dismiss, .artdeco-modal__dismiss-button');
                            if (closeButton) {
                                closeButton.click();
                                await new Promise(resolve => setTimeout(resolve, 1000));
                            } else {
                                // Try pressing Escape key as fallback
                                document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
                                await new Promise(resolve => setTimeout(resolve, 1000));
                            }
                        }
                    }
                } else {
                    console.log(`📄 [YOE AI] No new cards found on this scroll pass. Stable scrolls: ${stableScrolls + 1}/${maxStableScrolls}`);
                    stableScrolls++;
                }
                
                // Scroll down to check for more jobs
                if (this.isAnalyzing) {
                    console.log(`📜 [YOE AI] Scrolling down to find more jobs...`);
                    window.scrollTo(0, document.body.scrollHeight);
                    await new Promise(resolve => setTimeout(resolve, 1000)); // Wait for scroll to complete
                }
            }
            
            console.log(`✅ [YOE AI] Analysis loop complete. Total jobs analyzed: ${this.analysisResults.size}`);
        }
        
        // Removed pagination methods - using continuous scrolling instead
        
        stopAnalysis() {
            console.log('🛑 [YOE AI] Stopping analysis...');
            this.isAnalyzing = false;
            return { success: true, message: 'Analysis stopped' };
        }
        
        getStats() {
            let stats = { 
                totalJobs: 0, 
                reject: 0,
                low: 0,
                maybe: 0,
                high: 0,
                isAnalyzing: this.isAnalyzing 
            };
            
            this.analysisResults.forEach(result => {
                stats.totalJobs++;
                
                // Only process valid numerical scores
                if (typeof result.score === 'number') {
                    if (result.score <= 1.0) {
                        stats.reject++;
                    } else if (result.score <= 2.0) {
                        stats.low++;
                    } else if (result.score <= 2.5) {
                        stats.maybe++;
                    } else {
                        stats.high++;
                    }
                }
            });
            
            return stats;
        }
        
        checkForJobDescription() {
            // Check if we're on a job details page with a proper job description
            const detailsWrapper = document.querySelector('.jobs-search__job-details-wrapper, .jobs-search__right-rail, .scaffold-layout__detail');
            if (detailsWrapper) {
                const descriptionEl = detailsWrapper.querySelector('.jobs-description__content, .jobs-box__html-content');
                if (descriptionEl && descriptionEl.innerText.trim().length > 50) {
                    return true;
                }
            }
            return false;
        }
    }

    window.yoeAI = new YOEAIAnalyzer();

    browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
        if (message.action === 'ping') {
            sendResponse({ success: true, message: 'YOE AI Analyzer loaded' });
            return true;
        }
        
        if (message.action === 'startAnalysis') {
            window.yoeAI.startAnalysis().then(result => {
                sendResponse(result);
            });
            return true;
        }
        
        if (message.action === 'stopAnalysis') {
            const result = window.yoeAI.stopAnalysis();
            sendResponse(result);
            return true;
        }
        
        if (message.action === 'getStats') {
            sendResponse(window.yoeAI.getStats());
            return true;
        }
        
        if (message.action === 'checkJobDescription') {
            const hasJobDesc = window.yoeAI.checkForJobDescription();
            sendResponse({ hasJobDescription: hasJobDesc });
            return true;
        }
        
        sendResponse({ success: false, message: 'Unknown action' });
        return true;
    });
}

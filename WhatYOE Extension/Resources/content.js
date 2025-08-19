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
            // Clear previous styles and all labels first
            card.style.position = ''; // Reset position
            card.querySelector('.yoe-ai-label')?.remove();
            card.querySelector('.yoe-progress-label')?.remove(); // Clear progress label too

            // Determine color and text for the label based on AI score with updated rating scale
            let text, color;
            if (typeof result.score === 'number') {
                if (result.score >= 0 && result.score < 1.3) {
                    text = `Reject: ${result.score.toFixed(1)}`;
                    color = '#dc3545'; // Red
                } else if (result.score >= 1.3 && result.score < 2.0) {
                    text = `Poor: ${result.score.toFixed(1)}`;
                    color = '#fd7e14'; // Orange
                } else if (result.score >= 2.0 && result.score < 2.7) {
                    text = `Maybe: ${result.score.toFixed(1)}`;
                    color = '#ffc107'; // Yellow
                } else if (result.score >= 2.7) {
                    text = `Good: ${result.score.toFixed(1)}`;
                    color = '#28a745'; // Green
                } else {
                    text = 'Unknown';
                    color = '#6c757d'; // Gray
                }
            } else {
                text = 'Unknown';
                color = '#6c757d'; // Gray
            }

            // Create and style the label
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

            // Add label to card
            card.style.position = 'relative';
            card.appendChild(label);
            
            console.log(`[YOE AI] Applied final label "${text}" to card.`);
        }
        
        // Simple progress label for phases
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
        }

        cleanText(text) {
            return text
                .split('\n')
                .map(line => line.trim())
                .filter(line => line.length > 0)
                .join('\n');
        }

        extractJobTitle() {
            // Try multiple selectors for job title
            const selectors = [
                '.job-details-jobs-unified-top-card__job-title h1 a',
                '.job-details-jobs-unified-top-card__job-title h1',
                '.t-24.job-details-jobs-unified-top-card__job-title h1 a',
                '.t-24.job-details-jobs-unified-top-card__job-title h1',
                'h1.t-24.t-bold.inline a',
                'h1.t-24.t-bold.inline'
            ];
            
            for (const selector of selectors) {
                const element = document.querySelector(selector);
                if (element && element.textContent.trim()) {
                    console.log(`✅ Found job title with selector: ${selector}`);
                    return element.textContent.trim();
                }
            }
            
            console.warn('⚠️ Could not extract job title, using fallback');
            return 'Unknown Position';
        }

        extractCompany() {
            // Try multiple selectors for company name
            const selectors = [
                '.job-details-jobs-unified-top-card__company-name a',
                '.job-details-jobs-unified-top-card__company-name',
                '[class*="job-details-jobs-unified-top-card__company-name"] a',
                '[class*="job-details-jobs-unified-top-card__company-name"]'
            ];
            
            for (const selector of selectors) {
                const element = document.querySelector(selector);
                if (element && element.textContent.trim()) {
                    console.log(`✅ Found company with selector: ${selector}`);
                    return element.textContent.trim();
                }
            }
            
            console.warn('⚠️ Could not extract company, using fallback');
            return 'Unknown Company';
        }
        
        async runSingleRequestAnalysis(description, card) {
            try {
                // Show analyzing status
                this.applyProgressLabel(card, "Analyzing...", "#6c757d");
                
                // Extract job metadata from LinkedIn page
                const jobTitle = this.extractJobTitle();
                const company = this.extractCompany();
                const linkedinJobId = this.getCardId(card); // Extract LinkedIn job ID
                
                console.log(`📋 [YOE AI] Extracted - Title: "${jobTitle}", Company: "${company}", Job ID: "${linkedinJobId}"`);
                
                // Single request for 4-cycle analysis
                const analysisResult = await browser.runtime.sendMessage({
                    action: "startFourCycleAnalysis",
                    data: {
                        pageText: description,
                        characterCount: description.length,
                        wordCount: description.trim().split(/\s+/).filter(word => word.length > 0).length,
                        title: document.title,
                        url: window.location.href,
                        jobTitle: jobTitle,
                        company: company,
                        linkedinJobId: linkedinJobId, // Add LinkedIn job ID
                        timestamp: Date.now()
                    }
                });
                
                // Don't show "Analysis Complete" - let the final score label replace the progress label
                
                // Return result with scores if available
                const result = {
                    success: true,
                    aiAnalysis: analysisResult?.result?.aiAnalysis || "0.0",
                    analysisResult: analysisResult
                };
                
                // Include scores if they're available in the response
                if (analysisResult?.scores) {
                    result.scores = analysisResult.scores;
                    console.log(`📊 [YOE AI] Scores included in response:`, analysisResult.scores);
                }
                
                return result;
                
            } catch (error) {
                console.error('❌ Single request analysis failed:', error);
                this.applyProgressLabel(card, "Analysis Failed", "#dc3545");
                return {
                    success: false,
                    aiAnalysis: "0.0",
                    error: error.message
                };
            }
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
            console.log(`🚀 [YOE AI] Starting continuous analysis loop with pagination`);
            
            let processedInThisRun = new Set();
            let currentPageProcessed = false;

            // Main pagination loop - continue until no more pages
            while (this.isAnalyzing) {
                currentPageProcessed = await this.analyzeCurrentPage(processedInThisRun);
                
                if (!currentPageProcessed) {
                    // Try to go to next page
                    const nextPageClicked = await this.tryClickNextPage();
                    
                    if (!nextPageClicked) {
                        console.log(`✅ [YOE AI] No more pages available. Analysis complete.`);
                        break;
                    }
                    
                    // Wait for new page to load
                    await new Promise(resolve => setTimeout(resolve, 2000));
                    console.log(`📄 [YOE AI] Moved to next page, continuing analysis...`);
                } else {
                    // Page had jobs to process, continue with current page
                    continue;
                }
            }
            
            console.log(`✅ [YOE AI] Analysis loop complete. Total jobs analyzed: ${this.analysisResults.size}`);
        }

        async analyzeCurrentPage(processedInThisRun) {
            let stableScrolls = 0;
            let maxStableScrolls = 3; // Stop after 3 scrolls with no new jobs
            let foundJobsOnPage = false;

            // Scroll and process jobs on current page
            while (stableScrolls < maxStableScrolls && this.isAnalyzing) {
                const cardsOnPage = this.getJobCards();
                
                // Filter out cards that have already been processed in this session
                const newCards = cardsOnPage.filter(card => {
                    const jobId = this.getCardId(card);
                    return jobId && !this.analysisResults.has(jobId) && !processedInThisRun.has(jobId);
                });

                if (newCards.length > 0) {
                    console.log(`📊 [YOE AI] Found ${newCards.length} new jobs to process on current page.`);
                    stableScrolls = 0; // Reset stable count because we found new work to do
                    foundJobsOnPage = true;

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
                            
                            // Single request 4-cycle analysis
                            const response = await this.runSingleRequestAnalysis(description, card);
                            
                            // Debug: Log the full response structure
                            console.log(`🔍 [YOE AI] Full response from background:`, response);
                            console.log(`🔍 [YOE AI] Response keys:`, response ? Object.keys(response) : "No response");
                            if (response?.scores) {
                                console.log(`🔍 [YOE AI] Scores object:`, response.scores);
                            }

                        // Parse score from AI response (now comes pre-calculated from background service)
                        let score = 0;
                        
                        // First try to get score from the scores object in the response
                        if (response?.scores?.finalScore !== undefined) {
                            score = response.scores.finalScore;
                            console.log(`🤖 [YOE AI] Got score from response.scores.finalScore: ${score}`);
                        } else if (response?.aiAnalysis) {
                            // Fallback to the old method
                            const aiAnalysis = response.aiAnalysis;
                            score = parseFloat(aiAnalysis) || 0;
                            console.log(`🤖 [YOE AI] Got score from response.aiAnalysis: "${aiAnalysis}" → ${score}`);
                        } else {
                            console.log(`⚠️ [YOE AI] No score found in response:`, response);
                        }
                        
                        console.log(`🤖 [YOE AI] Final score: ${score}`);
                        
                        // Apply label to job card (now using decimal scores)
                        if (score >= 0) {
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
                
                // Scroll down to check for more jobs on current page
                if (this.isAnalyzing && stableScrolls < maxStableScrolls) {
                    console.log(`📜 [YOE AI] Scrolling down to find more jobs on current page...`);
                    window.scrollTo(0, document.body.scrollHeight);
                    await new Promise(resolve => setTimeout(resolve, 1000)); // Wait for scroll to complete
                }
            }
            
            console.log(`📄 [YOE AI] Current page analysis complete. Found jobs: ${foundJobsOnPage}`);
            return foundJobsOnPage;
        }

        async tryClickNextPage() {
            console.log(`🔍 [YOE AI] Looking for next page button...`);
            
            // Common selectors for LinkedIn next page buttons
            const nextPageSelectors = [
                'button[aria-label="Next"]',
                'button[aria-label="View next results"]', 
                '.artdeco-pagination__button--next:not([disabled])',
                '.artdeco-pagination__button--next:not(.artdeco-pagination__button--disabled)',
                'button.artdeco-pagination__button--next',
                '[data-test-pagination-page-btn="next"]:not([disabled])',
                '.jobs-search-pagination__button--next:not([disabled])',
                'a[aria-label="Next"]',
                'button:contains("Next")',
                '.pv1 button[aria-label*="next" i]'
            ];
            
            for (const selector of nextPageSelectors) {
                const nextButton = document.querySelector(selector);
                
                if (nextButton && !nextButton.disabled && !nextButton.classList.contains('disabled')) {
                    // Check if button is visible and clickable
                    const rect = nextButton.getBoundingClientRect();
                    const isVisible = rect.width > 0 && rect.height > 0;
                    
                    if (isVisible) {
                        console.log(`🖱️ [YOE AI] Found clickable next page button with selector: ${selector}`);
                        
                        // Scroll to button and click
                        nextButton.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        await new Promise(resolve => setTimeout(resolve, 500));
                        
                        nextButton.click();
                        console.log(`✅ [YOE AI] Clicked next page button successfully`);
                        return true;
                    }
                }
            }
            
            // Fallback: Try to find numbered pagination buttons
            const paginationNumbers = document.querySelectorAll('.artdeco-pagination__pages button, .jobs-search-pagination button');
            
            for (const button of paginationNumbers) {
                if (button.getAttribute('aria-current') === 'true' || button.classList.contains('selected')) {
                    // Found current page, look for next number
                    const nextSibling = button.nextElementSibling;
                    if (nextSibling && nextSibling.tagName === 'BUTTON' && !nextSibling.disabled) {
                        console.log(`🖱️ [YOE AI] Found next page number button`);
                        
                        nextSibling.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        await new Promise(resolve => setTimeout(resolve, 500));
                        
                        nextSibling.click();
                        console.log(`✅ [YOE AI] Clicked next page number successfully`);
                        return true;
                    }
                    break;
                }
            }
            
            console.log(`❌ [YOE AI] No clickable next page button found`);
            return false;
        }
        
        // Auto-pagination: analyzes current page completely, then moves to next page automatically
        
        stopAnalysis() {
            console.log('🛑 [YOE AI] Stopping analysis...');
            this.isAnalyzing = false;
            return { success: true, message: 'Analysis stopped' };
        }
        
        getStats() {
            let stats = { 
                totalJobs: 0, 
                reject: 0,
                poor: 0,
                maybe: 0,
                good: 0,
                isAnalyzing: this.isAnalyzing 
            };
            
            this.analysisResults.forEach(result => {
                stats.totalJobs++;
                
                // Only process valid numerical scores (0-3 scale)
                if (typeof result.score === 'number') {
                    if (result.score >= 0 && result.score < 1.3) {
                        stats.reject++;
                    } else if (result.score >= 1.3 && result.score < 2.0) {
                        stats.poor++;
                    } else if (result.score >= 2.0 && result.score < 2.7) {
                        stats.maybe++;
                    } else if (result.score >= 2.7) {
                        stats.good++;
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
            } else {
                // Try alternative selectors
                const alternativeSelectors = [
                    '.jobs-description__content',
                    '.jobs-box__html-content',
                    '.jobs-description',
                    '.jobs-box__html-content',
                    '[data-job-description]',
                    '.job-description'
                ];
                
                for (const selector of alternativeSelectors) {
                    const element = document.querySelector(selector);
                    if (element && element.innerText.trim().length > 50) {
                        return true;
                    }
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
            const stats = window.yoeAI.getStats();
            sendResponse(stats);
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

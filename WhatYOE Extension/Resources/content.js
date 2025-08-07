// YOE AI Analyzer - Content Script for LinkedIn Jobs
if (window.location.hostname.includes('linkedin.com') && window.top === window) {
    console.log('🚀 [YOE AI] Starting AI-powered job analyzer...');

    class YOEAIAnalyzer {
        constructor() {
            this.userYears = null;
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
            card.style.border = '';
            card.style.position = '';
            card.querySelector('.yoe-ai-label')?.remove();

            let text, color;
            if (result.years === 'unspecified') {
                text = 'Unspecified';
                color = '#ffc107'; // Yellow
            } else if (result.years === null) {
                text = '? Unspecified';
                color = '#ffc107'; // Yellow
            } else if (this.userYears !== null && result.years <= this.userYears) {
                text = `✓ ${result.years} Year${result.years !== 1 ? 's' : ''}`;
                color = '#28a745'; // Green
            } else {
                text = `✗ ${result.years} Year${result.years !== 1 ? 's' : ''}`;
                color = '#dc3545'; // Red
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

            // Add label to card without colored border
            card.style.position = 'relative';
            card.appendChild(label);
            
            console.log(`✨ [YOE AI] Applied label "${text}" to card (no border).`);
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
            
            card.scrollIntoView({ behavior: 'smooth', block: 'center' });
            await new Promise(resolve => setTimeout(resolve, 300));
            
            card.querySelector('a')?.click();

            const startTime = Date.now();
            const timeout = 12000;

            while (Date.now() - startTime < timeout) {
                const detailsWrapper = document.querySelector('.jobs-search__job-details-wrapper, .jobs-search__right-rail, .scaffold-layout__detail');
                if (detailsWrapper) {
                    const currentlyDisplayedJobId = this.getDisplayedJobId(detailsWrapper);
                    const descriptionEl = detailsWrapper.querySelector('.jobs-description__content, .jobs-box__html-content');
                    
                    if (currentlyDisplayedJobId === targetJobId && descriptionEl && descriptionEl.innerText.length > 50) {
                        console.log(`✅ [YOE AI] Verified description for ${targetJobId} loaded.`);
                        return this.cleanText(descriptionEl.innerText);
                    }
                }
                await new Promise(resolve => setTimeout(resolve, 300));
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

        async extractYearsWithAI(jobDescription) {
            try {
                console.log('🤖 [YOE AI] Sending to AI for analysis...');
                
                const response = await new Promise((resolve, reject) => {
                    browser.runtime.sendMessage({
                        action: "sendPageData",
                        data: {
                            pageText: jobDescription,
                            characterCount: jobDescription.length,
                            wordCount: jobDescription.trim().split(/\s+/).filter(word => word.length > 0).length,
                            foundSelector: "job-description",
                            title: document.title,
                            url: window.location.href,
                            timestamp: Date.now()
                        }
                    }, response => {
                        if (response) {
                            resolve(response);
                        } else {
                            reject(new Error('No response from background script'));
                        }
                    });
                });

                const aiAnalysis = response?.aiAnalysis || "0 Year";
                
                // Check if background script already formatted as "Unspecified"
                if (aiAnalysis === "Unspecified" || aiAnalysis.toLowerCase().includes('unspecified')) {
                    console.log(`🤖 [YOE AI] AI Analysis: "${aiAnalysis}" → unspecified`);
                    return 'unspecified';
                }
                
                const numberMatch = aiAnalysis.match(/\d+/);
                const years = numberMatch ? parseInt(numberMatch[0]) : null;
                
                console.log(`🤖 [YOE AI] AI Analysis: "${aiAnalysis}" → ${years} years`);
                return years;
                
            } catch (error) {
                console.error('❌ [YOE AI] AI analysis failed:', error);
                return null;
            }
        }

        async startAnalysis(userYears) {
            if (this.isAnalyzing) {
                console.log('⚠️ [YOE AI] Analysis already in progress');
                return { success: false, message: 'Analysis already in progress' };
            }
            
            this.isAnalyzing = true;
            this.userYears = userYears;
            console.log(`🚀 [YOE AI] Starting AI analysis with user years: ${userYears}`);
            this.analysisResults.clear();

            let processedInThisRun = new Set();
            let stableScrolls = 0;

            while (stableScrolls < 3 && this.isAnalyzing) {
                const cardsOnPage = this.getJobCards();
                const newCards = cardsOnPage.filter(card => {
                    const jobId = this.getCardId(card);
                    return jobId && !this.analysisResults.has(jobId) && !processedInThisRun.has(jobId);
                });

                if (newCards.length > 0) {
                    console.log(`📊 [YOE AI] Found ${newCards.length} new jobs to analyze.`);
                    stableScrolls = 0;

                    for (const card of newCards) {
                        if (!this.isAnalyzing) {
                            console.log('🛑 [YOE AI] Analysis stopped by user');
                            break;
                        }
                        
                        const jobId = this.getCardId(card);
                        if (!jobId) continue;

                        processedInThisRun.add(jobId);
                        try {
                            const description = await this.getVerifiedJobDescription(card);
                            const years = await this.extractYearsWithAI(description);
                            
                            const result = { years };
                            this.analysisResults.set(jobId, result);
                            this.applyHighlight(card, result);
                            
                            await new Promise(resolve => setTimeout(resolve, 2000));
                        } catch (error) {
                            console.error(`❌ [YOE AI] Error analyzing job ${jobId}:`, error);
                        }
                    }
                } else {
                    console.log('📄 [YOE AI] No new cards found, continuing scroll...');
                    stableScrolls++;
                }
                
                if (this.isAnalyzing) {
                    window.scrollTo(0, document.body.scrollHeight);
                    await new Promise(resolve => setTimeout(resolve, 1000));
                }
            }
            
            this.isAnalyzing = false;
            console.log(`✅ [YOE AI] Analysis complete: ${this.analysisResults.size} jobs analyzed`);
            return { success: true, message: 'Analysis completed' };
        }
        
        stopAnalysis() {
            console.log('🛑 [YOE AI] Stopping analysis...');
            this.isAnalyzing = false;
            return { success: true, message: 'Analysis stopped' };
        }
        
        getStats() {
            let stats = { 
                totalJobs: 0, 
                qualifyingJobs: 0, 
                tooHighJobs: 0, 
                unspecified: 0, 
                isAnalyzing: this.isAnalyzing 
            };
            
            this.analysisResults.forEach(result => {
                stats.totalJobs++;
                if (result.years === null || result.years === 'unspecified') {
                    stats.unspecified++;
                } else if (this.userYears !== null && result.years <= this.userYears) {
                    stats.qualifyingJobs++;
                } else {
                    stats.tooHighJobs++;
                }
            });
            
            return stats;
        }
    }

    window.yoeAI = new YOEAIAnalyzer();

    browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
        if (message.action === 'ping') {
            sendResponse({ success: true, message: 'YOE AI Analyzer loaded' });
            return true;
        }
        
        if (message.action === 'startAnalysis') {
            window.yoeAI.startAnalysis(message.userYears).then(result => {
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
        
        sendResponse({ success: false, message: 'Unknown action' });
        return true;
    });
}
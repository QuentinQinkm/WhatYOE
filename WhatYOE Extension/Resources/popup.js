/*
YOE AI Analyzer - Popup Interface
*/

document.addEventListener('DOMContentLoaded', async function() {
    const autoToggle = document.getElementById('autoToggle');
    const autoToggleLabel = document.getElementById('autoToggleLabel');
    const analyzeButton = document.getElementById('analyzeButton');
    const updateResumeLink = document.getElementById('updateResumeLink');
    const statusDiv = document.getElementById('statusMessage');
    const resumeSelect = document.getElementById('resumeSelect');
    const refreshResumesBtn = document.getElementById('refreshResumesBtn');
    
    let currentTab;
    let autoAnalysisEnabled = false;
    let isAnalyzing = false; // Track analysis state
    let availableResumes = [];
    let analysisStats = null;
    
    // Initialize
    await init();
    
    // Test native messaging connection
    async function testNativeMessaging() {
        try {
            const response = await browser.runtime.sendNativeMessage("com.kuangming.WhatYOE", {
                message: "ping"
            });
            console.log("✅ Native messaging test successful:", response);
            return true;
        } catch (error) {
            console.error("❌ Native messaging test failed:", error);
            showStatus('Native messaging not working - check installation', true);
            return false;
        }
    }
    
    async function init() {
        // Check if on LinkedIn
        try {
            const tabs = await browser.tabs.query({ active: true, currentWindow: true });
            currentTab = tabs[0];
            if (!currentTab.url.includes('linkedin.com/jobs')) {
                showStatus('Please navigate to LinkedIn Jobs page');
                return;
            }
        } catch (error) {
            showStatus('Error accessing tab');
            return;
        }
        
        // Test native messaging connection FIRST
        const nativeMessagingWorking = await testNativeMessaging();
        if (!nativeMessagingWorking) {
            showStatus('Native messaging not working - check installation');
            return;
        }
        
        // Load available resumes AFTER confirming native messaging works
        await loadAvailableResumes();
        
        // Check current analysis state from content script
        await checkAnalysisState();
        
        // Load saved settings (Safari compatible)
        try {
            const savedAutoAnalysis = localStorage.getItem('autoAnalysis');
            
            if (savedAutoAnalysis !== null) {
                autoAnalysisEnabled = savedAutoAnalysis === 'true';
                updateToggleState();
            }
        } catch (error) {
            console.log('Could not load settings');
        }
        
        updateStatusBasedOnState();
    }
    
    // Toggle switch functionality
    autoToggle.addEventListener('click', async function() {
        autoAnalysisEnabled = !autoAnalysisEnabled;
        updateToggleState();
        
        // Save setting (Safari compatible)
        localStorage.setItem('autoAnalysis', autoAnalysisEnabled.toString());
        
        if (autoAnalysisEnabled) {
            showStatus('Auto-analysis enabled');
            startAnalysis();
        } else {
            showStatus('Auto-analysis disabled');
        }
    });
    
    function updateToggleState() {
        if (autoAnalysisEnabled) {
            autoToggle.classList.add('active');
            autoToggleLabel.textContent = 'Auto-Analysis';
        } else {
            autoToggle.classList.remove('active');
            autoToggleLabel.textContent = 'Auto-Analysis';
        }
    }
    
    
    // Analyze button (now a div)
    analyzeButton.addEventListener('click', function() {
        if (isAnalyzing) {
            stopAnalysis();
        } else {
            startAnalysis();
        }
    });
    
    // Update Resume link
    updateResumeLink.addEventListener('click', function() {
        launchResumeUpdateApp();
    });
    
    // Resume selection
    if (resumeSelect) {
        resumeSelect.addEventListener('change', function() {
            setActiveResume(resumeSelect.value);
        });
    }
    
    // Refresh resumes button
    refreshResumesBtn.addEventListener('click', async function() {
        showStatus('Refreshing resume list...');
        await loadAvailableResumes();
    });
    
    async function startAnalysis() {
        // Check if there's a job description available
        try {
            const jobDescCheck = await browser.tabs.sendMessage(currentTab.id, {
                action: 'checkJobDescription'
            });
            
            if (!jobDescCheck || !jobDescCheck.hasJobDescription) {
                showStatus('No job description found. Please navigate to a job posting.', true);
                return;
            }
        } catch (error) {
            showStatus('Cannot detect job description. Please refresh the page.', true);
            return;
        }
        
        isAnalyzing = true;
        analyzeButton.textContent = 'Stop Analysis';
        analyzeButton.style.pointerEvents = 'auto';
        showStatus('Starting AI analysis...');
        
        try {
            // Ensure content script is loaded
            await ensureContentScript();
            
            // Send analysis command to content script
            const response = await browser.tabs.sendMessage(currentTab.id, {
                action: 'startAnalysis',
                autoMode: autoAnalysisEnabled
            });
            
            if (response && response.success) {
                showStatus('✓ Analysis started successfully');
            } else {
                showStatus('Failed to start analysis, try to refresh the page', true);
                isAnalyzing = false;
                analyzeButton.textContent = 'Analyze Resume-Job Match';
            }
        } catch (error) {
            console.error('Analysis error:', error);
            showStatus('Error - Please refresh the page', true);
            isAnalyzing = false;
            analyzeButton.textContent = 'Analyze Resume-Job Match';
        }
    }
    
    async function stopAnalysis() {
        isAnalyzing = false;
        analyzeButton.textContent = 'Analyze Resume-Job Match';
        showStatus('Analysis stopped');
        
        try {
            // Send stop command to content script
            await browser.tabs.sendMessage(currentTab.id, {
                action: 'stopAnalysis'
            });
        } catch (error) {
            console.log('Could not send stop command to content script');
        }
    }
    
    // Test content script availability (Safari uses manifest-declared content scripts)
    async function ensureContentScript() {
        try {
            const response = await browser.tabs.sendMessage(currentTab.id, { action: 'ping' });
            if (response && response.success) return;
        } catch (error) {
            // Content script not loaded - in Safari, content scripts are declared in manifest
            console.log('Content script not available - ensure it is declared in manifest.json');
        }
        
        // Wait a moment for content script to potentially load
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        // Try ping again
        try {
            const retryResponse = await browser.tabs.sendMessage(currentTab.id, { action: 'ping' });
            if (retryResponse && retryResponse.success) return;
        } catch (retryError) {
            console.error('Content script still not available after wait:', retryError);
        }
    }
    
    async function launchResumeUpdateApp() {
        showStatus('Opening Resume Analyzer...');
        
        try {
            // Send message to native app handler to launch the standalone resume analyzer
            const response = await browser.runtime.sendNativeMessage("com.kuangming.WhatYOE", {
                message: "launchResumeApp",
                data: {
                    autoTrigger: true
                }
            });
            
            if (response && response.status === "success") {
                showStatus('✓ Resume Analyzer opened');
                // Close the popup after a short delay
                setTimeout(() => {
                    window.close();
                }, 1000);
            } else if (response && response.status === "error") {
                showStatus(`Failed to open app: ${response.message}`, true);
            } else {
                showStatus('Unknown response from native app', true);
            }
        } catch (error) {
            console.error('Resume app launch error:', error);
            showStatus('Error launching Resume Analyzer', true);
        }
    }
    
    async function loadAvailableResumes() {
        try {
            const response = await browser.runtime.sendNativeMessage("com.kuangming.WhatYOE", {
                message: "getAvailableResumes"
            });
            
            if (response && response.status === "success") {
                availableResumes = response.resumes || [];
                updateResumeSelect();
            } else {
                availableResumes = [];
                updateResumeSelect();
                showStatus('Failed to load resumes - check native app');
            }
        } catch (error) {
            console.error('Failed to load resumes:', error);
            availableResumes = [];
            updateResumeSelect();
            showStatus(`Error loading resumes: ${error.message}`);
        }
    }
    
    function updateResumeSelect() {
        if (!resumeSelect) return;
        
        // Clear existing options
        resumeSelect.innerHTML = '';
        
        if (availableResumes.length === 0) {
            resumeSelect.innerHTML = '<option value="">No resumes available</option>';
            resumeSelect.disabled = true;
        } else {
            resumeSelect.disabled = false;
            resumeSelect.innerHTML = '<option value="">Select a resume...</option>';
            
            availableResumes.forEach(resume => {
                const option = document.createElement('option');
                option.value = resume.id;
                option.textContent = resume.name;
                resumeSelect.appendChild(option);
            });
        }
    }
    
    async function setActiveResume(resumeId) {
        if (!resumeId) return;
        
        try {
            const response = await browser.runtime.sendNativeMessage("com.kuangming.WhatYOE", {
                message: "setActiveResume",
                data: {
                    resumeId: resumeId
                }
            });
            
            if (response && response.status === "success") {
                showStatus('✓ Resume selected successfully');
            } else {
                showStatus('Failed to select resume', true);
            }
        } catch (error) {
            console.error('Failed to set active resume:', error);
            showStatus('Error selecting resume', true);
        }
    }
    
    async function checkAnalysisState() {
        try {
            const stats = await browser.tabs.sendMessage(currentTab.id, {
                action: 'getStats'
            });
            
            if (stats) {
                analysisStats = stats;
                isAnalyzing = stats.isAnalyzing;
                updateButtonState();
            }
        } catch (error) {
            console.log('Could not get analysis state from content script');
        }
    }
    
    function updateButtonState() {
        if (isAnalyzing) {
            analyzeButton.textContent = 'Stop Analysis';
        } else {
            analyzeButton.textContent = 'Analyze Resume-Job Match';
        }
    }
    
    function updateStatusBasedOnState() {
        if (availableResumes.length === 0) {
            showStatus('No resumes available - click Import to add resumes');
        } else if (isAnalyzing) {
            showStatus(`Analyzing... ${analysisStats?.totalJobs || 0} jobs processed`);
        } else if (analysisStats && analysisStats.totalJobs > 0) {
            showStatus(`Ready - ${analysisStats.totalJobs} jobs analyzed`);
        } else {
            showStatus('Ready to analyze jobs');
        }
    }
    
    function showStatus(message, isError = false) {
        statusDiv.textContent = message;
        if (isError) {
            statusDiv.classList.add('error');
        } else {
            statusDiv.classList.remove('error');
        }
        // Status text will remain visible until changed by another message
    }
});
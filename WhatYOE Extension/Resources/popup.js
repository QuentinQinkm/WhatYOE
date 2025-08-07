/*
YOE AI Analyzer - Popup Interface
*/

document.addEventListener('DOMContentLoaded', async function() {
    const autoToggle = document.getElementById('autoToggle');
    const autoToggleLabel = document.getElementById('autoToggleLabel');
    const analyzeButton = document.getElementById('analyzeButton');
    const statusDiv = document.getElementById('statusMessage');
    const decreaseYearBtn = document.getElementById('decreaseYear');
    const increaseYearBtn = document.getElementById('increaseYear');
    const yearDisplay = document.getElementById('yearDisplay');
    
    let currentTab;
    let autoAnalysisEnabled = false;
    let currentYears = 2; // Default value
    let isAnalyzing = false; // Track analysis state
    
    // Initialize
    await init();
    
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
        
        // Load saved settings (Safari compatible)
        try {
            const savedYears = localStorage.getItem('maxYOE');
            const savedAutoAnalysis = localStorage.getItem('autoAnalysis');
            
            if (savedYears) {
                currentYears = parseInt(savedYears);
                yearDisplay.textContent = currentYears;
            } else {
                yearDisplay.textContent = currentYears;
            }
            
            if (savedAutoAnalysis !== null) {
                autoAnalysisEnabled = savedAutoAnalysis === 'true';
                updateToggleState();
            }
        } catch (error) {
            console.log('Could not load settings');
        }
        
        showStatus('Ready to analyze jobs');
    }
    
    // Toggle switch functionality
    autoToggle.addEventListener('click', async function() {
        autoAnalysisEnabled = !autoAnalysisEnabled;
        updateToggleState();
        
        // Save setting (Safari compatible)
        localStorage.setItem('autoAnalysis', autoAnalysisEnabled.toString());
        
        if (autoAnalysisEnabled && currentYears > 0) {
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
    
    // Year adjustment buttons
    decreaseYearBtn.addEventListener('click', function() {
        if (currentYears > 0) {
            currentYears--;
            yearDisplay.textContent = currentYears;
            localStorage.setItem('maxYOE', currentYears.toString());
            if (autoAnalysisEnabled) {
                startAnalysis();
            }
        }
    });
    
    increaseYearBtn.addEventListener('click', function() {
        if (currentYears < 50) {
            currentYears++;
            yearDisplay.textContent = currentYears;
            localStorage.setItem('maxYOE', currentYears.toString());
            if (autoAnalysisEnabled) {
                startAnalysis();
            }
        }
    });
    
    // Analyze button (now a div)
    analyzeButton.addEventListener('click', function() {
        if (isAnalyzing) {
            stopAnalysis();
        } else {
            startAnalysis();
        }
    });
    
    async function startAnalysis() {
        if (currentYears <= 0) {
            showStatus('Please set valid years of experience');
            return;
        }
        
        isAnalyzing = true;
        analyzeButton.textContent = 'Stop Analyze';
        analyzeButton.style.pointerEvents = 'auto';
        showStatus('Starting AI analysis...');
        
        try {
            // Ensure content script is loaded
            await ensureContentScript();
            
            // Send analysis command to content script
            const response = await browser.tabs.sendMessage(currentTab.id, {
                action: 'startAnalysis',
                userYears: currentYears,
                autoMode: autoAnalysisEnabled
            });
            
            if (response && response.success) {
                showStatus('✓ Analysis started successfully');
            } else {
                showStatus('Failed to start analysis, try to refresh the page', true);
                isAnalyzing = false;
                analyzeButton.textContent = 'Analyze Jobs';
            }
        } catch (error) {
            console.error('Analysis error:', error);
            showStatus('Error - Please refresh the page', true);
            isAnalyzing = false;
            analyzeButton.textContent = 'Analyze Jobs';
        }
    }
    
    async function stopAnalysis() {
        isAnalyzing = false;
        analyzeButton.textContent = 'Analyze Jobs';
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
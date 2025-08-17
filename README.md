# WhatYOE - Resume-Job Match Analyzer

A macOS application that analyzes how well a resume matches a job description using Apple's Foundation Models AI.

## ⚠️ Current Status - Development Version
-----Aug 17------
Major UI/UX improvements and file-based job storage:
- **Collapsible Job Sections**: Jobs now grouped by rating (Good/Maybe/Poor/Rejected) with color-coded headers
- **File-Based Storage**: Migrated from UserDefaults to file-based storage with ResumeID/JobID.json structure
- **Resume Filtering**: Added resume dropdown to filter jobs by selected resume in desktop app
- **Material Blur Styling**: Consistent material design with proper typography and alignment
- **Universal Colors**: Centralized AppColors for consistent color management across app
- **Improved UI Alignment**: Better spacing and alignment between components
- **App Group Sandboxing**: Fixed sandboxing issues with shared container for data access

-----Aug 16------
Improved UI
Add proper jump to linkedin page
Fix app calling from background bug
Use Guided Generation, significant more reliable and consistent result. Speed up one analysis from 35-45 sec to 17-27 sec

-----Aug 15------
New function: 
-Job Manager - Scanned jobs will be saved to local storage
-Added UI for job management to desktop interface
-Local analysis function will be used for dev test only
-Optimized code structure and removed duplicate code
-Fixed web extension score loading and UI alignment issues

-----Aug 15------
-Start building UI based on concept 
-Implemented modern SwiftUI desktop interface with glass morphism design system, modular button components, gradient text fading, and improved resume management workflow.

-----Aug 13------
-Reconstruct the app into three targets: WhatYOE background serve, WhatYOE Desktop Interface (pending fix for proper resume mangement), WhatYOE safari extension (Pending fix for correct label render)

-----Aug 12:------

**This version is just for backup**

### Known Issues
- **App crashes when closing the native app window** - Window management needs fixing
- **Status label rendering is pending fix/removal** - UI rendering issues with status updates  
- **Current UI is for test functionality only** - UI/UX is temporary and will be redesigned

> This is a development build focused on implementing the 4-round analysis system. The core functionality works but UI stability and polish are pending.

### What's Updated in This Version
- **Enhanced Analysis System**: Replaced single years-of-experience extraction with comprehensive 4-scope evaluation
  - Years of Experience evaluation
  - Education assessment
  - Technical Skills analysis  
  - Relevant Experience evaluation
- **New Scoring System**: Implemented 0-3 scoring scale for each evaluation scope
  - Fit Score (0-3): How well candidate matches requirements
  - Gap Score (0-3): Areas needing improvement (higher = better)
- **Resume Import & Manager System**: Added complete resume management functionality
  - PDF import with text extraction
  - Resume storage and selection system
  - Active resume switching for analysis

## 🏗️ Architecture

**3-Component System:**
- **WhatYOE** - Background service with status bar icon, handles AI analysis and cross-app communication
- **WhatYOE-Desktop** - Full-featured SwiftUI desktop interface for resume management and job organization
- **WhatYOE Extension** - Safari extension for instant job analysis on web pages

## ✨ Features

### Desktop App (WhatYOE-Desktop)
- **Modern SwiftUI Interface** - Clean, intuitive design with material blur effects
- **Collapsible Job Sections** - Jobs organized by rating (Good/Maybe/Poor/Rejected) with tap-to-toggle
- **Resume Management** - Import, view, and manage multiple resumes with PDF support
- **Resume Filtering** - Filter job analysis results by selected resume
- **Color-Coded Organization** - Visual job rating system with consistent color scheme
- **File-Based Storage** - Reliable job storage with ResumeID/JobID.json structure

### Background Server (WhatYOE)
- **Status Bar Service** 📊 - Runs silently in background
- **AI-Powered Analysis** - Uses Apple's Foundation Models for intelligent matching
- **Cross-App Communication** - Handles requests from Safari extension and desktop app
- **Guided Generation** - Fast, reliable analysis (17-27 seconds vs previous 35-45 seconds)

### Safari Extension
- **One-Click Analysis** - Analyze job descriptions directly from LinkedIn and other job sites
- **Shared AI Engine** - Uses same algorithm as main app
- **Seamless Integration** - Works with imported resume data
- **Real-time Results** - Instant job-resume compatibility scoring

## 🚀 Quick Start

### 1. Build and Run
```bash
# Open in Xcode
open WhatYOE.xcodeproj

# Select WhatYOE scheme and build (⌘R)
```

### 2. Use Desktop App
- Launch WhatYOE-Desktop for full-featured interface
- Import resume PDFs and manage your resume library
- View and organize job analysis results by resume and rating
- Click section headers to collapse/expand job categories

### 3. Use Background Service
- WhatYOE runs in status bar (📊 icon) handling AI analysis
- Processes requests from both desktop app and Safari extension
- Runs silently in background with minimal resource usage

### 4. Use Safari Extension  
- Enable extension in Safari → Settings → Extensions
- Browse job pages → click extension icon → get instant analysis
- Results automatically saved and accessible in desktop app

## 🔧 Technical Details

### Core Technologies
- **PDFKit** - PDF text extraction
- **Foundation Models** - Apple's on-device AI
- **AppKit** - Native macOS UI
- **Safari Extensions** - Browser integration

### AI Analysis Pipeline
1. **Text Extraction** - PDFKit extracts resume text
2. **Text Cleaning** - AI cleans and structures text
3. **4-Round Evaluation** - YOE, Education, Skills, Experience
4. **Scoring System** - 0-3 scale with multipliers
5. **Final Recommendation** - Accept/Reject with detailed reasoning

### File Structure
```
WhatYOE/
├── AppDelegate.swift          # Status bar app setup
├── AnalysisViewController.swift # Main analysis UI
├── PromptTemplates.swift     # AI prompt templates
└── Info.plist               # App configuration

WhatYOE Extension/
├── SafariWebExtensionHandler.swift # Extension logic
├── manifest.json            # Extension manifest
└── Resources/               # Extension assets
```

## 📱 UI Flow

1. **Status Bar** → Click 📊 icon
2. **Menu Options**:
   - Local Analysis → Opens analysis window
   - Import Resume → Auto-opens file picker
   - Exit → Quits app
3. **Analysis Window**:
   - Upload resume PDF
   - Paste job description
   - Click Analyze → Get AI-powered results

## 🎯 Analysis Results

Each evaluation provides:
- **Fit Score** (0-3) - How well candidate matches requirements
- **Gap Score** (0-3) - Areas where candidate falls short
- **Final Score** - Combined evaluation with multipliers
- **Recommendation** - Accept/Reject with detailed reasoning

## 🔒 Privacy & Security

- **On-Device AI** - All analysis happens locally using Apple's Foundation Models
- **No Cloud Processing** - Resume data never leaves your device
- **Secure Storage** - Cleaned resume data stored locally for extension use

## 🛠️ Development

### Requirements
- macOS 26.0+ (for Foundation Models)
- Xcode 26.0+
- Safari 18.0+

### Building
1. Clone repository
2. Open `WhatYOE.xcodeproj` in Xcode
3. Select appropriate scheme (WhatYOE or Extension)
4. Build and run (⌘R)

### Key Files
- **AppDelegate.swift** - Main app lifecycle and status bar setup
- **AnalysisViewController.swift** - Core analysis logic and UI
- **PromptTemplates.swift** - AI prompt engineering
- **SafariWebExtensionHandler.swift** - Extension communication

## 📄 License

See [LICENSE.txt](LICENSE.txt) for details.

## 🤝 Contributing

This is a personal project demonstrating macOS app development with AI integration. Feel free to explore the code and adapt it for your own projects.

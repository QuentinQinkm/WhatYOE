# WhatYOE - Resume-Job Match Analyzer

A macOS application that analyzes how well a resume matches a job description using Apple's Foundation Models AI.

## ⚠️ Current Status - Development Version
-----Aug 13------
Reconstruct the app into three targets: WhatYOE background serve, WhatYOE Desktop Interface (pending fix for proper resume mangement), WhatYOE safari extension (Pending fix for correct label render)

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

**Simplified 2-App System:**
- **WhatYOE** - Main app with status bar icon, handles local analysis and extension requests
- **WhatYOE Extension** - Safari extension for instant job analysis

## ✨ Features

### Main App (WhatYOE)
- **Status Bar Icon** 📊 with dropdown menu
- **Local Analysis** - Import resume PDF and analyze job descriptions
- **Background Processing** - Runs in background, no dock icon
- **AI-Powered Analysis** - Uses Apple's Foundation Models for intelligent matching

### Safari Extension
- **Instant Analysis** - Analyze job descriptions from any webpage
- **Shared AI Engine** - Uses same algorithm as main app
- **Seamless Integration** - Works with imported resume data

## 🚀 Quick Start

### 1. Build and Run
```bash
# Open in Xcode
open WhatYOE.xcodeproj

# Select WhatYOE scheme and build (⌘R)
```

### 2. Use Main App
- App runs in status bar (📊 icon)
- Click icon → "Local Analysis" to open analysis window
- Import resume PDF → paste job description → analyze

### 3. Use Safari Extension
- Enable extension in Safari → Settings → Extensions
- Browse job pages → click extension icon → get instant analysis

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
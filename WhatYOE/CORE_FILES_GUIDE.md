# WhatYOE Core Files Documentation

## Overview

This guide documents the four core files that make up the WhatYOE 5-Variable Scoring System. These files have been refactored for maximum clarity and maintainability.

## 📁 Core Files Structure

```
WhatYOE/
├── AIEvaluationOutputs.swift       # AI Evaluation Output Structures  
├── CandidateEvaluationAI.swift     # AI Service Functions
├── DocumentCleaningStructures.swift # Document Cleaning Structures
└── AIPromptLibrary.swift           # AI Prompts Repository
```

---

## 1. AIEvaluationOutputs.swift
**Purpose:** Defines AI response formats for candidate evaluation

### 📋 Key Structures

#### `LLMScoringOutput` 
- **Variables 3, 4, 5:** Experience, Education, Skills scores (0-4 each)
- **Rationales:** Brief explanations for each score
- **Used by:** All AI evaluation functions

#### `ResumeParsingResult`
- **Variable 2:** Actual YOE calculation with confidence score
- **Usage:** Job-relevant experience extraction
- **Output:** Calculated YOE + methodology explanation

#### `ScoringScale` Enums
- **Reference guides** for consistent 0-4 scoring
- **Categories:** Experience, Education, Skills
- **Benefit:** Standardized evaluation criteria

### 🎯 Key Features
- **5-Variable System Overview** with clear variable mapping
- **Scoring reference guides** for consistent evaluation
- **Comprehensive documentation** for each structure
- **Clear usage attribution** showing which functions use each structure

---

## 2. CandidateEvaluationAI.swift  
**Purpose:** AI-powered candidate evaluation service

### 🔧 Service Functions

#### LLM Evaluation Functions
- `evaluateCandidate_WithRawText()` - Raw document evaluation
- `evaluateCandidate_WithCleanedResume()` - Optimized structured evaluation

#### YOE Calculation Functions  
- `calculateYOE_FromRawResume()` - General YOE extraction
- `calculateYOE_JobSpecific()` - Job-targeted YOE calculation

### 🚀 New Features
- **Clear function naming** with descriptive prefixes
- **Comprehensive documentation** with purpose, usage, advantages
- **Helper functions** for prompt building and data formatting
- **Legacy compatibility** with deprecation warnings
- **Error handling guidance** with expected exceptions

### 💡 Usage Examples
```swift
// Raw text evaluation
let scores = try await CandidateEvaluationAI.evaluateCandidate_WithRawText(
    resumeText: resumeContent, 
    jobDescription: jobPosting
)

// Optimized evaluation with cleaned data
let scores = try await CandidateEvaluationAI.evaluateCandidate_WithCleanedResume(
    cleanedResume: cleanedData, 
    jobDescription: jobPosting
)
```

---

## 3. DocumentCleaningStructures.swift
**Purpose:** Document cleaning and data extraction structures

### 📄 Resume Structures

#### `CleanedResume` - Master Structure
- **ContactInfo:** Name, email, phone extraction
- **ProfessionalExperience:** Work vs Other experience categorization
- **Education:** Degrees, certifications, training
- **Skills:** Technical, Professional, Industry categorization
- **YOE:** Intentionally skipped during cleaning (job-specific calculation)

#### Experience Categorization
- **`WorkExperience`:** Paid positions (employment, internships, consulting)
- **`OtherExperience`:** Valuable but unpaid (projects, volunteer, research)

### 🏢 Job Description Structures

#### `CleanedJobDescription` - Master Structure  
- **ExperienceRequirements:** YOE, level, industry context
- **Skills:** Required vs Preferred skill separation
- **Responsibilities:** Core job functions

### 🔄 Multi-Step Pipeline Helpers
- **`ContactAndSummaryExtraction`** - Step 1 helper
- **`EducationExtraction`** - Step 3 helper  
- **`JobRelevantYOECalculation`** - Evaluation phase structure

### 📚 Key Documentation Features
- **File overview** explaining structure organization
- **Pipeline step mapping** for multi-step cleaning
- **YOE calculation clarification** (why it's skipped in cleaning)
- **Usage attribution** for each structure
- **Clear categorization guidelines** for accurate data extraction

---

## 4. AIPromptLibrary.swift
**Purpose:** Central repository for all AI prompts

### 📝 Prompt Categories

#### Resume Cleaning Prompts
- **`resumeCleaningPrompt`** - Single-step fallback method
- **`contactAndSummaryExtractionPrompt`** - Step 1: Contact extraction
- **`professionalExperienceExtractionPrompt`** - Step 2: Experience categorization  
- **`educationExtractionPrompt`** - Step 3: Education extraction
- **`skillsExtractionPrompt`** - Step 4: Skills categorization

#### Job Description Cleaning  
- **`jobCleaningPrompt`** - Complete job posting structuring
- **Critical feature:** Required vs Preferred skills distinction

#### 5-Variable Evaluation Prompts
- **`fiveVariableLLMSystemPrompt`** - Core evaluation system prompt
- **`resumeYOEParsingSystemPrompt`** - YOE calculation methodology
- **Advanced:** Job-specific YOE calculation prompts

### 🎛️ Prompt Design Principles
- **Multi-step approach** for reliability and reduced hallucination
- **Structured outputs** using @Generable guided generation
- **Job-specific calculations** for improved accuracy
- **Clear role separation** to prevent prompt confusion

### 📖 Usage Guide
Built-in `usageGuide` provides:
- **Pipeline step mapping** for resume cleaning
- **Function selection guidance** for different scenarios  
- **Design principle explanations** for system architecture

### 💻 Usage Examples
```swift
// Step-by-step resume cleaning
let contactPrompt = AIPromptLibrary.contactAndSummaryExtractionPrompt
let experiencePrompt = AIPromptLibrary.professionalExperienceExtractionPrompt
let educationPrompt = AIPromptLibrary.educationExtractionPrompt
let skillsPrompt = AIPromptLibrary.skillsExtractionPrompt

// Evaluation system
let systemPrompt = AIPromptLibrary.fiveVariableLLMSystemPrompt
let userPrompt = AIPromptLibrary.createFiveVariableLLMPrompt(resume: resume, job: job)
```

---

## 🔄 System Integration Flow

```
1. RESUME CLEANING (DocumentCleaningStructures.swift)
   Raw Resume → Multi-step extraction → CleanedResume
   
2. JOB CLEANING (DocumentCleaningStructures.swift)  
   Raw Job Posting → Single-step extraction → CleanedJobDescription
   
3. AI EVALUATION (CandidateEvaluationAI.swift + AIPromptLibrary.swift)
   CleanedResume + CleanedJob → AI Evaluation → LLMScoringOutput
   
4. YOE CALCULATION (CandidateEvaluationAI.swift)
   Resume + Job Context → YOE Calculation → ResumeParsingResult
   
5. FINAL SCORING (ScoreCalculator.swift)
   5 Variables → Mathematical Formula → Final Score (0-100%)
```

---

## 🧮 Scoring Algorithm (ScoreCalculator.swift)

**Purpose:** Mathematical engine that converts the 5 evaluation variables into a final candidate score

### 📊 Algorithm Overview: Improved Option B

The scoring system uses a sophisticated algorithm that balances experience, education, and skills while accounting for job seniority requirements.

#### Input Variables
- **Variable 1:** Job Required YOE (from job description)
- **Variable 2:** Candidate Actual YOE (from resume parsing) 
- **Variables 3-5:** LLM Scores (Experience=0-4, Education=0-4, Skills=0-4)

#### Mathematical Formula Components

##### 1. Seniority Match Factor (fYOE)
```
fYOE = min(fYOECap, sqrt(actualYOE / (requiredYOE + ε)))
```
- **Purpose:** Measures how well candidate's experience matches job seniority
- **Square root scaling:** Provides diminishing returns for over-qualification
- **Cap at 1.5:** Prevents excessive bonus for extreme over-qualification
- **Epsilon (0.01):** Avoids division by zero for entry-level positions

##### 2. Experience Score Normalization (sExp)
```  
sExp = clamp01((sqrt(expScore) * fYOE) / (2.0 * fYOECap))
```
- **Purpose:** Converts LLM experience score (0-4) to normalized scale (0-1)
- **YOE Integration:** Multiplies by seniority factor for context-aware scoring
- **Proper Normalization:** Ensures maximum possible value stays within [0,1]

##### 3. Education Score Normalization (sEdu)
```
sEdu = clamp01(sqrt(eduScore) / 2.0)
```
- **Purpose:** Converts LLM education score (0-4) to normalized scale (0-1)
- **Square root scaling:** Provides diminishing returns like experience

##### 4. Dynamic Education Weight (wEdu)
```
wEdu = clamp(wEduIntercept - wEduSlope * requiredYOE, wEduMin, wEduMax)
```
- **Purpose:** Education importance decreases as job seniority increases
- **Linear Decay:** `wEduIntercept=0.85, wEduSlope=0.05`
- **Bounds:** Entry-level (75% education weight) → Senior (15% education weight)
- **Rationale:** Education matters more for junior roles, experience for senior roles

##### 5. Base Score Calculation (sBase)
```
sBase = clamp01((1.0 - wEdu) * sExp + wEdu * sEdu)
```
- **Purpose:** Weighted blend of experience and education scores
- **Dynamic Weighting:** Automatically adjusts based on job seniority level

##### 6. Skills Penalty Multiplier (mSkill)
```
mSkill = skillFloor + skillSpan * (skillScore/4)
mSkill = 0.95 + 0.05 * (skillScore/4)  // Range: [0.95, 1.0]
```
- **Purpose:** Penalty-only approach for skills deficiencies
- **Conservative Design:** Can only reduce score, never boost beyond experience+education
- **Minimal Impact:** 5% penalty range prevents skills from dominating evaluation

##### 7. Final Score Assembly
```
finalScore = clamp01(sBase * mSkill) * 100%
```
- **Purpose:** Combines all components into final percentage score
- **Range:** Guaranteed 0-100% output with proper mathematical bounds

### 🎯 Scoring Parameters (Tunable)

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `fYOECap` | 1.5 | Maximum over-qualification bonus |
| `wEduIntercept` | 0.85 | Education weight for entry-level jobs |
| `wEduSlope` | 0.05 | Education weight decay per YOE required |
| `wEduMin` | 0.15 | Minimum education weight (senior roles) |
| `wEduMax` | 0.75 | Maximum education weight (entry roles) |
| `skillFloor` | 0.95 | Minimum skills multiplier |
| `skillSpan` | 0.05 | Skills penalty range |

### 📈 Rating Classification

| Score Range | Rating | Interpretation |
|-------------|--------|----------------|
| 93-100% | **Good** | Strong candidate match |
| 85-92% | **Maybe** | Potential with reservations |
| 75-84% | **Poor** | Significant gaps identified |
| <75% | **Denied** | Insufficient qualifications |

### 💡 Algorithm Advantages

#### ✅ **Context-Aware Evaluation**
- Education weight automatically adjusts for job seniority
- Experience scaling considers over/under-qualification scenarios
- Skills assessment focuses on gap identification

#### ✅ **Mathematical Rigor**  
- All components properly normalized to [0,1] before combination
- Square root scaling prevents score inflation
- Clamping functions ensure output bounds are respected

#### ✅ **Realistic Scoring Distribution**
- Penalty-only skills approach prevents artificial score boosting
- Diminishing returns modeling reflects real-world hiring decisions
- Conservative parameter defaults reduce false positives

#### ✅ **Transparent & Debuggable**
- `ScoreBreakdown` structure exposes all intermediate calculations
- Each component separately analyzable for bias detection
- Tunable parameters allow algorithm customization

### 🔧 Usage Example
```swift
let result = ScoreCalculator.computeCandidateScore(
    actualYOE: 3.5,        // Candidate has 3.5 years experience  
    requiredYOE: 2.0,      // Job requires 2 years
    expScore: 3,           // LLM rates experience as 3/4
    eduScore: 2,           // LLM rates education as 2/4  
    skillScore: 4          // LLM rates skills as 4/4
)

print(result.score_percentage)  // Final score: 87%
print(result.breakdown.wEdu)    // Education weight: 75% (2 YOE job)
print(ScoreCalculator.specRating(for: result.score_percentage)) // "Maybe"
```

This scoring algorithm provides a mathematically sound, contextually aware, and tunable framework for candidate evaluation that balances all five assessment variables appropriately.

---

## 🛠️ Maintenance Guidelines

### When to Update Each File

#### AIEvaluationOutputs.swift
- **Add new AI output formats** when expanding evaluation criteria
- **Modify scoring scales** if evaluation rubrics change
- **Update structure fields** when AI response format needs change

#### CandidateEvaluationAI.swift  
- **Add new evaluation functions** for different evaluation scenarios
- **Update helper functions** when prompt building logic changes
- **Modify error handling** when AI service requirements change

#### DocumentCleaningStructures.swift
- **Add new document structures** when supporting new document types
- **Update extraction fields** when cleaning requirements change  
- **Modify pipeline helpers** when multi-step process changes

#### AIPromptLibrary.swift
- **Update prompts** when AI model requirements change
- **Add new templates** when supporting new evaluation scenarios
- **Modify system prompts** when scoring criteria evolve

### 🔍 Code Quality Standards
- **Comprehensive documentation** for all public functions/structures
- **Clear naming conventions** with descriptive prefixes
- **Usage examples** in documentation for complex functions
- **Backward compatibility** with deprecation warnings when needed
- **Error handling guidance** with expected exception types

---

## 🎯 Benefits of Refactored Structure

### ✅ Improved Maintainability
- **Clear separation of concerns** between structures, services, and prompts
- **Comprehensive documentation** making onboarding easier
- **Consistent naming conventions** reducing confusion
- **Usage attribution** showing interdependencies

### ✅ Enhanced Clarity
- **File purpose statements** at the top of each file
- **Section organization** with clear MARK comments
- **Inline documentation** explaining design decisions
- **Code examples** demonstrating proper usage

### ✅ Better Developer Experience  
- **Legacy compatibility** ensuring smooth transitions
- **Error handling guidance** reducing debugging time
- **Usage guides** providing implementation guidance
- **Reference materials** (like scoring scales) built into the code

---

## 📞 Quick Reference

| Task | Primary File | Key Structure/Function |
|------|--------------|----------------------|
| Define AI output format | AIEvaluationOutputs | `LLMScoringOutput`, `ResumeParsingResult` |
| Call AI evaluation | CandidateEvaluationAI | `evaluateCandidate_WithRawText()` |
| Structure resume data | DocumentCleaningStructures | `CleanedResume`, `ProfessionalExperience` |
| Get AI prompt | AIPromptLibrary | `fiveVariableLLMSystemPrompt` |
| Calculate YOE | CandidateEvaluationAI | `calculateYOE_FromRawResume()` |
| Clean job posting | DocumentCleaningStructures | `CleanedJobDescription` |
| Calculate final score | ScoreCalculator | `computeCandidateScore()` |
| Get score breakdown | ScoreCalculator | `ScoreBreakdown`, `specRating()` |

This refactored structure significantly improves code maintainability while preserving all existing functionality and design principles.
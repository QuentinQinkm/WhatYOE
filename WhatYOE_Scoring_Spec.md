# WhatYOE Scoring Spec (LLM + Calculation)

This document defines (1) **what the LLM must output** and (2) **how to compute the final candidate Score** using those outputs.

---

## 1) LLM Output Contract

The LLM must return a single JSON object with the following fields:

```json
{
  "relevant_yoe_years": <float>,          // a : total relevant experience in years (work + project-equivalent), de-duplicated
  "education_raw": <int>,                  // E_raw : education relevance in {0,1,2,3,4}
  "skills_raw": <int>,                     // S : overall skill match in {0,1,2,3,4}
  "rationales": {
    "yoe": "<string>",
    "education": "<string>",
    "skills": "<string>"
  }
}
```

### Guidance for the LLM
- **relevant_yoe_years (a):** 
  - Sum *relevant* work + *project-equivalent* years for the role’s major tasks.
  - Convert projects to year-equivalents using the app policy (e.g., major ≈ 0.75–1.0 yr; moderate ≈ 0.25–0.5 yr; minor ≈ 0–0.1 yr).
  - **Do not double-count overlapping time** (concurrent roles/tasks).
- **education_raw (E_raw in {0,1,2,3,4}):**
  - 0 = totally missing; 1 = minor relevant education; 2 = not meeting requirements but relevant major; 3 = meets requirements; 4 = surpasses.
- **skills_raw (S in {0,1,2,3,4}):**
  - Overall judgment of required skill coverage (0 = none, 4 = excellent). This is *not* per-skill; it’s a global rating for the JD’s critical skills.
- **rationales:** short bullet-style notes explaining the derivations and any assumptions (max 2–3 lines each).

---

## 2) Inputs (from App/JD)

- `r` (float ≥ 0): **Required YOE** from the job description.

---

## 3) Tunable Parameters

- `H = 5.0` — education weight **decay** smoothing (larger = slower decay as r increases).
- `m_min = 0.5`, `m_max = 1.0` — **skills multiplier caps** (Option 2, capped boost).

> Keep these as app settings (feature flags).

---

## 4) Component Calculations

Let the LLM fields be: `a = relevant_yoe_years`, `E_raw = education_raw`, `S = skills_raw`.

### 4.1 Experience multiplier
```
M_exp = sqrt( a / max(1, r) )
```
- Diminishing returns via square root.
- Use `max(1, r)` to avoid division by zero for r=0.

### 4.2 Education multiplier (quality)
```
M_edu = sqrt( E_raw / 4 )
```
### 4.3 Education weight (squared decay by required YOE)
```
w_edu = 1 / ( 1 + (r / H)^2 )
```
- r=0 ⇒ w_edu=1.0 (education dominates); r grows ⇒ weight decays smoothly toward 0.

### 4.4 Core (experience + education blend)
```
Core = (1 - w_edu) * M_exp + w_edu * M_edu
```

### 4.5 Skills multiplier (penalty-capped, Option 2)
```
m_skill = m_min + (m_max - m_min) * sqrt( S / 4 )
```
- With defaults: `m_min=0.5`, `m_max=1.0`.
- Behavior: S=0 ⇒ halves the Core; S=4 ⇒ leaves Core unchanged.

---

## 5) Final Score

```
Score = Core * m_skill
```

- Clamp all intermediate values to [0,1] if needed.
- Scale to 0–100 for UI if desired: `Score_pct = round(100 * Score)`.

---

## 6) Pseudocode

```
def compute_fit_score(r, a, E_raw, S, H=5.0, m_min=0.5, m_max=1.0):
    clamp01 = lambda x: max(0.0, min(1.0, x))

    # Experience
    denom = max(1.0, r)
    M_exp = clamp01((a / denom) ** 0.5)

    # Education
    M_edu = clamp01((E_raw / 4.0) ** 0.5)

    # Education weight
    w_edu = clamp01(1.0 / (1.0 + (r / H) ** 2))

    # Core
    Core = (1.0 - w_edu) * M_exp + w_edu * M_edu

    # Skills multiplier (Option 2)
    m_skill = m_min + (m_max - m_min) * (S / 4.0) ** 0.5
    m_skill = clamp01(m_skill)

    # Final
    Score = clamp01(Core * m_skill)
    return Score
```

---

## 7) Validation & Logging

- Validate: `a ≥ 0`, `r ≥ 0`, `E_raw ∈ {0..4}`, `S ∈ {0..4}`.
- Normalize if LLM returns floats: round to nearest in {0..4}.
- Log intermediates (`M_exp`, `M_edu`, `w_edu`, `Core`, `m_skill`, `Score`) for debugging and explanations.
- Store the LLM `rationales` with the computed values for traceability.

---

## 8) Notes

- **Project→YOE policy** must be consistent across runs to ensure stable scoring.
- If you later add per-skill weighting, keep the *overall* `skills_raw` but compute it from per-skill matches in the LLM prompt.
- If you need a hard gate on skills: set `m_min = 0.0` temporarily.
```

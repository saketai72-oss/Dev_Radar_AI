---
name: autonomous-feature
description: Autonomous end-to-end feature development across multi-project stacks with minimal human intervention.
version: 1.0.0
requires_agents: orchestrator
requires_skills: parallel-agents, coordinator-mode, intelligent-routing, verify-changes
artifact_outputs: project-context, requirements, implementation-plan, verification-report
---

# /autonomous-feature — Autonomous Multi-Project Orchestrator

End-to-end autonomous feature engineering across Web, Mobile, Desktop, Backend API, Fullstack, and DevOps stacks with minimal human intervention.

$ARGUMENTS

---

## 9-Stage Autonomous Lifecycle

```
[1. Discovery] ➔ [2. Requirements] ➔ [3. Architecture] ➔ [4. Delegation] ➔ [5. Implementation]
                                                                                │
[9. Memory & Report] ⬅ [8. Code Review] ⬅ [7. QA & Auto-Heal] ⬅ [6. Integration] ┘
```

---

### Stage 1: Discovery & Classification
- Scan codebase context, dependencies, and configuration.
- Classify the target architecture:
  * **Web**: React, Next.js, Vue, Tailwind
  * **Backend API**: Node.js, Python (FastAPI/Django), Go
  * **Mobile**: Flutter, React Native
  * **Desktop**: Electron, Tauri, .NET/WPF, Flutter Desktop
  * **Fullstack**: Web frontend + Backend API + DB
  * **DevOps**: Docker, K8s, CI/CD, Terraform
- Output artifact: `project-context.md`.

### Stage 2: Requirement Analysis
- Analyze user request and extract functional specifications, security constraints, and performance expectations.
- Identify edge cases, trust boundaries, and platform requirements.
- Output artifact: `requirements.md`.

### Stage 3: Architecture & Planning
- Formulate architectural design, data models, and API contracts (REST/OpenAPI/TypeScript).
- **Approval Gate**:
  * *Standard Task*: Automatically proceed to implementation without user prompt.
  * *Major Architectural Overhaul*: Solicit human confirmation only if breaking backward compatibility or migrating primary database.
- Output artifact: `implementation-plan.md`.

### Stage 4: Task Delegation
- Decompose plan into granular subtasks with strict file ownership:
  * UI/Components ➔ `frontend-specialist`
  * API/Services ➔ `backend-specialist`
  * Desktop Main/IPC ➔ `desktop-developer`
  * Mobile Screens/Native ➔ `mobile-developer`
  * Schemas/Migrations ➔ `database-architect`
  * Tests/Fixtures ➔ `test-engineer`
  * CI/CD/Infra ➔ `devops-engineer`

### Stage 5: Implementation
- Execute implementation adhering to `clean-code` standards.
- Execute **in parallel** for independent files across domain boundaries (e.g., frontend components and backend endpoints once API contract is fixed).
- Execute **sequentially** for shared interfaces and central configurations.

### Stage 6: Integration
- Wire up frontend/desktop consumers with backend API endpoints.
- Validate contract conformity (TypeScript types, schema parsers).
- Execute local database migrations and seed fixtures if applicable.

### Stage 7: QA & Self-Healing Loop
- Execute repository test suites (`npm test`, `pytest`, etc.).
- **Self-Healing Protocol**:
  1. Capture failing test traces and compiler errors.
  2. Route targeted fixes to the responsible file owner.
  3. Bounded to a **maximum of 3 auto-fix retry iterations**.
  4. If unresolved after 3 attempts, escalate with diagnostic report.
- Output artifact: `verification-report.md`.

### Stage 8: Independent Review
- Delegate review to `code-reviewer` (strictly independent from authoring agent).
- Verify:
  * Real test execution logs are present and passing.
  * Code adheres to clean-code standards and avoids bloat.
  * Security boundaries, inputs, and IPC channels are sanitized.

### Stage 9: Memory Update & Final Reporting
- Record newly established architecture decisions and patterns into `.agents/memory/`.
- Generate summary of implemented features, touched files, test evidence, and remaining non-blocking items.

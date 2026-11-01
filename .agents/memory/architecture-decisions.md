---
type: project
created: 2026-11-01
updated: 2026-11-01
---

# Architecture Decisions & API Contracts

## ADR-001: Autonomous Multi-Project Orchestrator

- **Decision**: Centralize orchestration via `.agents/agent/orchestrator.md` and `.agents/workflows/autonomous-feature.md`.
- **Contract First**: All client-server interfaces require explicit TypeScript definitions or OpenAPI/JSON schemas before frontend or desktop implementation begins.
- **IPC Isolation**: Desktop apps must keep renderer processes sandboxed (`contextIsolation: true`, `nodeIntegration: false`) and communicate strictly through whitelisted IPC channels.
- **Contract Enforcement**: Standard response envelopes `{ data, meta, error }` are enforced across backend APIs.

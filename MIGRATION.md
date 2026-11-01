# Migration Guide

## Upgrading to AG-Kit Autonomous Multi-Project Orchestrator

### From Legacy Workspace to AG-Kit 2026.8.31

1. **Autonomous Protocol Integration**:
   - Workflows now run via `.agents/workflows/autonomous-feature.md` with multi-project auto-orchestration.
   - Global autonomy rules are enforced via `.agents/rules/00-autonomous-development.md`.

2. **Cross-Platform Hook Execution**:
   - Hooks in `.agents/hooks/` now support Windows/PowerShell environments with BOM stripping and `node:url` `fileURLToPath` normalization.

3. **Multi-Project Agent Roster**:
   - Added `software-architect`, `desktop-developer`, and `code-reviewer`.
   - File ownership matrices and auto-recovery loops are defined in `orchestrator.md`.

4. **Validation**:
   - Run `npm run check:agents` for AG-Kit schema and consistency validation.
   - Run `npm run check:antigravity` to confirm Antigravity Doctor compliance.
   - Run `npm run test:antigravity` for test harness verification.

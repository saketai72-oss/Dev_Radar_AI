---
type: project
created: 2026-07-18
updated: 2026-11-01
---

# Technical Decisions

- Component metadata uses SemVer while the toolkit release keeps CalVer.
- `manifest.json` and `manifest.lock.json` must remain synchronized with component frontmatter.
- Cross-platform hooks normalize execution paths via `node:url` `fileURLToPath` for Windows PowerShell compatibility.
- UTF-8 BOM characters from PowerShell streams are stripped prior to JSON parsing in safety hooks.

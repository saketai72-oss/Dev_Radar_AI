---
type: project
created: 2026-11-01
updated: 2026-11-01
---

# Lessons Learned & Environment Troubleshooting

## Windows & PowerShell Compatibility
- PowerShell piping into Node CLI scripts prepends a UTF-8 BOM (`\uFEFF`), which causes standard `JSON.parse()` to fail. Strip `^\uFEFF` before parsing.
- On Windows, `process.argv[1]` contains backslashes and potentially differing drive letter casing compared to `import.meta.url`. Always normalize using `fileURLToPath(import.meta.url)` and `path.resolve()` with case-insensitive comparison on `win32`.
- Selective version checking in doctors avoids false negatives when optional workspace folders (`cli/`, `web/`) are absent.

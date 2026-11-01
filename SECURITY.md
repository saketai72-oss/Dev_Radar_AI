# Security Policy

## Supported Versions

The following versions are currently supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 2026.8.x| :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability within this repository or the AG-Kit integration:

1. **Do not create a public issue.**
2. Send a detailed report describing the vulnerability, proof of concept, and affected components to the repository maintainers.
3. You will receive an acknowledgment within 48 hours and subsequent progress updates.

## Safety & Tool Call Sandboxing

This project employs AG-Kit safety hooks (`.agents/hooks/validate-tool-call.mjs`) to intercept and prevent destructive operations (such as unconstrained recursive deletes, formatting drives, or elevated privileges).

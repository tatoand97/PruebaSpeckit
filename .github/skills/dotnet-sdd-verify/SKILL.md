---
name: dotnet-sdd-verify
description: Run and report the reusable OpenSpec .NET SDD package gate or an installed consumer guard.
---

# Verify .NET SDD

1. Record `git status --short` before verification.
2. Run `openspec validate --all --strict` and preserve its result.
3. In the distribution repository, run `./scripts/Test-OpenSpecDotNetSddPackage.ps1` and report OpenSpec, consistency, audits, guard tests, and installer tests.
4. In an installed consumer, run `./scripts/Invoke-OpenSpecSddGuard.ps1` and read `artifacts/sdd-guard/guard-result.json` plus `guard-result.md`.
5. Report every failed check and evidence location without exposing secrets or absolute paths.
6. Never weaken implementation, specifications, tests, thresholds, or guard logic to hide a failure.
7. Do not claim completion while a required command fails, reports `ERROR`, or lacks evidence.

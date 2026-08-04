---
name: dotnet-sdd-verify
description: Run and report the reusable OpenSpec .NET SDD package gate or an installed consumer guard.
---

# Verify .NET SDD

1. Work from the repository root and record `git status --short` first.
2. Run `openspec validate --all --strict` and preserve its exit code and summary.
3. If `scripts/Test-OpenSpecDotNetSddPackage.ps1` and `distribution/openspec/dotnet-sdd/` exist, run the package gate and report its OpenSpec, consistency, audit, guard-test, and installer-test results.
4. Otherwise, run `scripts/Invoke-OpenSpecSddGuard.ps1` for the installed consumer and read `artifacts/sdd-guard/guard-result.json` plus `guard-result.md` when present.
5. Report every failing check and evidence location. Do not expose source, command output containing secrets, or absolute paths from guard evidence.
6. Do not modify code, specifications, tests, thresholds, or guard logic merely to hide a failure.
7. Do not mark the package or consumer complete while a required command fails, reports `ERROR`, or lacks required evidence.

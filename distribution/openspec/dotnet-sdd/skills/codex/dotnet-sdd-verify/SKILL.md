---
name: dotnet-sdd-verify
description: Run and report the repository's OpenSpec and deterministic .NET SDD quality gates. Use before claiming an OpenSpec change or .NET implementation is complete, or when asked to verify architecture, build, tests, coverage, OpenAPI, secrets, or migration regressions.
---

# Verify .NET SDD

1. Work from the repository root.
2. Record `git status --short` before verification so preexisting changes remain distinguishable.
3. Run `openspec validate --all --strict` and preserve its exit code and summary.
4. Run `./scripts/Invoke-OpenSpecSddGuard.ps1` and preserve its exit code.
5. Read `PoCFinal/artifacts/sdd-guard/guard-result.json` and `guard-result.md` when present.
6. Report every command, pass/fail result, check ID, and evidence location. Distinguish a failure already present in the baseline from a regression only when evidence supports that distinction.
7. Do not modify code, specifications, tests, thresholds, or guard logic merely to hide a failure.
8. Do not mark the implementation complete while either command fails, reports `ERROR`, or lacks required evidence.

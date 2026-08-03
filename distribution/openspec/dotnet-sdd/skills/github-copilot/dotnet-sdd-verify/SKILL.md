---
name: dotnet-sdd-verify
description: Verify OpenSpec and the deterministic .NET SDD gates before reporting an implementation complete.
---

# Verify .NET SDD

From the repository root:

1. Record `git status --short`.
2. Run `openspec validate --all --strict`.
3. Run `./scripts/Invoke-OpenSpecSddGuard.ps1`.
4. Read `PoCFinal/artifacts/sdd-guard/guard-result.json` and report every failed check and evidence location.
5. Distinguish documented baseline failures from regressions only when evidence supports it.
6. Never modify code, specifications, tests, thresholds, or gate logic just to hide a failure.
7. Never claim completion while a command fails, the guard reports `ERROR`, or required evidence is absent.

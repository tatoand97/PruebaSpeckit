# Deterministic .NET SDD Guard

The neutral guard engine performs mechanical checks for the .NET 10 baseline, project-reference directions, persistence ownership, prohibited migrations and `EnsureCreated()`, Wolverine mediator-only configuration, Azure App Configuration, Problem Details, Minimal APIs, restore, warning-free Release build, unit tests, business coverage, and pinned Redocly linting.

Run the repository-level entry point from the repository root:

```powershell
./scripts/Invoke-OpenSpecSddGuard.ps1
```

That entry point first runs `openspec validate --all --strict`, performs a high-confidence secret/local-path scan, and then invokes this engine for `PoCFinal`. Evidence is written below `PoCFinal/artifacts/sdd-guard/`. The JSON report is canonical and intentionally excludes command output, source contents, payloads, secrets, and absolute paths.

Exit codes are `0` for pass, `1` for a failed mandatory check, and `2` for an engine configuration or execution error.

Run engine tests with:

```powershell
./tools/dotnet-sdd-guard/tests/Invoke-GuardTests.ps1
```

OpenSpec does not run this guard automatically; agents and CI invoke it explicitly.

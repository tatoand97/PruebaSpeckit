# Deterministic .NET SDD Guard

The reusable guard engine performs mechanical checks for the .NET 10 baseline, project-reference directions, persistence ownership, prohibited migrations and database auto-creation, Wolverine mediator-only configuration, Azure App Configuration, Problem Details, Minimal APIs, restore, warning-free Release build, unit tests, business coverage, and pinned Redocly linting.

Run the installed consumer entry point from the consumer repository root:

```powershell
./scripts/Invoke-OpenSpecSddGuard.ps1
```

The wrapper validates OpenSpec, scans high-confidence secrets and local-environment markers, and invokes the engine for the consumer root. Evidence is written below `<consumer-root>/artifacts/sdd-guard/`. Reports exclude command output, source contents, payloads, secrets, and absolute paths.

The engine may also be invoked directly:

```powershell
./tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1 `
  -ProjectRoot <consumer-root> `
  -ContractRoot <consumer-root> `
  -EvidencePath <optional-output-directory>
```

`-ContractRoot` and `-EvidencePath` are optional. The evidence path selects where sanitized reports and raw test results are written; it never supplies preapproved gate outcomes. Active contracts are discovered only under `openspec/specs`, non-archived `openspec/changes`, and `docs/contracts`; historical and generated trees are ignored.

Exit codes are `0` for pass, `1` for a failed mandatory check, and `2` for an engine configuration or execution error.

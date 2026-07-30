# .NET SDD Guard

`dotnet-sdd-guard` 1.0.1 is the deterministic enforcement component for the
mechanically verifiable controls defined by `dotnet-sdd` 1.0.1. It does not judge
business meaning, architecture trade-offs, or requirement interpretation.

The extension registers the mandatory `after_implement` hook
`speckit.dotnet-sdd-guard.verify`. Spec Kit materializes the command for the active
integration during extension installation. The command only launches the PowerShell
script and preserves its exit code.

## Run directly

```powershell
& ".specify/extensions/dotnet-sdd-guard/scripts/Invoke-SddGuard.ps1" `
  -ProjectRoot (Get-Location).Path
```

Exit codes:

- `0`: every hard check passed.
- `1`: at least one hard check failed.
- `2`: Guard configuration or execution error.

The only project writes are:

```text
artifacts/sdd-guard/guard-result.json
artifacts/sdd-guard/guard-result.md
artifacts/sdd-guard/raw/
```

The JSON report is canonical. Evidence is reduced to counts, percentages, and
structural summaries; command output, source, spec contents, secrets, payloads, and
absolute paths are never exported.

## Checks

Hard checks cover .NET 10, unambiguous solution selection, restore, warning-free
Release build, unit tests, business coverage, Redocly 2.41.1 lint, project-reference
direction, persistence ownership, prohibited migrations/design tooling/EnsureCreated,
Wolverine mediator-only baseline, prohibited distributed transports, Azure App
Configuration preparation, and Problem Details for HTTP applications.

The guard stays deterministic and offline: checks are static and do not execute HTTP
requests, contact Azure, connect to SQL Server, create migrations, or mutate source.
OpenAPI/configuration/architecture results are mechanical and do not claim runtime
equivalence.

Repository abstraction, exception mapping, and uncertain Minimal API detection remain
advisory where a mechanical check would be fragile.

## Tests

```powershell
& "./tests/Invoke-GuardTests.ps1"
```

The tests create synthetic fixtures in the operating system temporary directory and
never modify a PoC application.

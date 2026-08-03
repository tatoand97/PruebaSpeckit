# dotnet-sdd for OpenSpec

This package installs the repository-local `dotnet-sdd` schema, generic `openspec/config.yaml`, canonical governance, neutral deterministic guard, and custom verification skills. It does not install or depend on Python, `uv`, or any previous SDD runtime.

Prerequisites:

- Node.js 20.19.0 or newer.
- OpenSpec CLI `1.7.0` or a compatible newer `1.x` release available as `openspec`. Other major versions are rejected until compatibility is established.
- PowerShell 7 and .NET 10 for the verification gate.

Install into a target repository:

```powershell
./install.ps1 -ProjectPath <consumer-root> -Tools codex,github-copilot
```

The installer detects every differing payload collision before modification and refuses it by default. Use `-BackupExisting` only after reviewing the complete collision list; it creates timestamped adjacent backups before replacement. Identical reinstallations are idempotent. Existing legacy SDD roots must be migrated and preserved separately before installation.

After installation:

```powershell
openspec schema which dotnet-sdd
openspec schema validate dotnet-sdd --verbose
openspec validate --all --strict
```

Codex commands are `$openspec-propose`, `$openspec-explore`, `$openspec-update-change`, `$openspec-apply-change`, `$openspec-sync-specs`, and `$openspec-archive-change`. GitHub Copilot commands are `/opsx-propose`, `/opsx-explore`, `/opsx-update`, `/opsx-apply`, `/opsx-sync`, and `/opsx-archive`.

Invoke `./scripts/Invoke-OpenSpecSddGuard.ps1` explicitly before completion. Historical contracts under `docs/sdd-history/` or `legacy/` are never used as active gate evidence.

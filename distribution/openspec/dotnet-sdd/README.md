# dotnet-sdd for OpenSpec

This package installs the repository-local `dotnet-sdd` schema plus the neutral deterministic guard and custom verification skills. It does not install or depend on Python, `uv`, or any previous SDD runtime.

Prerequisites:

- Node.js 20.19.0 or newer.
- OpenSpec CLI available as `openspec`.
- PowerShell 7 and .NET 10 for the verification gate.

Install into a target repository:

```powershell
./install.ps1 -ProjectPath C:\path\to\project -Tools codex,github-copilot
```

The installer refuses differing existing payload files. Use `-BackupExisting` only after reviewing the collision; it creates a timestamped adjacent backup before replacement. Existing legacy SDD roots must be migrated and preserved separately before installation.

After installation:

```powershell
openspec schema which dotnet-sdd
openspec schema validate dotnet-sdd --verbose
openspec validate --all --strict
```

Use `$openspec-propose` in Codex or `/opsx-propose` in GitHub Copilot to begin a change. Invoke `./scripts/Invoke-OpenSpecSddGuard.ps1` explicitly before completion.

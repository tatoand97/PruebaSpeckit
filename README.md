# .NET OpenSpec Proof of Concept

This repository uses OpenSpec `1.7.0` with the local `dotnet-sdd` schema for governed development of the .NET 10 modular-monolith application in `PoCFinal`.

## Active structure

- `openspec/`: the only active OpenSpec root, including the `dotnet-sdd` schema and the `contact-requests` baseline capability.
- `docs/architecture/dotnet-sdd-governance.md`: canonical architecture, quality, security, and Definition of Done policy.
- `tools/dotnet-sdd-guard/`: neutral deterministic verification engine.
- `scripts/Invoke-OpenSpecSddGuard.ps1`: repository-level OpenSpec and .NET gate.
- `distribution/openspec/dotnet-sdd/`: auditable reusable package and installer.
- `docs/sdd-history/spec-kit/` and `legacy/spec-kit/`: unsupported historical evidence only.

## Setup

OpenSpec requires Node.js 20.19.0 or newer:

```powershell
npm install -g @fission-ai/openspec@1.7.0
openspec init . --tools 'codex,github-copilot' --force
openspec update
```

Do not initialize OpenSpec inside `PoCFinal`.

## Workflow

Terminal state and validation commands:

```powershell
openspec list
openspec status --change <change-name>
openspec validate --all --strict
openspec schemas
```

Agent chat workflows are propose, explore, update, apply, sync, and archive. Codex uses `.codex/skills/openspec-*` (for example `$openspec-propose`); GitHub Copilot uses generated `/opsx-*` prompts.

## Verification

```powershell
dotnet restore PoCFinal/PoCFinal.sln
dotnet build PoCFinal/PoCFinal.sln -c Release --no-restore -warnaserror
dotnet test PoCFinal/PoCFinal.sln -c Release --no-build
./scripts/Invoke-OpenSpecSddGuard.ps1
```

Run a sanitized evaluation record with:

```powershell
./tools/openspec-sdd-harness/Invoke-OpenSpecEvaluation.ps1
```

OpenSpec has no automatic post-implementation hook; agents and CI invoke the deterministic gate explicitly.

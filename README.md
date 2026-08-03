# .NET OpenSpec Proof of Concept

This repository uses OpenSpec `1.7.0` with the local `dotnet-sdd` schema for governed development of the .NET 10 modular-monolith application in `PoCFinal`.

## Active structure

- `openspec/`: the only active OpenSpec root, including the `dotnet-sdd` schema and the `contact-requests` baseline capability.
- `openspec/specs/contact-requests/contracts/openapi.yaml`: active HTTP contract for contact-request registration.
- `docs/architecture/dotnet-sdd-governance.md`: canonical architecture, quality, security, and Definition of Done policy.
- `tools/dotnet-sdd-guard/`: neutral deterministic verification engine.
- `scripts/Invoke-OpenSpecSddGuard.ps1`: repository-level OpenSpec and .NET gate.
- `distribution/openspec/dotnet-sdd/`: auditable reusable package and installer.
- `docs/sdd-history/spec-kit/` and `legacy/spec-kit/`: unsupported historical evidence only; these trees never participate in current gates.

## Setup

OpenSpec `1.7.0` is the minimum supported version and requires Node.js 20.19.0 or newer:

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

Codex uses `$openspec-propose`, `$openspec-explore`, `$openspec-update-change`, `$openspec-apply-change`, `$openspec-sync-specs`, and `$openspec-archive-change`. GitHub Copilot uses `/opsx-propose`, `/opsx-explore`, `/opsx-update`, `/opsx-apply`, `/opsx-sync`, and `/opsx-archive`.

## Verification

```powershell
dotnet restore PoCFinal/PoCFinal.sln
dotnet build PoCFinal/PoCFinal.sln -c Release --no-restore -warnaserror
dotnet test PoCFinal/PoCFinal.sln -c Release --no-build
npx --yes @redocly/cli@2.41.1 lint openspec/specs/contact-requests/contracts/openapi.yaml
./scripts/Invoke-OpenSpecSddGuard.ps1
```

Run a sanitized evaluation record with:

```powershell
./tools/openspec-sdd-harness/Invoke-OpenSpecEvaluation.ps1
```

OpenSpec has no automatic post-implementation hook; agents and CI invoke the deterministic gate explicitly.

The reusable installer under `distribution/openspec/dotnet-sdd/` installs the schema, generic configuration, canonical governance, guard, and requested assistant skills with collision-safe backups.

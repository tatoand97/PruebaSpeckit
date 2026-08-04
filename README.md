# Reusable .NET SDD Framework for OpenSpec

This repository distributes `dotnet-sdd`, a reusable OpenSpec workflow for governed .NET development. It contains no executable demonstration application and no product-specific capability.

## What it solves

The package keeps behavioral specifications separate from technical design while making architecture and quality gates explicit and repeatable. Consumers receive a custom OpenSpec schema, reusable governance, assistant integrations, and a deterministic guard for .NET 10 projects.

## Package contents

- `openspec/`: the single active OpenSpec root used to develop and validate the package.
- `openspec/schemas/dotnet-sdd/`: schema and six workflow templates.
- `docs/architecture/dotnet-sdd-governance.md`: canonical .NET architecture and quality policy.
- `tools/dotnet-sdd-guard/`: reusable consumer-project verification engine and synthetic fixture tests.
- `distribution/openspec/dotnet-sdd/`: installable package, installer, tests, configuration, schema, governance, guard, and verification skills.
- `.codex/skills/` and `.github/skills/`: Codex and GitHub Copilot integrations.
- `legacy/spec-kit/`: unsupported historical framework assets; never part of the active workflow.

## Requirements

- Node.js 20.19.0 or newer.
- OpenSpec CLI 1.7.0 or a compatible newer 1.x release.
- PowerShell 7.
- .NET 10 when validating a consumer project or running guard fixtures.

Install the pinned OpenSpec version used by CI:

```powershell
npm install --global @fission-ai/openspec@1.7.0
```

## Install in a consumer repository

```powershell
./distribution/openspec/dotnet-sdd/install.ps1 `
  -ProjectPath C:\path\to\consumer `
  -Tools codex,github-copilot
```

The installer performs collision checks before package writes, supports reviewed backups through `-BackupExisting`, is idempotent for identical content, generates the requested official OpenSpec integrations, and validates the installed schema.

## Use with Codex and GitHub Copilot

Codex uses `$openspec-propose`, `$openspec-explore`, `$openspec-update-change`, `$openspec-apply-change`, `$openspec-sync-specs`, and `$openspec-archive-change`.

GitHub Copilot uses `/opsx-propose`, `/opsx-explore`, `/opsx-update`, `/opsx-apply`, `/opsx-sync`, and `/opsx-archive`.

Both integrations expose `dotnet-sdd-verify` for explicit package or consumer verification. OpenSpec-managed skills and prompts are regenerated with `openspec update`; they are not edited manually.

## Artifact workflow

```text
proposal
├── specs
└── research
     └── design
specs + design
     └── review
specs + design + review
     └── tasks
tasks
     └── apply
```

The generated artifacts are `proposal.md`, `specs/**/*.md`, `research.md`, `design.md`, `review.md`, and `tasks.md`.

## Validate a consumer

From an installed consumer repository:

```powershell
./scripts/Invoke-OpenSpecSddGuard.ps1
```

Or invoke the engine explicitly:

```powershell
./tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1 `
  -ProjectRoot <consumer-project> `
  -ContractRoot <consumer-project>
```

The guard discovers one root solution, validates the .NET 10 and architecture baselines, runs restore/build/tests/coverage, and lints active OpenAPI contracts. HTTP consumers require an active contract; non-HTTP consumers report OpenAPI as not applicable.

## Validate this package repository

```powershell
./scripts/Test-OpenSpecDotNetSddPackage.ps1
```

This gate validates OpenSpec, package structure and consistency, forbidden references, secrets and local paths, guard fixtures, and installer fixtures. It does not require a real application in this repository.

## Distribution and legacy status

`distribution/openspec/dotnet-sdd/` is the supported installable artifact. The root schema, governance, guard, wrapper, and skills are kept byte-consistent with their distributed counterparts by the package gate.

Everything under `legacy/spec-kit/` is `LEGACY`, `UNSUPPORTED`, and `NOT USED BY THE CURRENT OPENSPEC WORKFLOW`. It is retained only as historical evidence for the reusable framework.

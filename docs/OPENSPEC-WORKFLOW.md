# OpenSpec Workflow

This repository develops and distributes one reusable OpenSpec schema: `dotnet-sdd`. Project context and per-artifact rules live in `openspec/config.yaml`; the detailed .NET policy lives only in `docs/architecture/dotnet-sdd-governance.md`.

OpenSpec 1.7.0 is the minimum supported version. There is no application baseline or durable business capability in this repository. Consumer specifications and active contracts belong to the repository where the package is installed.

## Terminal commands

```powershell
openspec init . --tools 'codex,github-copilot' --force
openspec update
openspec schemas
openspec list
openspec status --change <change-name>
openspec validate --all --strict
```

`openspec init` and `openspec update` generate the assistant integrations. Never hand-edit `.codex/skills/openspec-*`, `.github/skills/openspec-*`, or `.github/prompts/opsx-*`.

## Artifact graph

`proposal` enables `specs` and `research`; `research` enables `design`; `specs` plus `design` enable `review`; `specs`, `design`, and `review` enable `tasks`; `tasks` enable `apply`.

Specifications contain observable behavior. Research and design contain implementation choices. Review blocks task generation when material gaps or conflicts remain.

## Assistant usage

Codex uses `$openspec-propose`, `$openspec-explore`, `$openspec-update-change`, `$openspec-apply-change`, `$openspec-sync-specs`, and `$openspec-archive-change`.

GitHub Copilot exposes `/opsx-propose`, `/opsx-explore`, `/opsx-update`, `/opsx-apply`, `/opsx-sync`, and `/opsx-archive`.

## Explicit quality gates

For this distribution repository:

```powershell
./scripts/Test-OpenSpecDotNetSddPackage.ps1
```

For an installed consumer:

```powershell
./scripts/Invoke-OpenSpecSddGuard.ps1
```

The package gate validates schema, templates, configuration, distribution consistency, fixture tests, and repository hygiene. The consumer gate validates OpenSpec, audits secrets and local markers, and invokes the .NET guard against the consumer project.

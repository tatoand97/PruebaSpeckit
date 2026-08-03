# OpenSpec Workflow

The repository uses one root OpenSpec project with default schema `dotnet-sdd`. Project context and per-artifact rules live in `openspec/config.yaml`; detailed governance lives only in `docs/architecture/dotnet-sdd-governance.md`.

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

## Agent chat

- Propose or explore a change.
- Create/update the artifacts allowed by the dependency graph.
- Apply approved tasks.
- Synchronize durable capability specs.
- Verify, then archive the completed change.

Codex uses the generated skills such as `$openspec-propose`; it does not use terminal slash commands. GitHub Copilot exposes the generated `/opsx-*` prompt files.

## Explicit quality gate

```powershell
./scripts/Invoke-OpenSpecSddGuard.ps1
```

The command validates OpenSpec, scans for high-confidence secrets and local absolute paths, restores and builds with warnings as errors, executes unit tests and coverage, enforces architecture and platform rules, and lints all retained OpenAPI contracts with Redocly CLI `2.41.1`.

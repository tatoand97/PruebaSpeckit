# GitHub Copilot repository instructions

- Use the single repository-root OpenSpec installation as the active SDD workflow.
- Treat `docs/architecture/dotnet-sdd-governance.md` as the authority for architecture, security, contracts, and Definition of Done.
- Use the project-local `dotnet-sdd` schema selected by `openspec/config.yaml`.
- In Copilot chat, use the generated `/opsx-propose`, `/opsx-explore`, `/opsx-update`, `/opsx-apply`, `/opsx-sync`, and `/opsx-archive` prompts or the corresponding `openspec-*` skills.
- Do not edit `.github/skills/openspec-*` or `.github/prompts/opsx-*`; regenerate them with `openspec update`.
- Keep behavioral requirements in capability specs and implementation decisions in research/design artifacts.
- Do not silently change a specification to match code. Resolve inconsistencies in the appropriate artifact.
- Before implementation, require sufficient proposal, specs, research, design, review, and executable tasks for the change's risk.
- Run `openspec validate --all --strict` and `./scripts/Invoke-OpenSpecSddGuard.ps1` before claiming completion.
- Use `.github/skills/dotnet-sdd-verify` for explicit gate verification; it is custom and not managed by OpenSpec.
- Use .NET 10 and PowerShell for repository-owned automation. Preserve existing application behavior unless an approved capability delta changes it.
- Do not use multi-agent execution by default. Use it only for a concrete, documented, genuinely independent need.

## Repository discovery

- Prefer the codebase knowledge graph for architecture, symbols, callers, dependencies, impact, routes, and boundaries.
- Query the graph, identify candidate files, then read actual source before modifying it.
- Fall back to text search for literals, errors, configuration, scripts, and non-code files or when graph results are insufficient.
- Use current official primary documentation for version-sensitive external APIs and clearly distinguish verified facts from inference.

## OpenSpec surfaces

- Terminal: `openspec init`, `openspec update`, `openspec list`, `openspec status`, `openspec schemas`, and `openspec validate`.
- Copilot chat: `/opsx-propose`, `/opsx-explore`, `/opsx-update`, `/opsx-apply`, `/opsx-sync`, and `/opsx-archive`.
- The deterministic gate is explicit; OpenSpec does not run it as an automatic post-implementation hook.

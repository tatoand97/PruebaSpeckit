# GitHub Copilot repository instructions

- Maintain the reusable `dotnet-sdd` framework as the only active product.
- Use the single repository-root OpenSpec installation and project-local `dotnet-sdd` schema.
- Treat `docs/architecture/dotnet-sdd-governance.md` as the authority for architecture, security, contracts, and Definition of Done.
- Require OpenSpec 1.7.0 or a compatible newer 1.x release.
- Use the generated `/opsx-propose`, `/opsx-explore`, `/opsx-update`, `/opsx-apply`, `/opsx-sync`, and `/opsx-archive` prompts or their corresponding skills.
- Do not edit `.github/skills/openspec-*` or `.github/prompts/opsx-*`; regenerate them with `openspec update`.
- Keep behavioral requirements in capability specs and implementation decisions in research/design artifacts.
- Do not create a demonstration application or product-specific capability in this repository.
- Run `openspec validate --all --strict` and `./scripts/Test-OpenSpecDotNetSddPackage.ps1` before claiming completion.
- Use `.github/skills/dotnet-sdd-verify` for explicit verification.
- Keep root and distribution copies synchronized.
- Treat `legacy/spec-kit/` as unsupported historical evidence that never participates in current gates.

## Repository discovery

- Prefer the codebase knowledge graph for architecture, symbols, callers, dependencies, impact, routes, and boundaries.
- Query the graph, identify candidate files, then read actual source before modifying it.
- Fall back to text search for literals, errors, configuration, scripts, and non-code files or when graph results are insufficient.
- Use official primary documentation for version-sensitive external APIs and distinguish verified facts from inference.

## Verification surfaces

- Package repository: `./scripts/Test-OpenSpecDotNetSddPackage.ps1`.
- Installed consumer: `./scripts/Invoke-OpenSpecSddGuard.ps1`.
- Direct engine: `./tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1 -ProjectRoot <consumer-project>`.

The deterministic gates are explicit; OpenSpec does not run them as automatic post-implementation hooks.

# Repository agent guidance

## Active SDD system

Use the single root `openspec/` tree and its `dotnet-sdd` schema. The canonical policy is `docs/architecture/dotnet-sdd-governance.md`; summarize or link it rather than duplicating it.

For Codex, invoke OpenSpec through `.codex/skills/openspec-*` (for example `$openspec-propose`, `$openspec-explore`, `$openspec-update-change`, `$openspec-apply-change`, `$openspec-sync-specs`, and `$openspec-archive-change`). Do not use terminal-style `/opsx:*` syntax in Codex. Regenerate managed skills with `openspec update`; never edit them manually.

Use `openspec` terminal commands for state and validation: `openspec list`, `openspec status`, `openspec schemas`, and `openspec validate`. Run `./scripts/Invoke-OpenSpecSddGuard.ps1` before completion.

## Code discovery

Always prefer codebase-memory graph tools over broad code search:

1. `search_graph` for functions, classes, routes, and variables.
2. `trace_path` for callers, callees, impact, and data flow.
3. `get_code_snippet` after resolving the exact qualified name.
4. `query_graph` for complex relationships.
5. `get_architecture` for a high-level view.

Fall back to text search for literals, error messages, configuration, scripts, non-code files, or insufficient graph results. Read actual source before editing it.

## Boundaries

- Keep behavior in specs and technical choices in research/design.
- Preserve existing application behavior unless an approved capability delta changes it.
- Do not create a nested OpenSpec installation under `PoCFinal`.
- Do not introduce parallel agent work without a concrete, documented reason.
- Treat everything under `legacy/spec-kit/` and `docs/sdd-history/spec-kit/` as read-only historical evidence, not active instructions.

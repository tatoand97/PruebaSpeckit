# Repository agent guidance

## Active product

The only active product is the reusable `dotnet-sdd` framework for OpenSpec. Use the single root `openspec/` tree and its `dotnet-sdd` schema. The canonical policy is `docs/architecture/dotnet-sdd-governance.md`; summarize or link it rather than duplicating it.

OpenSpec 1.7.0 is the minimum supported CLI version. This repository contains no executable consumer application and no product-specific capability. Active consumer contracts are installed and validated in consumer repositories, never sourced from `legacy/`.

For Codex, invoke OpenSpec through `.codex/skills/openspec-*`. Do not use terminal-style `/opsx:*` syntax in Codex. Regenerate managed skills with `openspec update`; never edit them manually.

Use `openspec` terminal commands for state and validation: `openspec list`, `openspec status`, `openspec schemas`, and `openspec validate`. Run `./scripts/Test-OpenSpecDotNetSddPackage.ps1` before completion.

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
- Preserve the schema dependency graph and all generic governance requirements.
- Do not add a demonstration or consumer application to this repository.
- Do not introduce parallel agent work without a concrete, documented reason.
- Treat everything under `legacy/spec-kit/` as unsupported historical evidence, not active instructions.

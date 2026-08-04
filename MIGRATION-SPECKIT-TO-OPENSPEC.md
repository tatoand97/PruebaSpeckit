# Migration to the Reusable OpenSpec .NET SDD Artifact

## Scope decision

The repository now distributes only the reusable `dotnet-sdd` framework for OpenSpec. The former demonstration application was removed by scope decision, together with its contact-registration capability, implementation evidence, coverage, contracts, and historical feature documents. No demonstration application is included.

The active product consists of:

- the `dotnet-sdd` OpenSpec schema and templates;
- generic configuration and .NET SDD governance;
- a reusable deterministic guard for consumer projects;
- Codex and GitHub Copilot skills;
- a PowerShell installer;
- synthetic guard and installer fixtures;
- package documentation; and
- CI that validates the package rather than an embedded application.

## Migration mapping

The reusable framework was migrated from the former preset, workflow, extension, bundle, catalogs, guard, harness knowledge, distribution scripts, and agent skills. Only reusable historical material remains under `legacy/spec-kit/`.

The active OpenSpec project is the single root `openspec/` tree. No nested installation or second active SDD system remains. Historical assets are marked `LEGACY`, `UNSUPPORTED`, and `NOT USED BY THE CURRENT OPENSPEC WORKFLOW` at the directory boundary.

## Guard redesign

`tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1` operates on an explicit consumer `-ProjectRoot`, with optional `-ContractRoot` and output `-EvidencePath`. Evidence location never bypasses command execution. The engine does not assume a solution name, module name, business capability, or fixed contract.

The engine validates solution discovery, .NET 10, project-reference direction, persistence ownership, prohibited EF Core migrations, HTTP use of Wolverine mediator-only mode, Minimal APIs, Problem Details, Azure App Configuration, restore, warning-free Release build, unit tests, business-layer coverage, active OpenAPI contracts, and sanitized evidence.

Active OpenAPI discovery is limited to:

- `openspec/specs/**/contracts/openapi.yaml`;
- non-archived `openspec/changes/**/specs/**/contracts/openapi.yaml`; and
- `docs/contracts/**/openapi.yaml`.

HTTP consumers without an active contract fail. OpenAPI is not applicable for a non-HTTP consumer.

## Package gate and tests

The former repository-to-application gate was replaced by `scripts/Test-OpenSpecDotNetSddPackage.ps1`. It validates OpenSpec, required package files, root/distribution consistency, residual references, secrets, local paths, guard fixtures, and installer fixtures. It does not require a .NET solution in this repository.

Guard tests create and remove temporary synthetic consumer projects. They cover a valid modular project, architecture and persistence failures, prohibited migrations, HTTP configuration failures, OpenAPI discovery and linting, build/test/coverage failures, non-HTTP behavior, and evidence sanitization. No removed application is copied as a fixture.

Installer tests use temporary consumer repositories. The installer validates Node.js and OpenSpec compatibility, performs collision preflight, supports timestamped backups, preserves identical reinstallations, generates requested official integrations, installs the reusable payload, and validates the installed schema without Python, `uv`, or the former SDD runtime.

## Harness decision

The active evaluation harness was removed. It was coupled to application-specific evidence paths and did not add an independent package guarantee beyond explicit schema, installer, and guard results. The reusable historical harness remains only under `legacy/spec-kit/` as unsupported evidence.

## CI decision

CI installs pinned Node.js and OpenSpec versions, configures .NET 10 for synthetic fixtures, validates the schema and strict OpenSpec state, runs guard and installer tests, audits secrets and residual references, and executes the package gate. It does not restore, build, test, or lint an embedded application.

## Validation status

Results from the completed local run:

- OpenSpec CLI: PASS, version 1.7.0.
- Schema resolution and validation: PASS; six templates resolved.
- Strict OpenSpec validation: PASS; no active changes or capability specs require validation.
- Package consistency and hygiene gate: PASS across 63 active repository text files.
- Guard fixtures: PASS, 36/36.
- Installer fixtures: PASS, 11/11.
- Local validation: PASS.
- GitHub Actions validation: NOT RUN.

No push, force push, release, or pull request is part of this migration adjustment.

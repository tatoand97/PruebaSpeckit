# PoCFinal Copilot instructions

Use the repository-root OpenSpec workflow; do not initialize another OpenSpec root inside `PoCFinal`.

The complete policy is `../../docs/architecture/dotnet-sdd-governance.md`. Preserve the .NET 10 modular-monolith boundaries, Minimal APIs, Wolverine mediator-only mode, repositories, FluentValidation, Problem Details, OpenAPI, privacy controls, warning-free Release build, tests, and coverage defined there.

Use the generated root `.github/skills/openspec-*` and `.github/prompts/opsx-*` artifacts. Run verification from the repository root with `../../scripts/Invoke-OpenSpecSddGuard.ps1` or the custom `dotnet-sdd-verify` skill. Do not duplicate governance or tooling under this application directory.

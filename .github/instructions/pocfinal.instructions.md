---
applyTo: "PoCFinal/**"
---

# PoCFinal instructions

Use the single repository-root OpenSpec project; do not initialize OpenSpec inside `PoCFinal`.

Preserve the .NET 10 modular monolith and its Domain, Application, Infrastructure, and Presentation layers. Use Minimal APIs, Wolverine in `MediatorOnly` mode, the Repository Pattern, FluentValidation, and Problem Details.

Keep the active HTTP contract at `openspec/specs/contact-requests/contracts/openapi.yaml`. The canonical policy is `docs/architecture/dotnet-sdd-governance.md`; link it instead of duplicating it. From the repository root, run `./scripts/Invoke-OpenSpecSddGuard.ps1` before claiming completion.

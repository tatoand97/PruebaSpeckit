# GitHub Copilot repository instructions

- Use GitHub Spec Kit as the repository's Spec-Driven Development workflow.
- Treat `.specify/memory/constitution.md` as the governing authority.
- Keep `spec.md` focused on what and why, `plan.md` on how, and `tasks.md` on executable work.
- Do not change a specification silently to make it match the code; surface and resolve the gap.
- Use .NET 10 and follow the existing modular architecture and project dependency directions.
- Use Minimal APIs and delegate application work through Wolverine mediator.
- Add only abstractions justified by a requirement or concrete technical need.
- After code changes, run the applicable restore, Release build, unit tests and coverage checks.
- Validate HTTP OpenAPI statically with
  `npx --yes @redocly/cli@2.41.1 lint specs/<feature>/contracts/openapi.yaml`, then compare it
  separately with implemented behavior.
- Keep known module failure mapping in `Module.Presentation`; keep only unexpected cross-cutting
  fallback handling in `Common.Presentation`, which must not reference `Modules.*`.
- Integrate Azure App Configuration in code with its ASP.NET Core provider,
  `DefaultAzureCredential` and an externally supplied endpoint; skip remote provider activation
  when the endpoint is absent so local restore, build and unit tests remain offline-capable.
- Do not use EF Core Migrations, `dotnet-ef`, schema snapshots, database update commands or
  `EnsureCreated()` as a replacement policy.
- Never expose or log secrets, tokens or unnecessary sensitive information.
- Avoid multi-agent execution by default and keep model context reasonably small.
- Repository exploration policy

  For structural questions about the current repository, prefer codebase-memory-mcp before broad grep, glob, or file traversal.
  Use it for architecture discovery, symbol search, callers/callees, implementation relationships, dependency impact, HTTP route relationships, and locating candidate files.
  After locating candidate code with the graph, read the actual source files before editing.
  Never modify code solely from graph-derived information.

- External documentation policy

  Use Context7 only when current external library or API documentation is required.
  Typical cases include unfamiliar or version-sensitive APIs, package configuration, framework integration, APIs that may have changed, or build/runtime issues caused by package usage.
  Do not call Context7 for business requirements, project-local architecture already documented, ordinary repository navigation, or information already available in local source or docs.

- Context discipline

  Do not retrieve context merely because an MCP tool exists.
  Use the smallest sufficient context.
  Prefer graph query -> identify candidate symbols/files -> read only relevant files over recursive repository search and manual architecture inference.
  Do not call both repository search and codebase-memory for the same question unless the graph result is insufficient or needs verification.

- SDD integration policy

  For specify and review-spec, keep Context7 and codebase-memory off by default.
  For plan and review-plan, use codebase-memory for brownfield work and Context7 only when external API or library knowledge is needed.
  For tasks and implement, use codebase-memory first for brownfield discovery, then read source before editing; use Context7 only when documentation is actually required.
  For analyze and converge, use codebase-memory for impact and gap discovery, and keep Context7 normally off unless an external library question is part of the task.

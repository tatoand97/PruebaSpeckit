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

  For structural questions about the current repository, prefer the smallest sufficient local context before broad grep, glob, or file traversal.
  Use it for architecture discovery, symbol search, callers/callees, implementation relationships, dependency impact, HTTP route relationships, and locating candidate files.
  After locating candidate code, read the actual source files before editing.
  Never modify code solely from inferred relationships.

- External documentation policy

  Use official external documentation only when current library or API references are required.
  Typical cases include unfamiliar or version-sensitive APIs, package configuration, framework integration, APIs that may have changed, or build/runtime issues caused by package usage.
  Do not use external documentation for business requirements, project-local architecture already documented, ordinary repository navigation, or information already available in local source or docs.

- Context discipline

  Do not retrieve context merely because an integration exists.
  Use the smallest sufficient context.
  Prefer targeted discovery -> identify candidate symbols/files -> read only relevant files over recursive repository search and manual architecture inference.
  Do not run multiple discovery approaches for the same question unless the first result is insufficient or needs verification.

- SDD integration policy

  For specify and review-spec, keep external documentation tools off by default.
  For plan and review-plan, use local repository context for brownfield work and external docs only when API or library knowledge is needed.
  For tasks and implement, use local repository context first for brownfield discovery, then read source before editing; use external docs only when documentation is actually required.
  For analyze and converge, use local repository context for impact and gap discovery, and keep external docs normally off unless an external library question is part of the task.

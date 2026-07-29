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

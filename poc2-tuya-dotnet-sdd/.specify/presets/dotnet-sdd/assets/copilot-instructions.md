# GitHub Copilot repository instructions

- Use GitHub Spec Kit as the repository's Spec-Driven Development workflow.
- Treat `.specify/memory/constitution.md` as the governing authority.
- Keep `spec.md` focused on what and why, `plan.md` on how, and `tasks.md` on executable work.
- Do not change a specification silently to make it match the code; surface and resolve the gap.
- Use .NET 10 and follow the existing modular architecture and project dependency directions.
- Use Minimal APIs and delegate application work through Wolverine mediator.
- Add only abstractions justified by a requirement or concrete technical need.
- After code changes, run the applicable restore, Release build, unit tests and coverage checks.
- Keep OpenAPI consistent with implemented HTTP behavior and relevant errors.
- Never expose or log secrets, tokens or unnecessary sensitive information.
- Avoid multi-agent execution by default and keep model context reasonably small.

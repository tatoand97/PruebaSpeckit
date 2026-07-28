# GitHub Copilot repository instructions

- Use GitHub Spec Kit as the default Spec-Driven Development (SDD) workflow for this repository.
- Follow the rules established in `.specify/memory/constitution.md`; they govern development in this repository.
- For production features, follow this workflow: constitution → specify → clarify → plan → checklist → tasks → analyze → implement → converge.
- Treat `spec.md` as the definition of what must be built.
- Treat `plan.md` as the definition of how the feature will be built.
- Treat `tasks.md` as the executable work breakdown.
- Never change a specification silently to make it match the implementation. Surface inconsistencies and resolve them explicitly.
- Before implementing a feature, ensure that its specification, plan, and task breakdown are sufficient, unless the user explicitly requests a direct change.
- Use .NET 10 as the primary development stack.
- Prefer PowerShell for repository-owned automation scripts.
- Use the available Agent Skills only when they are relevant to the current task.
- Do not use multi-agent execution or parallelization by default. Reserve subagents for specialized work or work that is genuinely parallelizable.
- Keep the context sent to the model as small as reasonably possible.
- After code changes, run the applicable build and tests before considering the task complete.

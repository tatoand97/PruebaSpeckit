# GitHub Copilot repository instructions

- Use GitHub Spec Kit as the default Spec-Driven Development (SDD) workflow for this repository.
- Follow the rules established in `.specify/memory/constitution.md`; they govern development in this repository.
- For production features, use this reference workflow: constitution → specify → clarify → plan → checklist → tasks → analyze → implement → converge.
- Use clarify, checklist, and analyze when ambiguity, complexity, or risk makes them valuable; avoid unnecessary ceremony for trivial changes.
- Treat `spec.md` as the definition of what must be built.
- Treat `plan.md` as the definition of how the feature will be built.
- Treat `tasks.md` as the executable work breakdown.
- Never change a specification silently to make it match the implementation. Surface inconsistencies and resolve them explicitly.
- Before implementing a production feature, ensure that its specification, plan, and task breakdown are sufficient. Direct changes may skip phases only when they are trivial and do not redefine production behavior.
- Use .NET 10 as the primary development stack.
- Prefer PowerShell for repository-owned automation scripts.
- Use the available Agent Skills only when they are relevant to the current task.
- Do not use multi-agent execution or parallelization by default. Reserve subagents for specialized work or work that is genuinely parallelizable.
- Keep the context sent to the model as small as reasonably possible.
- After code changes, run the applicable build and tests before considering the task complete.
- Repository exploration policy

	For structural questions about this repository, prefer codebase-memory-mcp before broad grep, glob, or file traversal.
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

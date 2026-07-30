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
- Repository intelligence policy

	For structural questions about the current repository, prefer Graphify before broad grep, glob, recursive file traversal, or opening many source files.
	Use it for architecture discovery, dependency relationships, symbol relationships, callers/callees when represented in the graph, impact analysis, locating candidate files, and identifying subsystem boundaries.
	Preferred flow: Graphify graph query -> identify candidate nodes/files -> inspect relationships when necessary -> read only the actual source/configuration files needed -> make conclusions.
	Always read the actual source/configuration file before modifying it.
	Never modify source solely from graph-derived information.
	Do not repeatedly reformulate equivalent graph queries.
	Use the smallest sufficient graph query.
	Do not use both Graphify and broad repository search for the same question unless Graphify is insufficient.

- External documentation policy

	Use Context7 only when current external library or API documentation is required.
	Typical cases include unfamiliar or version-sensitive APIs, package configuration, framework integration, APIs that may have changed, or build/runtime issues caused by package usage.
	Do not call Context7 for business requirements, project-local architecture already documented, ordinary repository navigation, or information already available in local source or docs.

- Context discipline

	Do not retrieve context merely because an MCP tool exists.
	Use the smallest sufficient context.
	Prefer graph query -> identify candidate symbols/files -> read only relevant files over recursive repository search and manual architecture inference.
	Do not call both repository search and Graphify for the same question unless the graph result is insufficient or needs verification.

- SDD integration policy

	For specify and review-spec, keep Graphify and Context7 off by default.
	For plan and review-plan, use Graphify for brownfield work and Context7 only when external API or library knowledge is needed.
	For tasks and implement, use Graphify first for brownfield discovery, then read source before editing; use Context7 only when documentation is actually required.
	For analyze and converge, use Graphify for impact and gap discovery, and keep Context7 normally off unless an external library question is part of the task.

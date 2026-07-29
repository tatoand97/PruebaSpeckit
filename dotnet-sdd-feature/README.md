# .NET SDD Feature

Experimental workflow `dotnet-sdd-feature` version `0.1.0`.

## Purpose

Automate the STANDARD flow for a feature governed by `dotnet-sdd`. The workflow
orchestrates official Spec Kit commands; it does not redefine their behavior or
duplicate the preset's architecture, templates, testing rules, or Definition of
Done.

## Prerequisites

- Spec Kit `>= 0.14.3`.
- A project already initialized with Spec Kit.
- An initialized project Constitution.
- `dotnet-sdd >= 1.0.1` already installed and enabled.
- Either the GitHub Copilot CLI or Codex CLI integration available for
  non-interactive command dispatch.
- For Codex-based validation, a Git repository and workspace-write permission
  for the non-interactive Codex process.

The workflow does not install or enable `dotnet-sdd`.

## Installation

From an initialized consumer project, install this directory in development
mode:

```powershell
specify workflow add --dev ../dotnet-sdd-feature
```

## Verify

```powershell
specify workflow list
specify workflow info dotnet-sdd-feature
specify workflow resolve dotnet-sdd-feature
```

`resolve` is available in Spec Kit 0.14.3 and shows the workflow plus any enabled
overlay attribution.

## Run

GitHub Copilot is the target corporate consumer:

```powershell
specify workflow run dotnet-sdd-feature `
  -i spec="Construir una funcionalidad para..." `
  -i integration=copilot
```

Codex remains supported for PoC validation:

```powershell
specify workflow run dotnet-sdd-feature `
  -i spec="Construir una funcionalidad para..." `
  -i integration=codex
```

The `integration` input accepts only `copilot` or `codex`; its default is
`copilot`. No model selection or architecture parameters are exposed.

## Human gates

The STANDARD flow pauses for three mandatory approvals:

1. **Specification** (`review-spec`): review `spec.md` and confirm it represents
   the functional need before technical design begins. If `speckit.clarify`
   surfaced an unanswered question in the agent output, do not approve; resolve
   it and rerun the workflow.
2. **Technical Design** (`review-plan`): review `plan.md`, `research.md`,
   `data-model.md`, `contracts/`, and `checklists/` when present, then decide
   whether the design and contracts are mature enough for task generation.
3. **Implementation Readiness** (`review-readiness`): approve only when the
   specification, plan, and tasks are consistent and mature enough for code
   changes. Do not approve while `speckit.analyze` has blocking findings.

Rejecting any mandatory gate aborts the run. In a non-interactive execution, a
gate persists the run in the paused state. Resume it with:

```powershell
specify workflow resume <run_id>
```

## Flow

```text
speckit.specify
→ speckit.clarify
→ [Specification Gate]
→ speckit.plan
→ speckit.checklist
→ [Technical Design Gate]
→ speckit.tasks
→ speckit.analyze
→ [Implementation Readiness Gate]
→ speckit.implement
→ speckit.converge
→ [Convergence Gate]
```

## Convergence handling

Spec Kit 0.14.3 command steps expose dispatch metadata, `exit_code`, `stdout`,
and `stderr`. The `speckit.converge` command reports either `converged` or
`tasks_appended` through the agent's in-session narrative; it does not expose a
documented, stable structured convergence result to the workflow engine.

For that reason, version 0.1.0 does not parse agent text and does not implement
an automatic loop. The final `review-convergence` gate requires the operator to:

- approve and finish if converge reported **Converged**; or
- reject and abort if converge appended tasks, complete those tasks through the
  corresponding flow, and run the workflow or convergence flow again.

Known limitation: automatic implement/converge looping awaits a stable
structured convergence result from Spec Kit.

## Responsibilities

```text
dotnet-sdd
    = rules, templates, Definition of Done, and architecture

dotnet-sdd-feature
    = sequence and orchestration

future dotnet-sdd-guard
    = deterministic enforcement
```

Spec Kit Core and the installed `dotnet-sdd` preset remain the sources of
command behavior. This workflow supplies no parallel architectural instructions
and runs no project initialization or Constitution command.

## Out of scope

- deterministic shell quality gates;
- extensions;
- bundle or bootstrap installation;
- FAST or HIGH-RISK modes;
- CI/CD and deployment;
- MCP or Context7;
- multi-agent orchestration.

Version 0.1.0 intentionally contains no shell steps.

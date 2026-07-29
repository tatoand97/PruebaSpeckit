# .NET SDD Feature

Experimental workflow `dotnet-sdd-feature` version `0.1.1`.

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

The STANDARD flow pauses for four mandatory approvals:

1. **Specification** (`review-spec`): review `spec.md` and confirm it represents
  the functional need before technical design begins. Use
  `speckit.clarify` manually when the specification has material ambiguities or
  when the operator cannot approve the gate responsibly.
2. **Technical Design** (`review-plan`): review `plan.md`, `research.md`,
  `data-model.md`, and `contracts/` when present, then decide whether the
  design and contracts are mature enough for task generation. Use
  `speckit.checklist` manually when the feature is especially sensitive or
  needs a formal extra review.
3. **Implementation Readiness** (`review-readiness`): approve only when the
  specification, plan, and tasks are consistent and mature enough for code
  changes. `speckit.analyze` runs once automatically before this gate; if the
  findings are blocking, correct the source artifacts deliberately and rerun
  `speckit.analyze` only when you need a fresh check.
4. **Convergence** (`review-convergence`): approve only when `speckit.converge`
  reports that the workflow converged. If it appends tasks, decide manually how
  to continue; do not rely on an automatic retry loop.

Rejecting any mandatory gate aborts the run. In a non-interactive execution, a
gate persists the run in the paused state. Resume it with:

```powershell
specify workflow resume <run_id>
```

## Flow

```text
speckit.specify
→ [Specification Gate]
→ speckit.plan
→ [Technical Design Gate]
→ speckit.tasks
→ speckit.analyze
→ [Implementation Readiness Gate]
→ speckit.implement
→ after_implement hook: dotnet-sdd-guard
→ speckit.converge
→ [Convergence Gate]
```

## Standard path

```text
specify
→ gate
→ plan
→ gate
→ tasks
→ analyze
→ gate
→ implement
→ guard
→ converge
→ gate
```

## Optional quality commands

- `speckit.clarify`: manual / conditional, for material ambiguities in
  `spec.md`.
- `speckit.checklist`: manual / conditional, for especially sensitive or
  complex design reviews.
- Additional `speckit.analyze`: manual / operator decision, when a fresh check
  is justified after deliberate corrections.

## Why

This workflow keeps STANDARD execution bounded so it does not turn quality
review into an autonomous remediation loop. The goal is to reduce long agentic
sessions, lower token and premium request consumption, preserve human decision
points, and reserve extra review work for features that actually need it.

## Convergence handling

Spec Kit 0.14.3 command steps expose dispatch metadata, `exit_code`, `stdout`,
and `stderr`. The `speckit.converge` command does not currently expose a
documented, stable structured convergence outcome to the workflow engine.

For that reason, version 0.1.1 does not parse agent text and does not implement
an automatic loop. The final `review-convergence` gate requires the operator to
approve and finish when converge reports **Converged**, or to decide manually
how to proceed when tasks are appended.

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

The mandatory guard is provided by the `dotnet-sdd-guard` after-implement hook;
the workflow does not duplicate that step.

## Out of scope

- deterministic shell quality gates;
- extensions;
- bundle or bootstrap installation;
- FAST or HIGH-RISK modes;
- CI/CD and deployment;
- MCP or Context7;
- multi-agent orchestration.

Version 0.1.1 intentionally contains no shell steps.

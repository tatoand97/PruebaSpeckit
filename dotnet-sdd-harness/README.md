# .NET SDD Harness

`dotnet-sdd-harness` 0.1.1 is evaluation tooling. It is not a Spec Kit preset,
workflow, extension, or bundle, and must not be installed into normal developer
projects.

The Harness observes persisted workflow state, Guard output, and framework metadata.
It measures and reports; it does not execute or orchestrate workflows.

Responsibilities are intentionally separated:

- `dotnet-sdd-feature` executes and orchestrates;
- `dotnet-sdd-guard` validates;
- `dotnet-sdd-harness` observes, measures, and reports.

## Interactive workflow limitation

Spec Kit workflows with gate steps require an interactive operator context.

`dotnet-sdd-harness` does not provide gate input and does not execute `specify
workflow run` or `specify workflow resume`. The workflow must be run from an
interactive operator context. The Harness observes the persisted workflow state.

This limitation and responsibility boundary apply equally to Codex and GitHub
Copilot integrations. The Harness never approves or rejects gates, supplies stdin,
answers clarification questions, re-runs Guard checks, or uses an LLM.

## Evaluator workflow

### 1. Start the evaluation

Starting an evaluation immediately creates a durable Evaluation ID and metadata.
It does not start a workflow.

```powershell
$evaluation = & "./scripts/Start-SddEvaluation.ps1" `
  -ProjectRoot "." `
  -WorkflowId "dotnet-sdd-feature" `
  -Integration "codex" `
  -ScenarioId "contact-request-v1"
```

The public `-StartWorkflow` and `-Description` parameters from 0.1.0 were removed.

### 2. Run the workflow externally

Run it from an interactive operator context:

```powershell
specify workflow run dotnet-sdd-feature `
  -i spec="..." `
  -i integration=codex
```

Record the Workflow Run ID returned by Spec Kit.

### 3. Attach the persisted run

```powershell
& "./scripts/Attach-SddWorkflowRun.ps1" `
  -ProjectRoot "." `
  -EvaluationId $evaluation.evaluationId `
  -RunId "<run-id>"
```

Attachment is explicit. The Harness never guesses the latest run. Before writing
the association, it verifies that `state.json` exists, its `run_id` and
`workflow_id` match, and its integration matches when reliable persisted integration
metadata is available. Any persisted run state can be attached, including `paused`,
`completed`, `failed`, and `aborted`. `state.json` is never changed.

### 4. Operate gates externally

Approve or reject gates and use `specify workflow resume` from the interactive
operator context as needed. The Harness does not participate.

### 5. Inspect the evaluation

```powershell
& "./scripts/Get-SddEvaluation.ps1" `
  -ProjectRoot "." `
  -EvaluationId $evaluation.evaluationId
```

Before attachment, inspection returns `evaluationStatus = started`,
`workflowStatus = not_started`, and `guardResult = not_available`.

### 6. Export the acceptance report

```powershell
& "./scripts/Export-SddAcceptanceReport.ps1" `
  -ProjectRoot "." `
  -EvaluationId $evaluation.evaluationId
```

The canonical JSON and sanitized Markdown reports are stored inside the selected
evaluation directory.

## Persistence model

Each evaluation has an independent directory:

```text
artifacts/sdd-evaluation/
├── current.json
└── <evaluationId>/
    ├── evaluation.json
    ├── sdd-acceptance.json
    └── sdd-acceptance.md
```

`evaluation.json` uses evaluation metadata schema 1.1 and is persisted before any
workflow is run. It contains a random Evaluation ID independent of Scenario ID and
Workflow Run ID, Harness version 0.1.1, non-functional identifiers and timestamps,
and `runId = null` until explicit attachment.

`current.json` contains only an Evaluation ID and provides single-evaluation
ergonomics when `-EvaluationId` is omitted from inspect/export. Passing
`-EvaluationId` is recommended for history, parallel evaluations, and automation.
No path in the schema depends on an absolute project path.

The Acceptance Report remains schema 1.0; Harness versioning is independent from
the report schema version.

## Objective result rules

- `INCOMPLETE`: no run is attached, or the workflow is paused/running/non-terminal.
- `REJECTED`: the workflow is `aborted` and persisted gate output explicitly records
  `choice = reject` and `aborted = true`.
- `FAILED`: the workflow is `failed`; an abort lacks structured gate-rejection
  evidence; a completed workflow has no Guard result; Guard is `FAIL` or `ERROR`;
  or another blocking framework failure prevents acceptance.
- `ACCEPTED`: only when the workflow is `completed`, Guard is `PASS`, and no blocking
  framework execution error exists.

Spec Kit 0.14.3 does not provide a general structured cause for every aborted run.
The Harness therefore classifies an abort as `REJECTED` only with explicit persisted
gate-rejection evidence. Other aborts are `FAILED`; it never invents rejection
causality or changes an aborted run back to paused.

Guard 1.0 does not persist a Workflow Run ID. To avoid treating stale Guard output
as evidence for a non-terminal run, the Harness consumes Guard output only after the
selected workflow is `completed`.

Reports can always be generated for:

- workflow not started;
- workflow paused or otherwise non-terminal;
- workflow aborted with or without structured rejection evidence;
- workflow failed;
- workflow completed without Guard;
- workflow completed with Guard `FAIL`, `ERROR`, or `PASS`.

## Privacy

Reports contain identifiers, statuses, counters, versions, and normalized environment
facts only. They exclude descriptions, requirement/story/task text, command output,
source, secrets, payloads, remote URLs, absolute paths, usernames, and private domain
names. Evaluation ID and Workflow Run ID are safe random/opaque identifiers and may
appear.

AI usage defaults to `not_available`. Optional manual/external metrics may be supplied
as JSON with `source` equal to `manual` or `external`; only allowlisted numeric metrics
and a three-letter currency code are exported.

## Tests

```powershell
& "./tests/Invoke-HarnessTests.ps1"
```

Fixtures are synthetic and deterministic. Tests do not invoke Spec Kit, a real
workflow, an agent, Guard, or an LLM.

## Complete flow for the next final PoC

Do not run this non-interactively:

```text
Start Evaluation
      ↓
Run Workflow interactively
      ↓
Attach Run ID
      ↓
Operate gates/resume
      ↓
Guard runs via hook
      ↓
Workflow completed
      ↓
Export Acceptance Report
```

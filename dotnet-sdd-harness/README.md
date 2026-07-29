# .NET SDD Harness

`dotnet-sdd-harness` 0.1.0 is evaluation tooling. It is not a Spec Kit preset,
workflow, extension, or bundle, and must not be installed into normal developer
projects.

It answers how an SDD workflow execution behaved by consuming stable workflow
state, Guard output, and framework metadata. It never re-runs Guard checks, approves
gates, answers clarification questions, or uses an LLM.

## Evaluator experience

Register an evaluation:

```powershell
& "./scripts/Start-SddEvaluation.ps1" `
  -ProjectRoot "C:\path\to\consumer" `
  -WorkflowId "dotnet-sdd-feature" `
  -Integration "copilot" `
  -ScenarioId "enterprise-scenario-001"
```

Add `-StartWorkflow -Description "..."` only when the evaluator intentionally wants
the harness to invoke `specify workflow run`. The description is passed to Spec Kit
but is not persisted by the Harness or exported.

Inspect:

```powershell
& "./scripts/Get-SddEvaluation.ps1" -ProjectRoot "C:\path\to\consumer"
```

Export:

```powershell
& "./scripts/Export-SddAcceptanceReport.ps1" -ProjectRoot "C:\path\to\consumer"
```

The canonical report is `artifacts/sdd-evaluation/sdd-acceptance.json`; Markdown is a
sanitized human representation.

## Objective result rules

- `ACCEPTED`: workflow completed, Guard PASS, no blocking framework error.
- `REJECTED`: the workflow records a human gate rejection/abort.
- `FAILED`: workflow or Guard failed, or a completed workflow has no Guard report.
- `INCOMPLETE`: evaluation is created/running/paused, or its Guard is not yet expected.

AI usage defaults to `not_available`. Optional manual/external metrics may be supplied
as JSON with `source` equal to `manual` or `external`; the Harness never labels them
as automatically measured.

## Privacy

Reports contain identifiers, statuses, counters, versions, and normalized environment
facts only. They exclude descriptions, requirement/story/task text, command output,
source, secrets, payloads, remote URLs, absolute paths, usernames, and private domain
names. Paths are normalized to `<PROJECT_ROOT>/...` if a supported relative evidence
path is ever emitted.

## Tests

```powershell
& "./tests/Invoke-HarnessTests.ps1"
```

Fixtures are synthetic and deterministic.

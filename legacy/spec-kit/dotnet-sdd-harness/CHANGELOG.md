# Changelog

## 0.1.1

- Persist evaluations immediately with an independent Evaluation ID and nullable
  Workflow Run ID.
- Store evaluation metadata and reports in per-evaluation directories, with a small
  `current.json` pointer for optional ergonomics.
- Added `Attach-SddWorkflowRun.ps1` with deterministic run, workflow, and reliable
  integration validation for runs in any persisted state.
- Removed the `-StartWorkflow` and `-Description` public parameters. The Harness no
  longer invokes or resumes Spec Kit workflows.
- Made inspect/export safe before workflow start and for paused, aborted, failed, and
  completed workflows with missing, failing, or passing Guard output.
- Restrict `REJECTED` to aborted runs with explicit persisted gate-rejection evidence;
  unexplained aborts are `FAILED`.
- Added the Gate 1 / EOF regression fixture, multiple-evaluation coverage, schema
  validation, and expanded sanitization and state-classification tests.
- Kept the Acceptance Report schema at 1.0; only the Harness and evaluation metadata
  versions changed.

## 0.1.0

- Added evaluation start/inspect/export scripts, acceptance schema, objective result
  rules, workflow/Guard metric extraction, optional external AI metrics, and privacy
  fixtures.

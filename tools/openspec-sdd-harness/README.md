# OpenSpec SDD Evaluation Harness

The harness records one sanitized evaluation of the explicit repository gates. It does not attach to agent-internal workflow state and does not launch, resume, or simulate an OpenSpec change.

```powershell
./tools/openspec-sdd-harness/Invoke-OpenSpecEvaluation.ps1
```

Each run writes `artifacts/sdd-evaluation/<evaluation-id>/evaluation.json` with timestamps, exit codes, result, and relative evidence locations. Command output, prompts, source, payloads, secrets, and absolute paths are not persisted.

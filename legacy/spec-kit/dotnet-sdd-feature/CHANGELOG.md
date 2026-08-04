# Changelog

## 0.1.1

- Removed automatic `speckit.clarify` from the workflow.
- Removed automatic `speckit.checklist` from the workflow.
- Bounded automatic `speckit.analyze` to one workflow execution.
- Documented operator-driven remediation after analyze and converge findings.
- Preserved the four human gates.
- Kept `dotnet-sdd`, `dotnet-sdd-guard`, `dotnet-sdd-harness`, and the preset unchanged.

## 0.1.0

- Added the experimental STANDARD feature workflow.
- Added Specification, Technical Design, and Implementation Readiness approval
  gates.
- Added orchestration of the official Spec Kit commands from `specify` through
  `converge`, without duplicating preset instructions.
- Added an allowlisted Copilot/Codex integration input with Copilot as the
  default.
- Added a final Convergence gate because Spec Kit 0.14.3 does not provide a
  stable structured convergence result for safe automatic looping.

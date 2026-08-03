# Migration from GitHub Spec Kit to OpenSpec/OPSX

## Migration status

The active SDD system is OpenSpec `1.7.0` with one repository-root `openspec/` project and the local `dotnet-sdd` schema. Previous Spec Kit assets are preserved only under `legacy/spec-kit/` and `docs/sdd-history/spec-kit/`; they are immutable historical evidence and do not participate in active configuration, instructions, CI, application projects, or gates.

No release was published and no pull request was created during the migration execution.

## Review prechecks

- Branch: `chore/migrate-speckit-to-openspec`.
- Initial working tree for this correction: clean.
- Initial `HEAD`: `3e2ef8e`, also present at `origin/chore/migrate-speckit-to-openspec`.
- Initial comparison with `main`: 190 files changed, 13,400 insertions, and 47 deletions.
- Repository root in all reusable documentation: `<repository-root>`.

The migration commit already existed on the remote branch before this correction. No push, force push, release, or pull request was performed during the correction.

## Corrected migration design

### Reusable distribution

`distribution/openspec/dotnet-sdd/install.ps1` now installs:

- the `dotnet-sdd` schema and templates;
- generic `openspec/config.yaml` rules for proposal, specs, research, design, review, tasks, apply, and archive;
- `docs/architecture/dotnet-sdd-governance.md`;
- the deterministic guard and repository wrapper; and
- the requested Codex and GitHub Copilot verification skills.

The installer requires OpenSpec `1.7.0` or a compatible newer `1.x` release. It rejects unparseable, older, and unsupported-major versions. It detects all differing payload collisions before mutation, permits identical reinstallations, and replaces differing files only with `-BackupExisting` after creating adjacent timestamped backups. Consumers that already contain OpenSpec specs or changes receive `openspec validate --all --strict` after schema validation.

### Active OpenAPI contract

The active contract is `openspec/specs/contact-requests/contracts/openapi.yaml`. It was reconciled with the durable capability spec and the existing endpoint, request, result, validator, and exception handler. It describes only `POST /contact-requests`, including:

- required `name`, `email`, and `message` input;
- name and message length limits and the current email rule;
- `201 Created`, `Location`, UUID, creation timestamp, and `Pending` status;
- privacy-preserving confirmation without name, email, or message; and
- validation Problem Details with per-field errors and `traceId`.

The historical contract under `docs/sdd-history/spec-kit/` was not modified. Redocly no longer reports a placeholder-server problem. Its remaining recommended-rule warning is the absent license metadata; no license was invented because the repository contains no real license file.

### Guard and CI

`OPENAPI001` considers only contracts under:

- `openspec/specs/**/contracts/openapi.yaml`;
- non-archived `openspec/changes/**/specs/**/contracts/openapi.yaml`; and
- `docs/contracts/**/openapi.yaml`.

The guard does not traverse `docs/sdd-history/` or `legacy/` for active contracts. An HTTP application without an active contract fails; a non-HTTP project without a contract is `NOT_APPLICABLE`; existing baseline contracts are still linted even when a change does not affect HTTP.

The workflow retains `pull_request`, adds manual dispatch and pushes to `chore/migrate-speckit-to-openspec`, lints the active contract, installs exact OpenSpec and Redocly versions, uses `global.json` for .NET SDK `10.0.302`, and pins the four requested GitHub actions by full commit SHA with readable tag comments.

### Instructions and local-environment scanning

The unsupported nested `PoCFinal/.github/copilot-instructions.md` was moved to `.github/instructions/pocfinal.instructions.md` with `applyTo: "PoCFinal/**"`. It concisely links the canonical governance and records the .NET 10, modular-monolith, four-layer, Minimal API, Wolverine `MediatorOnly`, Repository Pattern, FluentValidation, Problem Details, active OpenAPI, and guard requirements.

The repository guard and reusable installer detect both Windows path separator forms plus file URLs and loopback-host markers. Test fixtures construct these markers only in isolated temporary directories so documentation of scanner patterns does not create false positives.

## Commit-history decision

The preexisting remote migration commit combines application restoration, OpenSpec migration, reusable distribution, harness, and CI. Rewriting it locally would diverge from an existing remote branch and would require a coordinated force push. In accordance with the review constraints, the remote history was preserved and these findings are addressed in a separate `fix` commit.

The desired complete conceptual split remains:

1. `restore: recover implemented PoCFinal application`
2. `migrate: replace active Spec Kit workflow with OpenSpec`
3. `feat: add reusable OpenSpec distribution and deterministic verification`
4. `fix: address OpenSpec migration review findings`

Achieving the first three commits as separate historical commits requires explicit coordination before any history rewrite. This correction does not perform or authorize a force push.

## Files created by the correction

- `.github/instructions/pocfinal.instructions.md`
- `distribution/openspec/dotnet-sdd/config/config.yaml`
- `distribution/openspec/dotnet-sdd/docs/dotnet-sdd-governance.md`
- `global.json`
- `openspec/specs/contact-requests/contracts/openapi.yaml`

## Files moved or removed by the correction

- Removed unsupported `PoCFinal/.github/copilot-instructions.md`; its applicable content now lives in `.github/instructions/pocfinal.instructions.md`.

## Principal files modified by the correction

- Distribution installer, wrapper, guard payload, tests, and README.
- Repository guard engine, wrapper, and guard tests.
- OpenSpec capability spec and workflow documentation.
- CI workflow, repository instructions, Copilot instructions, root README, and this report.

No restored `PoCFinal` application source file was modified. The two local-only `applicationUrl` entries were removed from `launchSettings.json` so the required loopback scan has no active exception; endpoint behavior and implementation remain unchanged.

## Validation results

| Validation | Result |
|---|---|
| `openspec --version` | PASS: `1.7.0`. |
| `openspec schemas` | PASS: project `dotnet-sdd` and built-in `spec-driven` listed. |
| `openspec schema which dotnet-sdd` | PASS: project-local schema resolved. |
| `openspec schema validate dotnet-sdd --verbose` | PASS. |
| `openspec templates --schema dotnet-sdd` | PASS: six templates resolved. |
| `openspec validate --specs --strict` | PASS: 1/1. |
| `openspec validate --all --strict` | PASS: 1/1. |
| `dotnet --version` | PASS: `10.0.302`. |
| `dotnet restore PoCFinal/PoCFinal.sln` | PASS. |
| Release build with `-warnaserror` | PASS: 0 warnings, 0 errors. |
| Solution tests | PASS: 11 passed, 0 failed, 0 skipped. |
| Active OpenAPI lint with Redocly `2.41.1` | PASS with one license warning; no license exists to declare. |
| Deterministic guard | PASS: 16 checks passed, 0 failed, 1 advisory (`EXC001`). |
| Guard tests | PASS: 29/29. |
| OpenSpec harness tests | PASS: 4/4. |
| Installer tests | PASS: 11/11. |
| Local path/loopback audit | PASS: matches remain only in immutable historical trees. |
| Active Spec Kit reference audit | PASS: matches remain only in immutable historical trees and this migration report. |
| `git diff --check` | PASS. |
| Local validation | PASS. |
| GitHub Actions validation | NOT RUN. Local results are not represented as a GitHub Actions run. |

## Required command surfaces

Codex:

```text
$openspec-propose
$openspec-explore
$openspec-update-change
$openspec-apply-change
$openspec-sync-specs
$openspec-archive-change
```

GitHub Copilot:

```text
/opsx-propose
/opsx-explore
/opsx-update
/opsx-apply
/opsx-sync
/opsx-archive
```

Deterministic gate:

```powershell
./scripts/Invoke-OpenSpecSddGuard.ps1
```

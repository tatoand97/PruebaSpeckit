# Distribution results

Date: 2026-07-29  
Spec Kit under test: 0.14.3  
Readiness: **NOT READY**

## Artifacts

| Component | Version | Artifact | SHA-256 | URL |
|---|---:|---|---|---|
| `dotnet-sdd` | 1.0.1 | `artifacts/dotnet-sdd-1.0.1.zip` | `fd3ac785f754910edab26fd4e5eab8194c9ae59f11af5462c1af373e28c08e04` | `https://github.com/tatoand97/PruebaSpeckit/releases/download/__RELEASE_TAG__/dotnet-sdd-1.0.1.zip` |
| `dotnet-sdd-feature` | 0.1.1 | `artifacts/dotnet-sdd-feature-0.1.1.yml` | `__PENDING_SHA256__` | `https://github.com/tatoand97/PruebaSpeckit/releases/download/__RELEASE_TAG__/dotnet-sdd-feature-0.1.1.yml` |
| `dotnet-sdd-guard` | 1.0.0 | `artifacts/dotnet-sdd-guard-1.0.0.zip` | `7ddde6edb1f8abfac73e292c7be01bbef3976606723083010a8af7d48f8c152e` | `https://github.com/tatoand97/PruebaSpeckit/releases/download/__RELEASE_TAG__/dotnet-sdd-guard-1.0.0.zip` |
| `dotnet-sdd-bundle` | 1.0.1 | `artifacts/dotnet-sdd-bundle-1.0.1.zip` | `__PENDING_SHA256__` | `https://github.com/tatoand97/PruebaSpeckit/releases/download/__RELEASE_TAG__/dotnet-sdd-bundle-1.0.1.zip` |

The Preset and Extension ZIPs were rebuilt twice with fixed entry timestamps, stable
path ordering, and identical hashes. The Workflow is the original `workflow.yml`
copied byte for byte. The Bundle is the existing artifact copied byte for byte.

Artifact audit passed for unsafe paths, traversal, PoC/Harness/cache directories,
Codex artifact directories, absolute workstation paths, local URLs, and known secret
fixture patterns. Extension tests were intentionally excluded from its install ZIP
because they contain synthetic secret/path fixtures; the functional manifest,
command, script, README, and changelog are included.

## Catalogs

| Catalog | URL | Schema | Component | Version | Install policy |
|---|---|---:|---|---:|---|
| Preset | `https://raw.githubusercontent.com/tatoand97/PruebaSpeckit/main/distribution/catalogs/presets.json` | 1.0 | `dotnet-sdd` | 1.0.1 | `install_allowed: true` through `--install-allowed` |
| Workflow | `https://raw.githubusercontent.com/tatoand97/PruebaSpeckit/main/distribution/catalogs/workflows.json` | 1.0 | `dotnet-sdd-feature` | 0.1.1 | `install_allowed: true`, written automatically by `catalog add` |
| Extension | `https://raw.githubusercontent.com/tatoand97/PruebaSpeckit/main/distribution/catalogs/extensions.json` | 1.0 | `dotnet-sdd-guard` | 1.0.0 | `install_allowed: true` through `--install-allowed` |
| Bundle | `https://raw.githubusercontent.com/tatoand97/PruebaSpeckit/main/distribution/catalogs/bundles.json` | 1.0 | `dotnet-sdd` | 1.0.1 | `install-allowed` through `--policy` |

The catalog structures were derived from the official/community catalogs and the
installed parser code at official tag `v0.14.3` (`b46ce37f6c87583cdfc40015dc81fed461973c9d`).
Spec Kit's actual Preset, Workflow, Extension, and Bundle parsers loaded the generated
JSON. Duplicate-property detection, exact ID/version checks, HTTPS-format checks, and
artifact/catalog hash consistency also passed.

On 2026-07-29 all four final raw catalog URLs returned HTTP `404`, as expected because
publication was not authorized. Release URLs still contain the explicit
`__RELEASE_TAG__` placeholder and also return `404`.

## Clean install

| Check | Result | Evidence |
|---|---|---|
| Catalog registration | LOCAL PASS / ONLINE NOT RUN | All four catalogs registered from a temporary loopback server. Public HTTPS catalogs are not published. |
| Preset resolution | LOCAL PASS | `search`, `info`, and `add` installed `dotnet-sdd` 1.0.1 from its catalog. |
| Workflow resolution | LOCAL PASS | `search`, `info`, and `add` installed `dotnet-sdd-feature` 0.1.1 from its catalog. |
| Extension resolution | LOCAL PASS | `search`, `info`, and `add` installed `dotnet-sdd-guard` 1.0.0; command and agent skill registered. |
| Bundle resolution | LOCAL PASS | `bundle search` and `bundle info` expanded the three exact pinned components from the catalog ZIP. |
| Bundle install | **FAIL** | Spec Kit 0.14.3 delegates `workflow_add(component.id)` in process; Typer's programmatic `dev` default is truthy, so it rejects the catalog ID as an invalid `--dev` path. |
| Provenance | **FAIL** | Bundle installation rolls back and does not create a successful `dotnet-sdd` 1.0.1 provenance record. |

The failing command was:

```powershell
specify bundle install dotnet-sdd --integration copilot
```

The exact CLI error was:

```text
--dev source must be a workflow YAML file or a directory containing workflow.yml:
dotnet-sdd-feature
Error: Failed to install workflow 'dotnet-sdd-feature'.
```

The responsible 0.14.3 code path is
`src/specify_cli/bundler/services/primitives.py`, where `_WorkflowKindManager.install`
calls `workflow_add(component.id)` without explicit Python values for `dev=False` and
`from_url=None`. This is outside the distribution artifacts and cannot be corrected
by a supported catalog property. Preinstalling the Workflow would mask the defect and
violate the bundle-only criterion, so it was not used.

## Final installed versions

| Component | Required | Individual catalog test | Bundle-only clean consumer |
|---|---:|---:|---:|
| `dotnet-sdd` | 1.0.1 | 1.0.1 PASS | Not retained; bundle transaction failed |
| `dotnet-sdd-feature` | 0.1.1 | 0.1.1 PASS | Not installed |
| `dotnet-sdd-guard` | 1.0.0 | 1.0.0 PASS | Not retained; bundle transaction failed |
| bundle | 1.0.1 | Resolution metadata PASS | Provenance not recorded |

The required final state:

```text
dotnet-sdd          1.0.1
dotnet-sdd-feature  0.1.1
dotnet-sdd-guard    1.0.0
bundle              1.0.1
```

was **not** achieved through the bundle alone.

## Remaining limitations

1. No commit, push, or GitHub Release was authorized, so catalogs and artifacts do
   not yet have reachable public HTTPS URLs.
2. Artifact URLs retain the intentional `__RELEASE_TAG__` placeholder.
3. Spec Kit 0.14.3 cannot install this catalog Workflow through the bundle because of
   the confirmed in-process Typer default defect, even though individual Workflow
   catalog installation succeeds.
4. Consequently, online clean installation, final bundle provenance, exact final
   versions, mandatory hook registration in the bundle-only consumer, and Copilot
   materialization in that consumer cannot be marked PASS.
5. The distribution remains portable to an internal HTTPS catalog, but no enterprise
   hosting infrastructure has been implemented.

## Readiness

**NOT READY**

To become ready:

1. use a Spec Kit build in which bundle workflow delegation passes explicit
   `dev=False` and `from_url=None` (or an official equivalent fix);
2. rebuild catalogs with an authorized immutable Release tag;
3. commit/push the catalogs and publish all four Release assets;
4. run `Test-CleanInstall.ps1` from a completely clean external consumer against the
   real HTTPS URLs; and
5. confirm the three exact component versions, mandatory `after_implement` hook,
   Copilot materialization, and bundle 1.0.1 provenance without `--dev`, local paths,
   manual preinstallation, or file copying.

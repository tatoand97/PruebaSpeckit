# .NET SDD distribution

This directory is the versioned distribution layer for the existing `.NET SDD`
components. It does not change the functional Preset, Workflow, Guard, Bundle, or
Harness.

The catalogs target Spec Kit 0.14.3 and follow the catalog shapes used by that tag:

- Preset: `schema_version: 1.0`, an object named `presets`, and one entry per ID
  using `download_url`.
- Workflow: `schema_version: 1.0`, an object named `workflows`, and one entry per ID
  using `url`. The installable artifact is the workflow YAML itself.
- Extension: `schema_version: 1.0`, an object named `extensions`, and one entry per
  ID using `download_url`.
- Bundle: `schema_version: 1.0`, an object named `bundles`, and one entry per ID
  using `download_url`.

Spec Kit 0.14.3 does not define a nested `versions` collection for these catalogs.
The object key is the resolution ID and each ID has one active catalog version.
Preset, Extension, and Bundle support an optional `sha256` field and verify it while
downloading. Workflow does not, so its SHA-256 is recorded in
`DISTRIBUTION-RESULTS.md` but not in `workflows.json`.

Primary references:

- [Preset official catalog at v0.14.3](https://github.com/github/spec-kit/blob/v0.14.3/presets/catalog.json)
- [Workflow official catalog at v0.14.3](https://github.com/github/spec-kit/blob/v0.14.3/workflows/catalog.json)
- [Extension community catalog at v0.14.3](https://github.com/github/spec-kit/blob/v0.14.3/extensions/catalog.community.json)
- [Bundle community catalog at v0.14.3](https://github.com/github/spec-kit/blob/v0.14.3/bundles/catalog.community.json)
- [Bundle documentation at v0.14.3](https://github.com/github/spec-kit/blob/v0.14.3/docs/reference/bundles.md)

## Current readiness warning

The files are prepared but not published. Artifact URLs intentionally contain
`__RELEASE_TAG__`, and the final raw GitHub catalog URLs return `404` until these
files are committed and pushed.

There is also a confirmed Spec Kit 0.14.3 bundle defect: catalog installation of
`dotnet-sdd-feature` works with `specify workflow add dotnet-sdd-feature`, but the
bundle's in-process workflow delegation supplies Typer's `--dev` default object
instead of the boolean `false`. The bundle install therefore fails with:

```text
--dev source must be a workflow YAML file or a directory containing workflow.yml:
dotnet-sdd-feature
```

Do not treat the commands below as accepted until `Test-CleanInstall.ps1` passes
against the published HTTPS URLs with a Spec Kit build that fixes this defect.

## One-time catalog registration

Run from an initialized Spec Kit project:

```powershell
$catalogBase = 'https://raw.githubusercontent.com/tatoand97/PruebaSpeckit/main/distribution/catalogs'

specify preset catalog add "$catalogBase/presets.json" `
  --name dotnet-sdd `
  --install-allowed

specify workflow catalog add "$catalogBase/workflows.json" `
  --name dotnet-sdd

specify extension catalog add "$catalogBase/extensions.json" `
  --name dotnet-sdd `
  --install-allowed

specify bundle catalog add "$catalogBase/bundles.json" `
  --id dotnet-sdd `
  --policy install-allowed
```

Workflow catalog registration has no `--install-allowed` option in Spec Kit 0.14.3.
The command writes `install_allowed: true` to the workflow catalog configuration
automatically.

## Project bootstrap

The target experience, after the recorded Spec Kit defect is fixed and the
distribution is published, is:

```powershell
specify bundle install dotnet-sdd --integration copilot
```

The explicit ZIP variant still resolves Preset, Workflow, and Extension references
through their active catalogs:

```powershell
Invoke-WebRequest `
  -Uri 'https://github.com/tatoand97/PruebaSpeckit/releases/download/<RELEASE_TAG>/dotnet-sdd-1.0.1.zip' `
  -OutFile '.\dotnet-sdd-1.0.1.zip'

specify bundle install '.\dotnet-sdd-1.0.1.zip' --integration copilot
```

Neither variant embeds or installs the Harness.

## First project setup

Run Constitution exactly once for a new project, after the framework installation,
to establish the permanent project principles. Do not repeat it for each feature.

With Copilot skills:

```text
/speckit-constitution
```

## Feature development

After the one-time project setup, the normal feature entry point is:

```powershell
specify workflow run dotnet-sdd-feature `
  -i spec="Describe the functional need" `
  -i integration=copilot
```

No workflow or feature command is executed by the distribution validation scripts.

## Build and offline validation

From the repository root:

```powershell
.\distribution\scripts\Build-Distribution.ps1
.\distribution\scripts\Test-Catalogs.ps1
```

`Build-Distribution.ps1` creates deterministic root-manifest ZIPs for the Preset and
Extension, copies the Workflow YAML, and preserves the existing Bundle ZIP byte for
byte. It also updates supported catalog hashes. With the default placeholder it does
not claim online readiness.

The local clean-install simulation exercises the real CLI catalog and primitive
installers over loopback, but is not online acceptance:

```powershell
.\distribution\scripts\Test-CleanInstall.ps1 `
  -LocalDistributionRoot '.\distribution' `
  -IgnoreAgentTools
```

The command currently demonstrates the Spec Kit 0.14.3 workflow delegation failure
described above.

## Publication commands

These commands are prepared for a later explicitly authorized publication. They have
not been executed:

```powershell
$releaseTag = 'dotnet-sdd-distribution-v1.0.1'

.\distribution\scripts\Build-Distribution.ps1 -ReleaseTag $releaseTag
.\distribution\scripts\Test-Catalogs.ps1

git add -- distribution
git commit -m "Add versioned .NET SDD distribution"
git push origin main

gh release create $releaseTag `
  '.\distribution\artifacts\dotnet-sdd-1.0.1.zip' `
  '.\distribution\artifacts\dotnet-sdd-feature-0.1.1.yml' `
  '.\distribution\artifacts\dotnet-sdd-guard-1.0.1.zip' `
  '.\distribution\artifacts\dotnet-sdd-bundle-1.0.1.zip' `
  --repo tatoand97/PruebaSpeckit `
  --title '.NET SDD distribution 1.0.1' `
  --notes 'Versioned Spec Kit catalogs and immutable .NET SDD artifacts.'

.\distribution\scripts\Test-CleanInstall.ps1 -IgnoreAgentTools
```

Use `-IgnoreAgentTools` only when GitHub Copilot is unavailable on the acceptance
machine. The script still initializes the Copilot integration and verifies its
materialized skills.

## Troubleshooting

Individual installation is diagnostic only, not the normal developer experience:

```powershell
specify preset add dotnet-sdd
specify workflow add dotnet-sdd-feature
specify extension add dotnet-sdd-guard
```

All three commands passed the local catalog simulation with exact versions. Their
success does not substitute for the required bundle-only acceptance.

## Enterprise distribution

The public repository is only the PoC host. The same immutable artifacts and catalog
shapes can later be copied to an approved internal HTTPS host. Replace:

```text
https://raw.githubusercontent.com/tatoand97/PruebaSpeckit/main/distribution/catalogs
```

with:

```text
<INTERNAL_HTTPS_CATALOG>
```

and update only catalog/artifact URLs. Preset, Workflow, Guard, Bundle, and Harness
do not need functional changes. No enterprise hosting infrastructure is implemented
here.

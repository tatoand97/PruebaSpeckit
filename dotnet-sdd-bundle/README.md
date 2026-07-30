# .NET SDD Framework Bundle

`dotnet-sdd` 1.0.1 is the distribution layer for exactly:

- preset `dotnet-sdd` 1.0.1;
- workflow `dotnet-sdd-feature` 0.1.1;
- extension `dotnet-sdd-guard` 1.0.1.

The evaluation-only `dotnet-sdd-harness` is deliberately excluded.

The bundle does not pin an `integration` field, so Spec Kit inherits or selects the
project integration. GitHub Copilot is the primary enterprise consumer; Codex may be
used to develop and validate public framework artifacts.

## Intended developer experience

After the three pinned components have been published to active Spec Kit component
catalogs, the official one-step installation is:

```powershell
specify bundle install "./dotnet-sdd-1.0.1.zip" --integration copilot
```

For a directory that is not yet a Spec Kit project:

```powershell
specify bundle init "./dotnet-sdd-1.0.1.zip" --integration copilot
```

Initialize the Constitution once through the materialized `speckit.constitution`
command. Then run each feature through:

```powershell
specify workflow run dotnet-sdd-feature `
  -i spec="Describe the functional need" `
  -i integration=copilot
```

Developers must not install the preset, workflow, and extension individually in the
final distribution experience.

## Spec Kit 0.14.3 local-component limitation

Spec Kit 0.14.3 bundle artifacts embed `bundle.yml`, README, and arbitrary local
assets, but the bundle installer does not resolve component references from those
embedded assets. It resolves only components shipped with Spec Kit, already installed
in the consumer, or available through active HTTPS component catalogs. The manifest's
optional component `source` value is parsed and recorded but is not used by the
primitive installers.

Consequently, this bundle can be structurally validated and reproducibly built, but a
clean consumer cannot yet install its three unpublished local components from the ZIP
alone. Adding relative paths, `file://` URLs, absolute workstation paths, or invented
download URLs would not be supported and is intentionally not done.

The minimum official completion step is to publish versioned preset, workflow, and
extension artifacts to install-allowed HTTPS catalogs, then re-run online bundle
validation and the clean installation test. See
[`SPEC-KIT-0.14.3-LIMITATION.md`](SPEC-KIT-0.14.3-LIMITATION.md).

## Validation and build

```powershell
specify bundle validate --path "./dotnet-sdd-bundle" --offline
specify bundle build --path "./dotnet-sdd-bundle" --output "./dotnet-sdd-bundle/dist"
& "./dotnet-sdd-bundle/tests/Test-BundleArtifact.ps1"
```

Offline validation can only warn that unpublished references are unverifiable. Online
validation and clean installation remain blocked until publication.

## Enterprise acceptance test

Run this later on the enterprise PC with GitHub Copilot, after component publication
and a successful clean bundle installation test:

1. Install the bundle with `--integration copilot`.
2. Initialize the Constitution once.
3. Start an evaluation with `dotnet-sdd-harness`.
4. Run `dotnet-sdd-feature` with Copilot.
5. Approve or reject every gate manually.
6. Let the mandatory Guard hook run after `implement`.
7. Complete `converge` and its human review.
8. Export the Acceptance Report with the Harness.
9. Share only the sanitized Acceptance Report for external review.

Do not install the Harness through this bundle.

# Spec Kit 0.14.3 bundle resolution limitation

## Observed behavior

The installed CLI is Spec Kit 0.14.3. Its official bundle manifest schema permits
pinned references to extensions, presets, steps, and workflows. `bundle build`
packages every file below the bundle directory, but `bundle install` loads only the
manifest from a local ZIP.

Primitive installation then resolves:

1. assets bundled with the Spec Kit CLI;
2. components already installed in the target project; or
3. components in active install-allowed HTTPS catalogs.

It does not extract or route embedded component directories from a bundle artifact.
The parsed `source` property is not consulted by preset, extension, or workflow
primitive installation.

## Impact

`dotnet-sdd` 1.0.1, `dotnet-sdd-feature` 0.1.1, and `dotnet-sdd-guard` 1.0.0 are local
and unpublished. A clean consumer therefore cannot resolve them from the bundle ZIP.
Preinstalling them would make a test pass only because bundle installation is
idempotent by component ID; it would not validate the required one-step distribution.

## Minimum supported resolution

Publish each immutable, versioned component artifact through the corresponding Spec
Kit component catalog, using HTTPS download URLs and install-allowed catalog policy.
Then:

```powershell
specify bundle validate --path "./dotnet-sdd-bundle"
specify bundle build --path "./dotnet-sdd-bundle" --output "./dotnet-sdd-bundle/dist"
specify bundle init "./dotnet-sdd-bundle/dist/dotnet-sdd-1.0.1.zip" --integration copilot
```

No changes to the frozen preset or workflow are required. No absolute path, `file://`
URL, relative pseudo-source, or fabricated remote URL is a supported substitute.

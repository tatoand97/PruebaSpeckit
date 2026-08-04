[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$distributionRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $distributionRoot
$catalogRoot = Join-Path $distributionRoot 'catalogs'
$artifactRoot = Join-Path $distributionRoot 'artifacts'
$failures = [Collections.Generic.List[string]]::new()

function Add-Failure([string]$Message) {
    $failures.Add($Message)
}

function Read-Catalog([string]$Name) {
    $path = Join-Path $catalogRoot $Name
    try {
        return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    }
    catch {
        Add-Failure "$Name is not valid JSON: $($_.Exception.Message)"
        return $null
    }
}

function Test-DuplicateJsonProperties([string]$Path) {
    $document = [Text.Json.JsonDocument]::Parse([IO.File]::ReadAllText($Path))
    try {
        $walk = $null
        $walk = {
            param([Text.Json.JsonElement]$Element, [string]$Location)
            if ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Object) {
                $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                foreach ($property in $Element.EnumerateObject()) {
                    if (-not $seen.Add($property.Name)) {
                        Add-Failure "Duplicate JSON property '$($property.Name)' at $Location in $(Split-Path -Leaf $Path)."
                    }
                    & $walk $property.Value "$Location.$($property.Name)"
                }
            }
            elseif ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Array) {
                $index = 0
                foreach ($item in $Element.EnumerateArray()) {
                    & $walk $item "$Location[$index]"
                    $index++
                }
            }
        }
        & $walk $document.RootElement '$'
    }
    finally {
        $document.Dispose()
    }
}

function Test-HttpsUrl([string]$Value, [string]$Label) {
    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
        Add-Failure "$Label must be an absolute HTTPS URL: $Value"
    }
    if ($Value -match '(?i)localhost|file://|C:\\Users\\') {
        Add-Failure "$Label contains a forbidden local reference: $Value"
    }
}

function Test-ZipAudit([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $names = @($archive.Entries | ForEach-Object FullName)
        foreach ($name in $names) {
            if ([IO.Path]::IsPathRooted($name) -or $name -match '(^|/)\.\.(/|$)') {
                Add-Failure "$(Split-Path -Leaf $Path) contains unsafe path '$name'."
            }
            if ($name -match '(?i)(^|/)(\.git|\.github|\.codex|__pycache__|\.pytest_cache|\.mypy_cache|dist|artifacts|TestResults|poc[^/]*|dotnet-sdd-harness)(/|$)') {
                Add-Failure "$(Split-Path -Leaf $Path) contains forbidden entry '$name'."
            }
        }
        foreach ($entry in $archive.Entries | Where-Object { $_.Length -gt 0 -and $_.Length -lt 5MB }) {
            $reader = [IO.StreamReader]::new($entry.Open(), [Text.Encoding]::UTF8, $true)
            try {
                $text = $reader.ReadToEnd()
                if ($text -match '(?i)C:\\Users\\|file://[A-Za-z0-9/\\]|https?://(?:localhost|127\.0\.0\.1|\[::1\])|super-secret-value|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}') {
                    Add-Failure "$(Split-Path -Leaf $Path) entry '$($entry.FullName)' contains a forbidden local path or secret fixture."
                }
            }
            finally {
                $reader.Dispose()
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

$catalogFiles = @('presets.json', 'workflows.json', 'extensions.json', 'bundles.json')
foreach ($catalogFile in $catalogFiles) {
    Test-DuplicateJsonProperties -Path (Join-Path $catalogRoot $catalogFile)
}

$presets = Read-Catalog 'presets.json'
$workflows = Read-Catalog 'workflows.json'
$extensions = Read-Catalog 'extensions.json'
$bundles = Read-Catalog 'bundles.json'

foreach ($pair in @(
    @($presets, 'presets.json'),
    @($workflows, 'workflows.json'),
    @($extensions, 'extensions.json'),
    @($bundles, 'bundles.json')
)) {
    if ($null -ne $pair[0]) {
        if ($pair[0].schema_version -ne '1.0') {
            Add-Failure "$($pair[1]) must use schema_version 1.0."
        }
        Test-HttpsUrl -Value $pair[0].catalog_url -Label "$($pair[1]) catalog_url"
    }
}

if (@($presets.presets.PSObject.Properties).Count -ne 1 -or $presets.presets.'dotnet-sdd'.version -ne '1.0.1') {
    Add-Failure 'Preset catalog must contain only dotnet-sdd 1.0.1.'
}
if (@($workflows.workflows.PSObject.Properties).Count -ne 1 -or $workflows.workflows.'dotnet-sdd-feature'.version -ne '0.1.1') {
    Add-Failure 'Workflow catalog must contain only dotnet-sdd-feature 0.1.1.'
}
if (@($extensions.extensions.PSObject.Properties).Count -ne 1 -or $extensions.extensions.'dotnet-sdd-guard'.version -ne '1.0.2') {
    Add-Failure 'Extension catalog must contain only dotnet-sdd-guard 1.0.2.'
}
if (@($bundles.bundles.PSObject.Properties).Count -ne 1 -or $bundles.bundles.'dotnet-sdd'.version -ne '1.0.2') {
    Add-Failure 'Bundle catalog must contain only dotnet-sdd 1.0.2.'
}

$presetUrl = $presets.presets.'dotnet-sdd'.download_url
$workflowUrl = $workflows.workflows.'dotnet-sdd-feature'.url
$extensionUrl = $extensions.extensions.'dotnet-sdd-guard'.download_url
$bundleUrl = $bundles.bundles.'dotnet-sdd'.download_url
Test-HttpsUrl $presetUrl 'preset download_url'
Test-HttpsUrl $workflowUrl 'workflow url'
Test-HttpsUrl $extensionUrl 'extension download_url'
Test-HttpsUrl $bundleUrl 'bundle download_url'

if ($workflows.workflows.'dotnet-sdd-feature'.PSObject.Properties.Name -contains 'sha256') {
    Add-Failure 'Workflow catalog must not declare sha256; Spec Kit 0.14.3 does not verify it.'
}

$artifactMap = @(
    @{ Path = Join-Path $artifactRoot 'dotnet-sdd-1.0.1.zip'; Expected = $presets.presets.'dotnet-sdd'.sha256; Zip = $true }
    @{ Path = Join-Path $artifactRoot 'dotnet-sdd-feature-0.1.1.yml'; Expected = $null; Zip = $false }
    @{ Path = Join-Path $artifactRoot 'dotnet-sdd-guard-1.0.2.zip'; Expected = $extensions.extensions.'dotnet-sdd-guard'.sha256; Zip = $true }
    @{ Path = Join-Path $artifactRoot 'dotnet-sdd-bundle-1.0.2.zip'; Expected = $bundles.bundles.'dotnet-sdd'.sha256; Zip = $true }
)
foreach ($artifact in $artifactMap) {
    if (-not (Test-Path -LiteralPath $artifact.Path -PathType Leaf)) {
        Add-Failure "Missing artifact $($artifact.Path)."
        continue
    }
    $actual = (Get-FileHash -LiteralPath $artifact.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($artifact.Expected -and $actual -ne $artifact.Expected) {
        Add-Failure "SHA-256 mismatch for $(Split-Path -Leaf $artifact.Path)."
    }
    if ($artifact.Zip) {
        Test-ZipAudit -Path $artifact.Path
    }
}

$toolDirectory = (& uv tool dir).Trim()
$python = Join-Path $toolDirectory 'specify-cli\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    Add-Failure "Cannot locate Spec Kit 0.14.3 Python at $python."
}
else {
    $validator = @'
import json
import sys
import tempfile
import zipfile
from pathlib import Path
from types import SimpleNamespace

from specify_cli.presets import PresetCatalog, PresetManager
from specify_cli.extensions import ExtensionCatalog, ExtensionManager
from specify_cli.workflows.catalog import WorkflowCatalog
from specify_cli.workflows.engine import WorkflowDefinition, validate_workflow
from specify_cli.bundler.models.catalog import load_catalog_payload
from specify_cli.bundler.models.manifest import BundleManifest
from specify_cli.bundler.services.validator import validate_manifest

root = Path(sys.argv[1])
catalog_root = root / "distribution" / "catalogs"
artifact_root = root / "distribution" / "artifacts"
payloads = {
    name: json.loads((catalog_root / name).read_text(encoding="utf-8"))
    for name in ("presets.json", "workflows.json", "extensions.json", "bundles.json")
}

with tempfile.TemporaryDirectory() as temp:
    project = Path(temp)
    PresetCatalog(project)._validate_catalog_payload(payloads["presets.json"], "https://validation.invalid/presets.json")
    ExtensionCatalog(project)._validate_catalog_payload(payloads["extensions.json"], "https://validation.invalid/extensions.json")

    workflow_catalog = WorkflowCatalog(project)
    workflow_payload = payloads["workflows.json"]
    source = SimpleNamespace(name="validation", priority=1, install_allowed=True)
    workflow_catalog.get_active_catalogs = lambda: [source]
    workflow_catalog._fetch_single_catalog = lambda entry, force_refresh=False: workflow_payload
    merged = workflow_catalog._get_merged_workflows()
    assert set(merged) == {"dotnet-sdd-feature"}

    bundle_entries = load_catalog_payload(payloads["bundles.json"])
    assert set(bundle_entries) == {"dotnet-sdd"}

    installed_preset = PresetManager(project / "preset-consumer").install_from_zip(
        artifact_root / "dotnet-sdd-1.0.1.zip", "0.14.3"
    )
    assert installed_preset.id == "dotnet-sdd" and installed_preset.version == "1.0.1"

    installed_extension = ExtensionManager(project / "extension-consumer").install_from_zip(
        artifact_root / "dotnet-sdd-guard-1.0.2.zip", "0.14.3"
    )
    assert installed_extension.id == "dotnet-sdd-guard" and installed_extension.version == "1.0.2"
    assert "after_implement" in installed_extension.hooks
    assert installed_extension.hooks["after_implement"]["optional"] is False

    workflow = WorkflowDefinition.from_string(
        (artifact_root / "dotnet-sdd-feature-0.1.1.yml").read_text(encoding="utf-8")
    )
    assert workflow.id == "dotnet-sdd-feature" and workflow.version == "0.1.1"
    errors = validate_workflow(workflow)
    assert not errors, errors

    with zipfile.ZipFile(artifact_root / "dotnet-sdd-bundle-1.0.2.zip") as archive:
        manifest_data = archive.read("bundle.yml").decode("utf-8")
    import yaml
    bundle = BundleManifest.from_dict(yaml.safe_load(manifest_data))
    report = validate_manifest(bundle)
    assert report.ok, report.errors
    assert bundle.bundle.id == "dotnet-sdd" and bundle.bundle.version == "1.0.2"
    pins = {(component.kind, component.id): component.version for component in bundle.components}
    assert pins == {
        ("extensions", "dotnet-sdd-guard"): "1.0.2",
        ("presets", "dotnet-sdd"): "1.0.1",
        ("workflows", "dotnet-sdd-feature"): "0.1.1",
    }
'@
    & $python -c $validator $repoRoot
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'Spec Kit 0.14.3 parser/installer validation failed.'
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    throw "Catalog validation failed with $($failures.Count) error(s)."
}

Write-Output 'PASS: JSON, IDs, versions, URLs, artifact audit, hashes, and Spec Kit 0.14.3 parsers/installers.'
if ($presetUrl -match '__RELEASE_TAG__') {
    Write-Warning 'Offline validation passed, but Release asset URLs are intentional placeholders and were not tested online.'
}

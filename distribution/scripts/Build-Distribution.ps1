[CmdletBinding()]
param(
    [string]$ReleaseTag = '__RELEASE_TAG__'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$distributionRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $distributionRoot
$artifactRoot = Join-Path $distributionRoot 'artifacts'
$catalogRoot = Join-Path $distributionRoot 'catalogs'
$fixedTimestamp = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)

function Assert-SpecKitVersion {
    $versionOutput = (& specify --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch '\b0\.14\.3\b') {
        throw "Spec Kit 0.14.3 is required. Actual output: $versionOutput"
    }
}

function Assert-PathWithin {
    param(
        [Parameter(Mandatory)][string]$Base,
        [Parameter(Mandatory)][string]$Candidate
    )

    $resolvedBase = [IO.Path]::GetFullPath($Base).TrimEnd('\', '/')
    $resolvedCandidate = [IO.Path]::GetFullPath($Candidate)
    if (-not $resolvedCandidate.StartsWith("$resolvedBase$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to write outside $resolvedBase`: $resolvedCandidate"
    }
}

function Get-PackageFiles {
    param(
        [Parameter(Mandatory)][string]$SourceRoot
    )

    $excludedSegments = @('.git', '.github', '.codex', '__pycache__', '.pytest_cache', '.mypy_cache', 'dist', 'artifacts', 'TestResults', 'tests')
    $sourcePrefix = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    Get-ChildItem -LiteralPath $SourceRoot -File -Recurse -Force |
        Where-Object {
            $relative = $_.FullName.Substring($sourcePrefix.Length)
            $segments = $relative -split '[\\/]'
            -not ($segments | Where-Object { $_ -in $excludedSegments })
        } |
        Sort-Object { $_.FullName.Substring($sourcePrefix.Length).Replace('\', '/') }
}

function New-DeterministicZip {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$Destination
    )

    Assert-PathWithin -Base $artifactRoot -Candidate $Destination
    $temporary = "$Destination.tmp"
    Assert-PathWithin -Base $artifactRoot -Candidate $temporary
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $sourcePrefix = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $fileStream = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $archive = [IO.Compression.ZipArchive]::new($fileStream, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($file in (Get-PackageFiles -SourceRoot $SourceRoot)) {
                $entryName = $file.FullName.Substring($sourcePrefix.Length).Replace('\', '/')
                $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = $fixedTimestamp
                $entry.ExternalAttributes = 0
                $input = [IO.File]::OpenRead($file.FullName)
                $output = $entry.Open()
                try {
                    $input.CopyTo($output)
                }
                finally {
                    $output.Dispose()
                    $input.Dispose()
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $fileStream.Dispose()
    }

    Move-Item -LiteralPath $temporary -Destination $Destination -Force
}

function Set-CatalogValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][scriptblock]$Mutation
    )

    $document = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    & $Mutation $document
    $json = $document | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText($Path, "$json`n", [Text.UTF8Encoding]::new($false))
}

Assert-SpecKitVersion
New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null

$presetArtifact = Join-Path $artifactRoot 'dotnet-sdd-1.0.1.zip'
$workflowArtifact = Join-Path $artifactRoot 'dotnet-sdd-feature-0.1.0.yml'
$extensionArtifact = Join-Path $artifactRoot 'dotnet-sdd-guard-1.0.0.zip'
$bundleArtifact = Join-Path $artifactRoot 'dotnet-sdd-1.0.0.zip'

New-DeterministicZip -SourceRoot (Join-Path $repoRoot 'dotnet-sdd') -Destination $presetArtifact
Copy-Item -LiteralPath (Join-Path $repoRoot 'dotnet-sdd-feature\workflow.yml') -Destination $workflowArtifact -Force
New-DeterministicZip -SourceRoot (Join-Path $repoRoot 'dotnet-sdd-guard') -Destination $extensionArtifact
Copy-Item -LiteralPath (Join-Path $repoRoot 'dotnet-sdd-bundle\dist\dotnet-sdd-1.0.0.zip') -Destination $bundleArtifact -Force

$firstPresetHash = (Get-FileHash -LiteralPath $presetArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
$firstExtensionHash = (Get-FileHash -LiteralPath $extensionArtifact -Algorithm SHA256).Hash.ToLowerInvariant()

$reproPreset = Join-Path $artifactRoot 'dotnet-sdd-1.0.1.repro.zip'
$reproExtension = Join-Path $artifactRoot 'dotnet-sdd-guard-1.0.0.repro.zip'
try {
    New-DeterministicZip -SourceRoot (Join-Path $repoRoot 'dotnet-sdd') -Destination $reproPreset
    New-DeterministicZip -SourceRoot (Join-Path $repoRoot 'dotnet-sdd-guard') -Destination $reproExtension
    if ((Get-FileHash -LiteralPath $reproPreset -Algorithm SHA256).Hash.ToLowerInvariant() -ne $firstPresetHash) {
        throw 'Preset artifact is not reproducible.'
    }
    if ((Get-FileHash -LiteralPath $reproExtension -Algorithm SHA256).Hash.ToLowerInvariant() -ne $firstExtensionHash) {
        throw 'Extension artifact is not reproducible.'
    }
}
finally {
    Remove-Item -LiteralPath $reproPreset, $reproExtension -Force -ErrorAction SilentlyContinue
}

$releaseBase = "https://github.com/tatoand97/PruebaSpeckit/releases/download/$ReleaseTag"
$workflowHash = (Get-FileHash -LiteralPath $workflowArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
$bundleHash = (Get-FileHash -LiteralPath $bundleArtifact -Algorithm SHA256).Hash.ToLowerInvariant()

Set-CatalogValue -Path (Join-Path $catalogRoot 'presets.json') -Mutation {
    param($catalog)
    $catalog.presets.'dotnet-sdd'.download_url = "$releaseBase/dotnet-sdd-1.0.1.zip"
    $catalog.presets.'dotnet-sdd'.sha256 = $firstPresetHash
}
Set-CatalogValue -Path (Join-Path $catalogRoot 'workflows.json') -Mutation {
    param($catalog)
    $catalog.workflows.'dotnet-sdd-feature'.url = "$releaseBase/dotnet-sdd-feature-0.1.0.yml"
}
Set-CatalogValue -Path (Join-Path $catalogRoot 'extensions.json') -Mutation {
    param($catalog)
    $catalog.extensions.'dotnet-sdd-guard'.download_url = "$releaseBase/dotnet-sdd-guard-1.0.0.zip"
    $catalog.extensions.'dotnet-sdd-guard'.sha256 = $firstExtensionHash
}
Set-CatalogValue -Path (Join-Path $catalogRoot 'bundles.json') -Mutation {
    param($catalog)
    $catalog.bundles.'dotnet-sdd'.download_url = "$releaseBase/dotnet-sdd-1.0.0.zip"
    $catalog.bundles.'dotnet-sdd'.sha256 = $bundleHash
}

@(
    [pscustomobject]@{ Component = 'dotnet-sdd'; Version = '1.0.1'; Artifact = $presetArtifact; SHA256 = $firstPresetHash }
    [pscustomobject]@{ Component = 'dotnet-sdd-feature'; Version = '0.1.0'; Artifact = $workflowArtifact; SHA256 = $workflowHash }
    [pscustomobject]@{ Component = 'dotnet-sdd-guard'; Version = '1.0.0'; Artifact = $extensionArtifact; SHA256 = $firstExtensionHash }
    [pscustomobject]@{ Component = 'dotnet-sdd-bundle'; Version = '1.0.0'; Artifact = $bundleArtifact; SHA256 = $bundleHash }
) | Format-Table -AutoSize

if ($ReleaseTag -eq '__RELEASE_TAG__') {
    Write-Warning 'Catalog artifact URLs still contain the intentional __RELEASE_TAG__ publication placeholder.'
}

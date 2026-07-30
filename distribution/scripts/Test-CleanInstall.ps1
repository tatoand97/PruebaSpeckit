[CmdletBinding()]
param(
    [string]$CatalogBaseUrl = 'https://raw.githubusercontent.com/tatoand97/PruebaSpeckit/main/distribution/catalogs',
    [switch]$IgnoreAgentTools,
    [switch]$AllowLoopbackValidation,
    [string]$LocalDistributionRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($LocalDistributionRoot) {
    $resolvedDistribution = [IO.Path]::GetFullPath($LocalDistributionRoot)
    $catalogSource = Join-Path $resolvedDistribution 'catalogs'
    $artifactSource = Join-Path $resolvedDistribution 'artifacts'
    if (-not (Test-Path -LiteralPath $catalogSource -PathType Container) -or
        -not (Test-Path -LiteralPath $artifactSource -PathType Container)) {
        throw "Local distribution root must contain catalogs and artifacts: $resolvedDistribution"
    }

    $temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $publishRoot = Join-Path $temporaryBase ("dotnet-sdd-publish-" + [Guid]::NewGuid().ToString('N'))
    $resolvedPublish = [IO.Path]::GetFullPath($publishRoot)
    if (-not $resolvedPublish.StartsWith($temporaryBase, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe temporary publish path: $resolvedPublish"
    }

    $catalogPublish = Join-Path $resolvedPublish 'catalogs'
    $artifactPublish = Join-Path $resolvedPublish 'artifacts'
    New-Item -ItemType Directory -Path $catalogPublish, $artifactPublish -Force | Out-Null
    foreach ($artifact in Get-ChildItem -LiteralPath $artifactSource -File) {
        Copy-Item -LiteralPath $artifact.FullName -Destination (Join-Path $artifactPublish $artifact.Name) -Force
    }

    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    $localBase = "http://127.0.0.1:$port"

    foreach ($name in @('presets.json', 'workflows.json', 'extensions.json', 'bundles.json')) {
        $document = Get-Content -LiteralPath (Join-Path $catalogSource $name) -Raw | ConvertFrom-Json
        $document.catalog_url = "$localBase/catalogs/$name"
        switch ($name) {
            'presets.json' {
                $document.presets.'dotnet-sdd'.download_url = "$localBase/artifacts/dotnet-sdd-1.0.1.zip"
            }
            'workflows.json' {
                $document.workflows.'dotnet-sdd-feature'.url = "$localBase/artifacts/dotnet-sdd-feature-0.1.1.yml"
            }
            'extensions.json' {
                $document.extensions.'dotnet-sdd-guard'.download_url = "$localBase/artifacts/dotnet-sdd-guard-1.0.1.zip"
            }
            'bundles.json' {
                $document.bundles.'dotnet-sdd'.download_url = "$localBase/artifacts/dotnet-sdd-bundle-1.0.1.zip"
            }
        }
        [IO.File]::WriteAllText(
            (Join-Path $catalogPublish $name),
            (($document | ConvertTo-Json -Depth 20) + "`n"),
            [Text.UTF8Encoding]::new($false)
        )
    }

    $server = Start-Process -FilePath (Get-Command python).Source `
        -ArgumentList @('-m', 'http.server', $port, '--bind', '127.0.0.1', '--directory', $resolvedPublish) `
        -WindowStyle Hidden -PassThru
    try {
        Start-Sleep -Milliseconds 700
        & $PSCommandPath `
            -CatalogBaseUrl "$localBase/catalogs" `
            -AllowLoopbackValidation `
            -IgnoreAgentTools:$IgnoreAgentTools
        if ($LASTEXITCODE -ne 0) {
            throw 'Local clean-install simulation failed.'
        }
    }
    finally {
        if ($null -ne $server -and -not $server.HasExited) {
            Stop-Process -Id $server.Id -Force
        }
        if (Test-Path -LiteralPath $resolvedPublish) {
            Remove-Item -LiteralPath $resolvedPublish -Recurse -Force
        }
    }
    return
}

$isLoopback = $CatalogBaseUrl -match '^http://(?:localhost|127\.0\.0\.1|\[::1\])(?::\d+)?(?:/|$)'
if ($CatalogBaseUrl -notmatch '^https://' -and -not ($AllowLoopbackValidation -and $isLoopback)) {
    throw 'Clean-install acceptance requires a real HTTPS catalog base URL. Use -AllowLoopbackValidation only for a non-acceptance local transport simulation.'
}

$catalogNames = @('presets.json', 'workflows.json', 'extensions.json', 'bundles.json')
foreach ($name in $catalogNames) {
    $url = "$($CatalogBaseUrl.TrimEnd('/'))/$name"
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    if ($response.StatusCode -ne 200 -or $response.Content -match '__RELEASE_TAG__|__[A-Z0-9_]+__') {
        throw "Catalog is unavailable or still contains placeholders: $url"
    }
}

function Invoke-Specify {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    Push-Location $WorkingDirectory
    try {
        & specify @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "specify $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

function Initialize-Consumer([string]$Path) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    $arguments = @(
        'init', '--here', '--force',
        '--integration', 'copilot',
        '--integration-options=--skills',
        '--script', 'ps'
    )
    if ($IgnoreAgentTools) {
        $arguments += '--ignore-agent-tools'
    }
    Invoke-Specify -WorkingDirectory $Path -Arguments $arguments

    $base = $CatalogBaseUrl.TrimEnd('/')
    Invoke-Specify $Path @('preset', 'catalog', 'add', "$base/presets.json", '--name', 'dotnet-sdd', '--install-allowed')
    Invoke-Specify $Path @('workflow', 'catalog', 'add', "$base/workflows.json", '--name', 'dotnet-sdd')
    Invoke-Specify $Path @('extension', 'catalog', 'add', "$base/extensions.json", '--name', 'dotnet-sdd', '--install-allowed')
    Invoke-Specify $Path @('bundle', 'catalog', 'add', "$base/bundles.json", '--id', 'dotnet-sdd', '--policy', 'install-allowed')
}

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("dotnet-sdd-clean-install-" + [Guid]::NewGuid().ToString('N'))
$individualConsumer = Join-Path $temporaryRoot 'individual'
$bundleConsumer = Join-Path $temporaryRoot 'bundle'
try {
    Initialize-Consumer $individualConsumer
    Invoke-Specify $individualConsumer @('preset', 'search', 'dotnet-sdd')
    Invoke-Specify $individualConsumer @('preset', 'info', 'dotnet-sdd')
    Invoke-Specify $individualConsumer @('preset', 'add', 'dotnet-sdd')
    Invoke-Specify $individualConsumer @('workflow', 'search', 'dotnet-sdd-feature')
    Invoke-Specify $individualConsumer @('workflow', 'info', 'dotnet-sdd-feature')
    Invoke-Specify $individualConsumer @('workflow', 'add', 'dotnet-sdd-feature')
    Invoke-Specify $individualConsumer @('extension', 'search', 'dotnet-sdd-guard')
    Invoke-Specify $individualConsumer @('extension', 'info', 'dotnet-sdd-guard')
    Invoke-Specify $individualConsumer @('extension', 'add', 'dotnet-sdd-guard')
    Invoke-Specify $individualConsumer @('bundle', 'search', 'dotnet-sdd')
    Invoke-Specify $individualConsumer @('bundle', 'info', 'dotnet-sdd')

    Initialize-Consumer $bundleConsumer
    Invoke-Specify $bundleConsumer @('bundle', 'install', 'dotnet-sdd', '--integration', 'copilot')

    $presetManifest = Get-Content -LiteralPath (Join-Path $bundleConsumer '.specify\presets\dotnet-sdd\preset.yml') -Raw
    $workflowManifest = Get-Content -LiteralPath (Join-Path $bundleConsumer '.specify\workflows\dotnet-sdd-feature\workflow.yml') -Raw
    $extensionManifestPath = Join-Path $bundleConsumer '.specify\extensions\dotnet-sdd-guard\extension.yml'
    $extensionManifest = Get-Content -LiteralPath $extensionManifestPath -Raw
    $bundleRecords = Get-Content -LiteralPath (Join-Path $bundleConsumer '.specify\bundle-records.json') -Raw | ConvertFrom-Json

    if ($presetManifest -notmatch '(?m)^\s*version:\s*"?1\.0\.1"?\s*$') { throw 'Installed preset version is not 1.0.1.' }
    if ($workflowManifest -notmatch '(?m)^\s*version:\s*"?0\.1\.1"?\s*$') { throw 'Installed workflow version is not 0.1.1.' }
    if ($extensionManifest -notmatch '(?m)^\s*version:\s*"?1\.0\.1"?\s*$') { throw 'Installed extension version is not 1.0.1.' }
    if ($extensionManifest -notmatch '(?ms)after_implement:.*?optional:\s*false') { throw 'Mandatory after_implement hook is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $bundleConsumer '.specify\extensions\dotnet-sdd-guard\scripts\Invoke-SddGuard.ps1'))) {
        throw 'Guard script was not installed.'
    }
    if (-not (Get-ChildItem -LiteralPath (Join-Path $bundleConsumer '.github\skills') -Directory | Where-Object Name -Match 'dotnet-sdd|speckit')) {
        throw 'Copilot skill materialization was not found.'
    }
    $record = @($bundleRecords.bundles | Where-Object bundle_id -eq 'dotnet-sdd')
    if ($record.Count -ne 1 -or $record[0].version -ne '1.0.1') {
        throw 'Bundle provenance for dotnet-sdd 1.0.1 was not recorded.'
    }

    if ($isLoopback) {
        Write-Output 'LOCAL PASS (not online acceptance): clean loopback catalog registration, individual resolution, bundle-only install, versions, hook, Copilot materialization, and provenance.'
    }
    else {
        Write-Output 'PASS: clean HTTPS catalog registration, individual resolution, bundle-only install, versions, hook, Copilot materialization, and provenance.'
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

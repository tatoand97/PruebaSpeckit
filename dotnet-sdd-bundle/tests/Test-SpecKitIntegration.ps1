[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ExtensionRoot,
    [Parameter(Mandatory)][string]$BundleArtifact
)

$ErrorActionPreference = 'Stop'
$extension = [System.IO.Path]::GetFullPath($ExtensionRoot)
$artifact = [System.IO.Path]::GetFullPath($BundleArtifact)
$systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $systemTemp ("dotnet-sdd-integration-" + [guid]::NewGuid().ToString('N'))
$extensionConsumer = Join-Path $testRoot 'extension-consumer'
$bundleConsumer = Join-Path $testRoot 'bundle-consumer'
$originalLocation = (Get-Location).Path

if (-not $testRoot.StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to create integration fixtures outside the system temporary directory.'
}

New-Item -ItemType Directory -Path $extensionConsumer, $bundleConsumer -Force | Out-Null
try {
    Set-Location $extensionConsumer
    & specify init --here --integration copilot --ignore-agent-tools --script ps
    $extensionInit = $LASTEXITCODE
    & specify extension add $extension --dev
    $extensionAdd = $LASTEXITCODE
    & specify extension info dotnet-sdd-guard
    $extensionInfo = $LASTEXITCODE

    $hooks = Get-Content -LiteralPath (Join-Path $extensionConsumer '.specify/extensions.yml') -Raw
    $hookOk = $hooks -match 'after_implement' -and
        $hooks -match 'optional:\s*false' -and
        $hooks -match 'speckit\.dotnet-sdd-guard\.verify'
    $copilotArtifact = @(Get-ChildItem -LiteralPath (Join-Path $extensionConsumer '.github') -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'dotnet-sdd-guard' }).Count -gt 0

    Set-Location $bundleConsumer
    & specify init --here --integration copilot --ignore-agent-tools --script ps
    $bundleInit = $LASTEXITCODE
    & specify bundle install $artifact --integration copilot --offline
    $bundleInstall = $LASTEXITCODE
    $bundleList = & specify bundle list --json
    $bundleRecorded = ($bundleList -join "`n") -match '"id"\s*:\s*"dotnet-sdd"'

    [ordered]@{
        extensionInitExit = $extensionInit
        extensionAddExit = $extensionAdd
        extensionInfoExit = $extensionInfo
        mandatoryHookRegistered = $hookOk
        copilotArtifactMaterialized = $copilotArtifact
        bundleInitExit = $bundleInit
        bundleInstallExit = $bundleInstall
        bundleProvenanceRecorded = $bundleRecorded
    } | ConvertTo-Json

    if ($extensionInit -ne 0 -or $extensionAdd -ne 0 -or $extensionInfo -ne 0 -or -not $hookOk -or -not $copilotArtifact) {
        exit 1
    }
    if ($bundleInstall -eq 0 -or $bundleRecorded) {
        throw 'Clean bundle installation unexpectedly succeeded; re-audit local component resolution.'
    }
    exit 2
}
finally {
    Set-Location $originalLocation
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    if ($resolvedTestRoot.StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

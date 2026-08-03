[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),

    [Parameter()]
    [switch]$VerboseDiagnostics
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRepository = [IO.Path]::GetFullPath($RepositoryRoot)
$projectRoot = Join-Path $resolvedRepository 'PoCFinal'
$engine = Join-Path $resolvedRepository 'tools/dotnet-sdd-guard/Invoke-DotNetSddGuard.ps1'

if (-not (Test-Path -LiteralPath (Join-Path $resolvedRepository 'openspec/config.yaml') -PathType Leaf)) {
    throw "OpenSpec root not found at $resolvedRepository"
}
if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) {
    throw "Application root not found at $projectRoot"
}
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) {
    throw "Guard engine not found at $engine"
}

Write-Output '== OpenSpec strict validation =='
& openspec validate --all --strict
if ($LASTEXITCODE -ne 0) {
    Write-Error 'OpenSpec strict validation failed.'
    exit 1
}

Write-Output '== High-confidence secret and local-path scan =='
$scanExtensions = @('.cs', '.csproj', '.props', '.targets', '.json', '.yaml', '.yml', '.ps1', '.md')
$scanFiles = @(Get-ChildItem -LiteralPath $resolvedRepository -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Extension -in $scanExtensions -and
        $_.FullName -notmatch '[\\/](\.git|legacy|bin|obj|artifacts|TestResults|node_modules)[\\/]'
    })
$forbiddenPatterns = @(
    'ghp_[A-Za-z0-9]{20,}',
    'github_pat_[A-Za-z0-9_]{20,}',
    '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    '(?i)(?:password|clientsecret|accountkey)\s*[:=]\s*["''][^"'']{8,}["'']',
    '[A-Za-z]:\\Users\\[A-Za-z0-9._-]+\\'
)
$forbiddenCount = 0
foreach ($file in $scanFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    foreach ($pattern in $forbiddenPatterns) {
        if ($content -match $pattern) {
            $forbiddenCount++
            Write-Output "FAIL sensitive/local marker: $($file.FullName.Substring($resolvedRepository.Length + 1))"
            break
        }
    }
}
if ($forbiddenCount -gt 0) {
    Write-Error "$forbiddenCount file(s) contain a high-confidence secret or local absolute path marker."
    exit 1
}
Write-Output "PASS scanned $($scanFiles.Count) text file(s)."

Write-Output '== Deterministic .NET SDD guard =='
& $engine -ProjectRoot $projectRoot -ContractRoot $resolvedRepository -VerboseDiagnostics:$VerboseDiagnostics
exit $LASTEXITCODE

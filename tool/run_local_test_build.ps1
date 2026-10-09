param(
    [switch]$PrepareOnly,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$counterDirectory = Join-Path $workspace '.local'
$counterFile = Join-Path $counterDirectory 'test_build_number'
$definesFile = Join-Path $counterDirectory 'test_build_defines.json'
New-Item -ItemType Directory -Force -Path $counterDirectory | Out-Null

$testBuild = 1
if (Test-Path -LiteralPath $counterFile) {
    $previousBuild = 0
    if (-not [int]::TryParse((Get-Content -LiteralPath $counterFile -Raw).Trim(), [ref]$previousBuild) -or
        $previousBuild -lt 0 -or $previousBuild -eq [int]::MaxValue) {
        throw "Ungueltige Testbuild-Nummer in $counterFile. Datei pruefen."
    }
    $testBuild = $previousBuild + 1
}

$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
$defines = @{ LOCAL_TEST_BUILD = [string]$testBuild } | ConvertTo-Json
[System.IO.File]::WriteAllText($definesFile, $defines, $utf8WithoutBom)
[System.IO.File]::WriteAllText($counterFile, [string]$testBuild, $utf8WithoutBom)

Write-Host "Lokaler Testbuild $testBuild vorbereitet."
if ($PrepareOnly) { return }

$pinnedFlutterVersion = (Get-Content -LiteralPath (Join-Path $workspace '.fvmrc') -Raw |
    ConvertFrom-Json).flutter
$flutter = Join-Path $workspace ".fvm/versions/$pinnedFlutterVersion/bin/flutter.bat"
if (-not (Test-Path -LiteralPath $flutter)) {
    throw "Gepinntes Flutter $pinnedFlutterVersion wurde unter .fvm nicht gefunden."
}

$runArguments = @("--dart-define-from-file=$definesFile")
if ($env:GEOAPIFY_API_KEY) {
    $runArguments += "--dart-define=GEOAPIFY_API_KEY=$($env:GEOAPIFY_API_KEY)"
}
$runArguments += $FlutterArguments

Push-Location $workspace
try {
    & $flutter run @runArguments
    $runExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $runExitCode

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

$ErrorActionPreference = 'Stop'

$counterDirectory = Join-Path $PSScriptRoot '..\.local'
$counterFile = Join-Path $counterDirectory 'test_build_number'
New-Item -ItemType Directory -Force -Path $counterDirectory | Out-Null

$testBuild = 1
if (Test-Path -LiteralPath $counterFile) {
    $previousBuild = 0
    if ([int]::TryParse((Get-Content -LiteralPath $counterFile -Raw).Trim(), [ref]$previousBuild)) {
        $testBuild = $previousBuild + 1
    }
}
Set-Content -LiteralPath $counterFile -Value $testBuild -NoNewline

Write-Host "Starte lokalen Testbuild $testBuild ..."
$runArguments = @("--dart-define=LOCAL_TEST_BUILD=$testBuild")
if ($env:GEOAPIFY_API_KEY) {
    $runArguments += "--dart-define=GEOAPIFY_API_KEY=$($env:GEOAPIFY_API_KEY)"
}
$runArguments += $FlutterArguments

& flutter run @runArguments
exit $LASTEXITCODE

param(
    [ValidateSet('status', 'road-prepare', 'road-collect', 'quality')]
    [string]$Action = 'status',
    [switch]$AllowConnectedDevice
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$diagnosticsDirectory = Join-Path $workspace '.diagnostics'
$applicationId = 'com.munichways.app'
$pinnedFlutterRoot = Join-Path $workspace '.fvm\versions\3.44.7'

function Resolve-Adb {
    $fromPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($fromPath) { return $fromPath.Source }

    $candidates = @()
    if ($env:ANDROID_SDK_ROOT) {
        $candidates += Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe'
    }
    if ($env:ANDROID_HOME) {
        $candidates += Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
    }
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

function Get-ConnectedDevices([string]$adb) {
    if (-not $adb) { return @() }
    $lines = & $adb devices 2>$null
    return @(
        $lines |
            Select-Object -Skip 1 |
            Where-Object { $_ -match '^([^\s]+)\s+device$' } |
            ForEach-Object { $Matches[1] }
    )
}

function Test-FlutterToolAvailable {
    $lockPath = Join-Path $pinnedFlutterRoot 'bin\cache\lockfile'
    if (-not (Test-Path -LiteralPath $lockPath)) { return $true }
    try {
        $stream = [System.IO.File]::Open(
            $lockPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::None
        )
        $stream.Dispose()
        return $true
    } catch {
        return $false
    }
}

function Require-OneDevice([string]$adb) {
    if (-not $adb) {
        throw 'ADB wurde nicht gefunden. ANDROID_SDK_ROOT prüfen.'
    }
    $devices = @(Get-ConnectedDevices $adb)
    if ($devices.Count -ne 1) {
        throw "Genau ein Android-Gerät erwartet, gefunden: $($devices.Count)."
    }
    return $devices[0]
}

function Get-AppPid([string]$adb, [string]$device) {
    $output = @(& $adb -s $device shell pidof $applicationId 2>$null)
    if ($output.Count -eq 0) { return '' }
    return (($output | ForEach-Object { [string]$_ }) -join '').Trim()
}

function Show-Status {
    $adb = Resolve-Adb
    $devices = @(Get-ConnectedDevices $adb)
    $flutterAvailable = Test-FlutterToolAvailable

    Write-Output "Workspace: $workspace"
    Write-Output "Flutter-Toolchain: $(if ($flutterAvailable) { 'frei' } else { 'belegt (flutter run/build/test aktiv)' })"
    Write-Output "ADB: $(if ($adb) { $adb } else { 'nicht gefunden' })"
    Write-Output "Android-Geräte: $($devices.Count)"
    foreach ($device in $devices) {
        $appPid = Get-AppPid $adb $device
        Write-Output "- $device, MunichWays: $(if ($appPid) { "läuft (PID $appPid)" } else { 'nicht aktiv' })"
    }
}

function Prepare-RoadTest {
    $adb = Resolve-Adb
    $device = Require-OneDevice $adb
    New-Item -ItemType Directory -Force -Path $diagnosticsDirectory | Out-Null

    # A larger circular buffer makes it much less likely that early startup or
    # navigation messages are overwritten during a longer ride.
    & $adb -s $device logcat -G 16M
    & $adb -s $device logcat -b all -c

    $startedAt = Get-Date
    $sessionFile = Join-Path $diagnosticsDirectory 'road-test-session.txt'
    @(
        "started_local=$($startedAt.ToString('o'))"
        "device=$device"
        "application_id=$applicationId"
        'procedure=Start app, verify immediately, unplug USB, ride, reconnect without restarting app, collect logs.'
    ) | Set-Content -LiteralPath $sessionFile -Encoding utf8

    Write-Output 'Straßentest vorbereitet: Logpuffer 16 MB und geleert.'
    Write-Output 'Jetzt App starten, sofort prüfen und danach USB abziehen.'
    Write-Output "Sitzung: $sessionFile"
}

function Collect-RoadTest {
    $adb = Resolve-Adb
    $device = Require-OneDevice $adb
    New-Item -ItemType Directory -Force -Path $diagnosticsDirectory | Out-Null
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logFile = Join-Path $diagnosticsDirectory "road-test-$timestamp.log"
    $summaryFile = Join-Path $diagnosticsDirectory "road-test-$timestamp-summary.txt"

    & $adb -s $device logcat -b all -d -v threadtime |
        Set-Content -LiteralPath $logFile -Encoding utf8

    $appPid = Get-AppPid $adb $device
    @(
        "collected_local=$((Get-Date).ToString('o'))"
        "device=$device"
        "application_id=$applicationId"
        "app_pid=$(if ($appPid) { $appPid } else { 'not_running' })"
        "full_log=$logFile"
        ''
        'Previous session:'
    ) | Set-Content -LiteralPath $summaryFile -Encoding utf8
    $sessionFile = Join-Path $diagnosticsDirectory 'road-test-session.txt'
    if (Test-Path -LiteralPath $sessionFile) {
        Get-Content -LiteralPath $sessionFile |
            Add-Content -LiteralPath $summaryFile -Encoding utf8
    }
    if ($appPid) {
        '' | Add-Content -LiteralPath $summaryFile -Encoding utf8
        'Memory at collection:' | Add-Content -LiteralPath $summaryFile -Encoding utf8
        & $adb -s $device shell dumpsys meminfo $appPid |
            Add-Content -LiteralPath $summaryFile -Encoding utf8
    }

    Write-Output "Straßentest-Log gespeichert: $logFile"
    Write-Output "Zusammenfassung: $summaryFile"
}

function Invoke-QualityChecks {
    $adb = Resolve-Adb
    $devices = @(Get-ConnectedDevices $adb)
    if ($devices.Count -gt 0 -and -not $AllowConnectedDevice) {
        throw 'Qualitätsprüfung abgebrochen: Android-Gerät ist angeschlossen. Erst USB abziehen oder bewusst -AllowConnectedDevice verwenden.'
    }
    if (-not (Test-FlutterToolAvailable)) {
        throw 'Qualitätsprüfung abgebrochen: Flutter-Toolchain ist durch einen anderen Run/Build/Test belegt.'
    }

    $dart = Join-Path $pinnedFlutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
    $flutterTools = Join-Path $pinnedFlutterRoot 'bin\cache\flutter_tools.snapshot'
    if (-not (Test-Path -LiteralPath $dart) -or
        -not (Test-Path -LiteralPath $flutterTools)) {
        throw 'Gepinntes Flutter 3.44.7 wurde unter .fvm nicht gefunden.'
    }

    Push-Location $workspace
    try {
        $step = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Output '[1/4] Dart-Format prüfen...'
        & $dart format --output=none --set-exit-if-changed .
        if ($LASTEXITCODE -ne 0) { throw 'Formatprüfung fehlgeschlagen.' }
        Write-Output "[1/4] Format OK ($([math]::Round($step.Elapsed.TotalSeconds, 1)) s)"

        $step.Restart()
        Write-Output '[2/4] Git-Diff prüfen...'
        & git diff --check
        if ($LASTEXITCODE -ne 0) { throw 'git diff --check fehlgeschlagen.' }
        Write-Output "[2/4] Diff OK ($([math]::Round($step.Elapsed.TotalSeconds, 1)) s)"

        # Calling flutter.bat has intermittently stalled before it even starts
        # Dart on this Windows workstation. Invoke the pinned Flutter tool
        # snapshot directly to bypass that batch-wrapper failure mode.
        $step.Restart()
        Write-Output '[3/4] Flutter-Analyse läuft (auf diesem Rechner zuletzt ca. 135 s)...'
        & $dart $flutterTools analyze --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Flutter-Analyse fehlgeschlagen.' }
        Write-Output "[3/4] Analyse OK ($([math]::Round($step.Elapsed.TotalSeconds, 1)) s)"

        $step.Restart()
        Write-Output '[4/4] Flutter-Tests laufen...'
        & $dart $flutterTools test --no-pub --reporter compact
        if ($LASTEXITCODE -ne 0) { throw 'Flutter-Tests fehlgeschlagen.' }
        Write-Output "[4/4] Tests OK ($([math]::Round($step.Elapsed.TotalSeconds, 1)) s)"
    } finally {
        Pop-Location
    }
    Write-Output 'Alle Qualitätsprüfungen erfolgreich.'
}

switch ($Action) {
    'status' { Show-Status }
    'road-prepare' { Prepare-RoadTest }
    'road-collect' { Collect-RoadTest }
    'quality' { Invoke-QualityChecks }
}

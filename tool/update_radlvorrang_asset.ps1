param(
    [string]$SourceUrl = 'https://www.munichways.de/App/happy_bike_level_munich_RV.geojson'
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $repositoryRoot 'assets\radlnetz\happy_bike_level_munich_RV.geojson'
$temporaryFile = Join-Path ([System.IO.Path]::GetTempPath()) ("munichways-radlvorrang-{0}.geojson" -f [guid]::NewGuid())

try {
    Write-Host "Lade RadlVorrang-Netz herunter: $SourceUrl"
    Invoke-WebRequest -Uri $SourceUrl -OutFile $temporaryFile -UseBasicParsing

    $download = Get-Item -LiteralPath $temporaryFile
    if ($download.Length -lt 100000) {
        throw "Die heruntergeladene Datei ist unerwartet klein ($($download.Length) Bytes)."
    }

    $geoJson = Get-Content -LiteralPath $temporaryFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($geoJson.type -ne 'FeatureCollection') {
        throw "Unerwarteter GeoJSON-Typ '$($geoJson.type)' statt 'FeatureCollection'."
    }

    $featureCount = @($geoJson.features).Count
    if ($featureCount -lt 1000) {
        throw "Das RadlVorrang-Netz enthält unerwartet wenige Features ($featureCount)."
    }

    $featuresWithoutRoute = @(
        $geoJson.features | Where-Object {
            -not $_.properties.munichways_mw_rv_route
        }
    ).Count
    if ($featuresWithoutRoute -gt 0) {
        $propertyNames = @($geoJson.features[0].properties.PSObject.Properties.Name) -join ', '
        Write-Host "Vorhandene Properties: $propertyNames"
        throw "$featuresWithoutRoute Features sind nicht als RadlVorrang-Route gekennzeichnet."
    }

    $newHash = (Get-FileHash -LiteralPath $temporaryFile -Algorithm SHA256).Hash
    $oldHash = if (Test-Path -LiteralPath $destination) {
        (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    }

    if ($newHash -eq $oldHash) {
        Write-Host "Das gebündelte RadlVorrang-Netz ist bereits aktuell ($featureCount Features)."
        exit 0
    }

    Copy-Item -LiteralPath $temporaryFile -Destination $destination -Force
    Write-Host "Asset aktualisiert: $featureCount Features, $($download.Length) Bytes"
    Write-Host "SHA256: $newHash"
    Write-Host 'Bitte die geänderte GeoJSON-Datei prüfen und zusammen mit dem App-Code committen.'
}
finally {
    if (Test-Path -LiteralPath $temporaryFile) {
        Remove-Item -LiteralPath $temporaryFile -Force
    }
}

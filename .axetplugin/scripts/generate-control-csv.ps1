<#
.SYNOPSIS
  Genera/actualiza control.csv desde archivos .java.

.DESCRIPTION
  - Escanea recursivamente el directorio Root (por defecto: src/main/java).
  - Si control.csv NO existe: crea el CSV y marca todos los .java como PENDING.
  - Si control.csv SÍ existe:
      * DONE -> PREEXISTING
      * Conserva otros estados (PENDING, EXCLUDED, PREEXISTING)
      * Agrega nuevos .java como PENDING
      * Elimina del CSV entradas de archivos que ya no existan (reflejo exacto)
  - Escribe CSV manualmente sin comillas, UTF-8 sin BOM.
#>

param(
    [string]$Root = "ms-bandejas-gedo-develop/src/main/java",
    [string]$CsvPath = ".axetplugin/control.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -------------------------------------------------
# Funciones auxiliares
# -------------------------------------------------

function To-PosixPath([string]$path) {
    return ($path -replace "\\", "/")
}

function Get-JavaFiles([string]$RootDir) {

    if (-not (Test-Path -LiteralPath $RootDir -PathType Container)) {
        throw "El directorio no existe o no es válido: $RootDir"
    }

    $cwd = (Get-Location).ProviderPath
    $rootFull = (Resolve-Path -LiteralPath $RootDir).ProviderPath

    $files = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Filter "*.java"

    $set = New-Object "System.Collections.Generic.HashSet[string]"

    foreach ($f in $files) {
        $full = $f.FullName
        try {
            $rel = [System.IO.Path]::GetRelativePath($cwd, $full)
            if ($rel.StartsWith("..")) {
                $finalPath = $full
            } else {
                $finalPath = $rel
            }
        } catch {
            if ($full.StartsWith($cwd, [System.StringComparison]::OrdinalIgnoreCase)) {
                $rel2 = $full.Substring($cwd.Length).TrimStart('\','/')
                $finalPath = $rel2
            } else {
                $finalPath = $full
            }
        }

        [void]$set.Add((To-PosixPath $finalPath))
    }

    return $set
}

function Read-ExistingControl([string]$CsvFile) {

    $dict = @{}

    if (-not (Test-Path -LiteralPath $CsvFile -PathType Leaf)) {
        return $dict
    }

    $rows = Import-Csv -LiteralPath $CsvFile

    foreach ($r in $rows) {
        $sp = ("{0}" -f $r.sourcePath).Trim()
        $st = ("{0}" -f $r.status).Trim()
        if ([string]::IsNullOrWhiteSpace($sp)) { continue }
        $dict[$sp] = $st
    }

    return $dict
}

function Build-NewControl($DiscoveredSet, $ExistingDict) {

    $new = @{}

    foreach ($sp in $DiscoveredSet) {
        if ($ExistingDict.ContainsKey($sp)) {
            $st = ("{0}" -f $ExistingDict[$sp]).Trim()
            if ([string]::IsNullOrWhiteSpace($st)) { $st = "PENDING" }
            if ($st -eq "DONE") { $st = "PREEXISTING" }
            $new[$sp] = $st
        }
        else {
            $new[$sp] = "PENDING"
        }
    }

    return $new
}

# -------------------------------------------------
# Flujo principal
# -------------------------------------------------

Write-Host "Escaneando directorio: $Root"

$discovered = Get-JavaFiles -RootDir $Root
$existing   = Read-ExistingControl -CsvFile $CsvPath
$updated    = Build-NewControl -DiscoveredSet $discovered -ExistingDict $existing

Write-Host "Archivos .java encontrados: $($discovered.Count)"
Write-Host "Filas en CSV previo: $($existing.Count)"
Write-Host "Filas en CSV nuevo: $($updated.Count)"

# -------------------------------------------------
# Escritura manual
# -------------------------------------------------

if ([System.IO.Path]::IsPathRooted($CsvPath)) {
    $fullCsv = $CsvPath
} else {
    $fullCsv = Join-Path -Path (Get-Location).ProviderPath -ChildPath $CsvPath
}

$csvParent = Split-Path -Parent $fullCsv
if ($csvParent -and -not (Test-Path -LiteralPath $csvParent)) {
    New-Item -ItemType Directory -Path $csvParent | Out-Null
}

$lines = @()
$lines += "sourcePath,status"

foreach ($key in ($updated.Keys | Sort-Object)) {
    $status = $updated[$key]
    $lines += "$key,$status"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($fullCsv, $lines, $utf8NoBom)

Write-Host "control.csv actualizado correctamente."
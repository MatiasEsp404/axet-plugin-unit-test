<#
.SYNOPSIS
  Sincroniza el inventario de tests (control.csv) con el estado actual del codigo
  
.DESCRIPTION
  Compara los hashes actuales de metodos contra el control.csv.
  - Hash igual: mantener estado (DONE pasa a PREEXISTING)
  - Hash diferente: marcar como UPDATED
  - Metodo nuevo: marcar como PENDING
  
.PARAMETER Root
  Directorio raiz del codigo fuente a escanear
  
.PARAMETER CsvPath
  Ruta del archivo control.csv (default: .axetplugin/control.csv)
  
.PARAMETER ParserJar
  Ruta al JAR del parser
  
.OUTPUTS
  Actualiza control.csv y retorna estadisticas de cambios
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Root,
    
    [Parameter(Mandatory=$false)]
    [string]$CsvPath = ".axetplugin/control.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$ParserJar = "tools/java-parser/target/java-method-parser.jar"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -------------------------------------------------
# Funciones de Utilidad
# -------------------------------------------------

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"  { "Cyan" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Escape-CsvField {
    param([string]$field)
    
    if ($field -match '[;"\r\n]') {
        return '"' + ($field -replace '"', '""') + '"'
    }
    return $field
}

function Read-ControlCsv {
    param([string]$csvPath)
    
    $dict = @{}
    
    if (-not (Test-Path -LiteralPath $csvPath)) {
        Write-Log "Control.csv no existe, se creara uno nuevo" "WARN"
        return $dict
    }
    
    try {
        $rows = Import-Csv -LiteralPath $csvPath -Delimiter ';' -Encoding UTF8
        
        foreach ($row in $rows) {
            $key = "$($row.sourcePath)|$($row.method)"
            $dict[$key] = @{
                status = $row.status
                hash   = $row.contentHash
            }
        }
        
        Write-Log "Control.csv cargado: $($dict.Count) registros" "INFO"
    }
    catch {
        Write-Log "Error leyendo control.csv: $_" "ERROR"
        throw
    }
    
    return $dict
}

# -------------------------------------------------
# Flujo Principal
# -------------------------------------------------

try {
    Write-Log "=== SYNC-TEST-INVENTORY ===" "INFO"
    
    $cwd = (Get-Location).ProviderPath
    
    # Resolver ruta completa del CSV
    $fullCsvPath = if ([System.IO.Path]::IsPathRooted($CsvPath)) { 
        $CsvPath 
    } else { 
        Join-Path $cwd $CsvPath 
    }
    
    Write-Log "Control CSV: $fullCsvPath" "INFO"
    
    # Leer inventario existente
    $existingInventory = Read-ControlCsv -csvPath $fullCsvPath
    
    # Obtener estado actual del codigo usando Get-MethodHashes
    Write-Log "Extrayendo hashes actuales del codigo..." "INFO"
    
    $scriptPath = Join-Path $PSScriptRoot "Get-MethodHashes.ps1"
    $currentMethods = & $scriptPath -Root $Root -ParserJar $ParserJar -OutputFormat PSObject
    
    if ($null -eq $currentMethods -or $currentMethods.Count -eq 0) {
        throw "No se obtuvieron metodos del codigo fuente"
    }
    
    Write-Log "Metodos actuales en codigo: $($currentMethods.Count)" "INFO"
    
    # Comparar y actualizar estados
    $newInventory = @()
    $stats = @{
        New = 0
        Updated = 0
        Unchanged = 0
        Removed = 0
    }
    
    # Procesar cada metodo actual
    foreach ($method in $currentMethods) {
        $key = "$($method.SourcePath)|$($method.MethodSignature)"
        $status = "PENDING"
        
        if ($existingInventory.ContainsKey($key)) {
            $old = $existingInventory[$key]
            
            if ($old.hash -eq $method.ContentHash) {
                # Hash igual: mantener estado o convertir DONE a PREEXISTING
                if ($old.status -eq "DONE") {
                    $status = "PREEXISTING"
                    $stats.Unchanged++
                }
                elseif ($old.status -eq "PREEXISTING") {
                    $status = "PREEXISTING"
                    $stats.Unchanged++
                }
                elseif ($old.status -eq "EXCLUDED") {
                    $status = "EXCLUDED"
                    $stats.Unchanged++
                }
                else {
                    # PENDING o UPDATED: mantener
                    $status = $old.status
                    $stats.Unchanged++
                }
            }
            else {
                # Hash diferente: metodo modificado
                $status = "UPDATED"
                $stats.Updated++
                Write-Log "  [UPDATED] $($method.SourcePath) -> $($method.MethodSignature)" "WARN"
            }
            
            # Marcar como procesado
            $existingInventory.Remove($key)
        }
        else {
            # Metodo nuevo
            $status = "PENDING"
            $stats.New++
            Write-Log "  [NEW] $($method.SourcePath) -> $($method.MethodSignature)" "SUCCESS"
        }
        
        $newInventory += [PSCustomObject]@{
            sourcePath  = $method.SourcePath
            method      = $method.MethodSignature
            contentHash = $method.ContentHash
            status      = $status
        }
    }
    
    # Metodos que quedaron en el inventario anterior fueron removidos del codigo
    $stats.Removed = $existingInventory.Count
    if ($stats.Removed -gt 0) {
        Write-Log "Metodos removidos del codigo: $($stats.Removed)" "WARN"
        foreach ($key in $existingInventory.Keys) {
            Write-Log "  [REMOVED] $key" "WARN"
        }
    }
    
    # Crear directorio si no existe
    $csvDir = Split-Path -Parent $fullCsvPath
    if ($csvDir -and -not (Test-Path $csvDir)) {
        New-Item -ItemType Directory -Path $csvDir -Force | Out-Null
        Write-Log "Directorio creado: $csvDir" "INFO"
    }
    
    # Escribir nuevo control.csv (UTF-8 sin BOM)
    $lines = @("sourcePath;method;contentHash;status")
    
    foreach ($item in ($newInventory | Sort-Object sourcePath, method)) {
        $line = "{0};{1};{2};{3}" -f `
            (Escape-CsvField $item.sourcePath),
            (Escape-CsvField $item.method),
            (Escape-CsvField $item.contentHash),
            (Escape-CsvField $item.status)
        $lines += $line
    }
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($fullCsvPath, $lines, $utf8NoBom)
    
    # Resumen
    Write-Log "`n=== RESUMEN DE SINCRONIZACION ===" "INFO"
    Write-Log "Metodos nuevos (PENDING): $($stats.New)" "SUCCESS"
    Write-Log "Metodos modificados (UPDATED): $($stats.Updated)" $(if ($stats.Updated -gt 0) { "WARN" } else { "INFO" })
    Write-Log "Metodos sin cambios: $($stats.Unchanged)" "INFO"
    Write-Log "Metodos removidos: $($stats.Removed)" $(if ($stats.Removed -gt 0) { "WARN" } else { "INFO" })
    Write-Log "Total registros: $($newInventory.Count)" "SUCCESS"
    Write-Log "CSV actualizado: $fullCsvPath" "SUCCESS"
    
    # Retornar estadisticas
    return [PSCustomObject]@{
        TotalMethods = $newInventory.Count
        NewMethods = $stats.New
        UpdatedMethods = $stats.Updated
        UnchangedMethods = $stats.Unchanged
        RemovedMethods = $stats.Removed
        CsvPath = $fullCsvPath
    }
}
catch {
    Write-Log "ERROR CRITICO: $_" "ERROR"
    Write-Error $_
    exit 1
}

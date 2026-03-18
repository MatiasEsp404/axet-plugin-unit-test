<#
.SYNOPSIS
  Cuenta y muestra estadísticas del archivo control.csv
  
.DESCRIPTION
  Lee el archivo control.csv y muestra un resumen de métodos por estado,
  incluyendo desglose por clase de los métodos PENDING.
  
.PARAMETER CsvPath
  Ruta del archivo control.csv a analizar
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvPath = ".axetplugin/control.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -------------------------------------------------
# Funciones de Utilidad
# -------------------------------------------------

function Write-ColoredMessage {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    switch ($Type) {
        "Info"    { Write-Host $Message -ForegroundColor Cyan }
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Warning" { Write-Host $Message -ForegroundColor Yellow }
        "Error"   { Write-Host $Message -ForegroundColor Red }
        "Gray"    { Write-Host $Message -ForegroundColor Gray }
        "White"   { Write-Host $Message -ForegroundColor White }
        default   { Write-Host $Message }
    }
}

# -------------------------------------------------
# Flujo Principal
# -------------------------------------------------

try {
    # Validar existencia del archivo
    if (-not (Test-Path -LiteralPath $CsvPath)) {
        Write-ColoredMessage "`nERROR: Archivo no encontrado: $CsvPath" "Error"
        Write-ColoredMessage "Ejecute primero: generate-control-csv.ps1" "Warning"
        exit 1
    }
    
    # Leer CSV
    $csv = Import-Csv -LiteralPath $CsvPath -Encoding UTF8
    
    if ($csv.Count -eq 0) {
        Write-ColoredMessage "`nADVERTENCIA: El archivo CSV está vacío" "Warning"
        exit 0
    }
    
    # Agrupar por estado
    $pending = @($csv | Where-Object { $_.status -eq 'PENDING' })
    $done = @($csv | Where-Object { $_.status -eq 'DONE' })
    $preexisting = @($csv | Where-Object { $_.status -eq 'PREEXISTING' })
    $excluded = @($csv | Where-Object { $_.status -eq 'EXCLUDED' })
    $empty = @($csv | Where-Object { -not $_.status -or $_.status.Trim() -eq '' })
    
    # Resumen general
    Write-ColoredMessage "`n=== RESUMEN CONTROL CSV ===" "Info"
    Write-ColoredMessage "Archivo: $CsvPath" "Gray"
    Write-ColoredMessage "`nTotal métodos: $($csv.Count)" "White"
    Write-ColoredMessage "PENDING: $($pending.Count)" "Yellow"
    Write-ColoredMessage "DONE: $($done.Count)" "Success"
    Write-ColoredMessage "PREEXISTING: $($preexisting.Count)" "Gray"
    Write-ColoredMessage "EXCLUDED: $($excluded.Count)" "Gray"
    
    if ($empty.Count -gt 0) {
        Write-ColoredMessage "Sin estado: $($empty.Count)" "Error"
    }
    
    # Métodos PENDING por clase
    if ($pending.Count -gt 0) {
        Write-ColoredMessage "`n=== MÉTODOS PENDING POR CLASE ===" "Info"
        
        $pendingByClass = $pending | Group-Object { 
            Split-Path $_.sourcePath -Leaf 
        } | Sort-Object Count -Descending
        
        foreach ($group in $pendingByClass) {
            Write-ColoredMessage "$($group.Name): $($group.Count) método(s)" "Yellow"
        }
    }
    else {
        Write-ColoredMessage "`n✓ No hay métodos PENDING" "Success"
    }
    
    # Métodos sin estado (posible error)
    if ($empty.Count -gt 0) {
        Write-ColoredMessage "`n=== MÉTODOS SIN ESTADO (REVISAR) ===" "Error"
        
        foreach ($item in $empty | Select-Object -First 10) {
            $fileName = Split-Path $item.sourcePath -Leaf
            Write-ColoredMessage "  - $fileName :: $($item.method)" "Error"
        }
        
        if ($empty.Count -gt 10) {
            Write-ColoredMessage "`n  ... y $($empty.Count - 10) más" "Error"
        }
    }
    
    # Estadísticas adicionales
    Write-ColoredMessage "`n=== ESTADÍSTICAS ===" "Info"
    
    $totalClasses = ($csv | Group-Object sourcePath).Count
    Write-ColoredMessage "Clases totales: $totalClasses" "White"
    
    $classesWithPending = ($pending | Group-Object sourcePath).Count
    Write-ColoredMessage "Clases con PENDING: $classesWithPending" "Yellow"
    
    $avgMethodsPerClass = [math]::Round($csv.Count / $totalClasses, 1)
    Write-ColoredMessage "Promedio métodos/clase: $avgMethodsPerClass" "Gray"
    
    # Progreso general
    $completed = $done.Count + $preexisting.Count
    $testable = $csv.Count - $excluded.Count - $empty.Count
    
    if ($testable -gt 0) {
        $progress = [math]::Round(($completed / $testable) * 100, 1)
        Write-ColoredMessage "`nProgreso: $progress% ($completed/$testable)" "Info"
    }
    
    Write-ColoredMessage ""
}
catch {
    Write-ColoredMessage "`nERROR: $_" "Error"
    Write-ColoredMessage $_.ScriptStackTrace "Error"
    exit 1
}

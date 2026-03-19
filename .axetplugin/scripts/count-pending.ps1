param(
    [string]$CsvPath = ".axetplugin/control.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    if (-not (Test-Path -LiteralPath $CsvPath)) {
        Write-Host ""
        Write-Host "ERROR: Archivo no encontrado: $CsvPath" -ForegroundColor Red
        Write-Host "Ejecute primero: generate-control-csv.ps1" -ForegroundColor Yellow
        exit 1
    }
    
    $csv = Import-Csv -LiteralPath $CsvPath -Delimiter ';' -Encoding UTF8
    
    if ($csv.Count -eq 0) {
        Write-Host ""
        Write-Host "ADVERTENCIA: El archivo CSV esta vacio" -ForegroundColor Yellow
        exit 0
    }
    
    $pending = @($csv | Where-Object { $_.status -eq 'PENDING' })
    $done = @($csv | Where-Object { $_.status -eq 'DONE' })
    $preexisting = @($csv | Where-Object { $_.status -eq 'PREEXISTING' })
    $excluded = @($csv | Where-Object { $_.status -eq 'EXCLUDED' })
    
    Write-Host ""
    Write-Host "=== RESUMEN CONTROL CSV ===" -ForegroundColor Cyan
    Write-Host "Archivo: $CsvPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Total metodos: $($csv.Count)" -ForegroundColor White
    Write-Host "PENDING: $($pending.Count)" -ForegroundColor Yellow
    Write-Host "DONE: $($done.Count)" -ForegroundColor Green
    Write-Host "PREEXISTING: $($preexisting.Count)" -ForegroundColor Gray
    Write-Host "EXCLUDED: $($excluded.Count)" -ForegroundColor Gray
    Write-Host ""
    
    if ($pending.Count -gt 0) {
        Write-Host "=== METODOS PENDING POR CLASE ===" -ForegroundColor Cyan
        $pendingByClass = $pending | Group-Object { Split-Path $_.sourcePath -Leaf } | Sort-Object Count -Descending
        foreach ($group in $pendingByClass) {
            $mensaje = "$($group.Name): $($group.Count) metodo(s)"
            Write-Host $mensaje -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    Write-Host "=== ESTADISTICAS ===" -ForegroundColor Cyan
    $totalClasses = ($csv | Group-Object sourcePath).Count
    Write-Host "Clases totales: $totalClasses" -ForegroundColor White
    
    $completed = $done.Count + $preexisting.Count
    $testable = $csv.Count - $excluded.Count
    
    if ($testable -gt 0) {
        $progress = [math]::Round(($completed / $testable) * 100, 1)
        $mensaje = "Progreso: $progress% ($completed/$testable)"
        Write-Host $mensaje -ForegroundColor Cyan
    }
    Write-Host ""
}
catch {
    Write-Host ""
    $errorMsg = $_.Exception.Message
    Write-Host "ERROR: $errorMsg" -ForegroundColor Red
    exit 1
}

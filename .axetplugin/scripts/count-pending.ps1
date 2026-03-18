param(
    [string]$CsvPath = ".axetplugin/control.csv"
)

$csv = Import-Csv -Path $CsvPath

$pending = $csv | Where-Object { $_.status -eq 'PENDING' }
$done = $csv | Where-Object { $_.status -eq 'DONE' }
$excluded = $csv | Where-Object { $_.status -eq 'EXCLUDED' }
$empty = $csv | Where-Object { -not $_.status }

Write-Host "`n=== RESUMEN CONTROL CSV ===" -ForegroundColor Cyan
Write-Host "Total métodos: $($csv.Count)" -ForegroundColor White
Write-Host "PENDING: $($pending.Count)" -ForegroundColor Yellow
Write-Host "DONE: $($done.Count)" -ForegroundColor Green
Write-Host "EXCLUDED: $($excluded.Count)" -ForegroundColor Gray
Write-Host "Sin estado: $($empty.Count)" -ForegroundColor Red

Write-Host "`n=== MÉTODOS PENDING POR CLASE ===" -ForegroundColor Cyan
$pending | Group-Object { Split-Path $_.sourcePath -Leaf } | Sort-Object Count -Descending | ForEach-Object {
    Write-Host "$($_.Name): $($_.Count) método(s)" -ForegroundColor Yellow
}

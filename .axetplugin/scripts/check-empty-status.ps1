$rows = Import-Csv ".axetplugin/control.csv" -Delimiter ';'
$empty = $rows | Where-Object { [string]::IsNullOrWhiteSpace($_.status) }

Write-Host "Total metodos sin estado: $($empty.Count)" -ForegroundColor Yellow
Write-Host "`nPrimeros 10 metodos sin estado:" -ForegroundColor Cyan
$empty | Select-Object -First 10 sourcePath, method | Format-Table -AutoSize

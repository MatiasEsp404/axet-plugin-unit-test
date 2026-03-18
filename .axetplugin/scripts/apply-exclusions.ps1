param(
    [string]$CsvPath = ".axetplugin/control.csv"
)

$csv = Import-Csv -Path $CsvPath

$excluded = 0

foreach ($row in $csv) {
    if ($row.status -ne 'PENDING') { continue }
    
    $path = $row.sourcePath
    
    # Excluir excepciones (constructores y getters simples)
    if ($path -match 'exceptions[\\/].*Exception\.java') {
        $row.status = 'EXCLUDED'
        $excluded++
        Write-Host "EXCLUDED: $($row.method) en $path"
        continue
    }
    
    # Excluir DefaultExceptionHandler
    if ($path -match 'DefaultExceptionHandler\.java') {
        $row.status = 'EXCLUDED'
        $excluded++
        Write-Host "EXCLUDED: $($row.method) en $path"
        continue
    }
}

# Guardar sin BOM
$lines = @("sourcePath,method,contentHash,status")
foreach ($row in $csv) {
    $lines += "$($row.sourcePath),$($row.method),$($row.contentHash),$($row.status)"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines((Resolve-Path $CsvPath), $lines, $utf8NoBom)

Write-Host "`nTotal métodos excluidos: $excluded" -ForegroundColor Green

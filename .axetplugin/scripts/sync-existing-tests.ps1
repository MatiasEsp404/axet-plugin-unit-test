param(
    [string]$TestRoot = "C:\Proyectos\rce-partidas-back\source\sp-business\src\test\java",
    [string]$CsvPath = ".axetplugin/control.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Sincronizando tests existentes..." -ForegroundColor Cyan

$controlData = Import-Csv -Path $CsvPath -Delimiter ";"

$testFiles = Get-ChildItem -Path $TestRoot -Recurse -Filter "*Test.java"

Write-Host "Archivos de test encontrados: $($testFiles.Count)" -ForegroundColor Gray

$methodsFound = 0
$classesProcessed = 0

foreach ($testFile in $testFiles) {
    $className = $testFile.BaseName -replace 'Test$', ''
    $classesProcessed++
    
    Write-Host "[$classesProcessed/$($testFiles.Count)] $className" -ForegroundColor DarkGray
    
    $content = Get-Content -Path $testFile.FullName -Raw
    
    # Buscar métodos con @Test (permite @DisplayName u otras anotaciones intermedias)
    $testMethods = [regex]::Matches($content, '@Test[\s\S]*?(?:void|public\s+void)\s+(\w+)\s*\(')
    
    if ($testMethods.Count -eq 0) {
        continue
    }
    
    # Extraer nombres base de los métodos de test
    $baseMethodNames = @()
    foreach ($match in $testMethods) {
        $fullTestName = $match.Groups[1].Value
        
        # Extraer el nombre base antes de _ o Should o When
        $baseName = $fullTestName
        if ($fullTestName -match '^([^_]+)') {
            $baseName = $matches[1]
        }
        
        if (-not ($baseMethodNames -contains $baseName)) {
            $baseMethodNames += $baseName
        }
    }
    
    # Obtener paquete del test (ej: ar\gob\gcaba\service\impl)
    $relativePath = $testFile.FullName.Replace($TestRoot, "").TrimStart("\")
    $packagePath = Split-Path -Parent $relativePath
    $packagePath = $packagePath -replace "\\", "/"
    
    # Construir ruta esperada
    $expectedPath = "$packagePath/$className.java"
    
    # Actualizar CSV
    $matchedForClass = 0
    for ($i = 0; $i -lt $controlData.Count; $i++) {
        $row = $controlData[$i]
        
        # Extraer la parte del paquete del sourcePath del CSV
        $csvPackagePart = $row.sourcePath
        if ($csvPackagePart -match 'src/main/java/(.+)$') {
            $csvPackagePart = $matches[1]
        }
        
        # Verificar si el sourcePath corresponde a esta clase y paquete
        if ($csvPackagePart -eq $expectedPath) {
            
            # Extraer nombre del método del CSV
            $csvMethodName = $row.method
            if ($csvMethodName -match '^([^\(]+)') {
                $csvBaseName = $matches[1]
                
                # Verificar si algún test cubre este método
                if ($baseMethodNames -contains $csvBaseName) {
                    if ($row.status -eq "PENDING") {
                        $controlData[$i].status = "PREEXISTING"
                        $methodsFound++
                        $matchedForClass++
                        Write-Host "    OK $csvBaseName -> PREEXISTING" -ForegroundColor Green
                    }
                }
            }
        }
    }
    
    if ($matchedForClass -gt 0) {
        Write-Host "  Total sincronizados: $matchedForClass" -ForegroundColor Cyan
    }
}

$lines = @("sourcePath;method;contentHash;status")
foreach ($item in $controlData) {
    $sourcePath = $item.sourcePath
    $method = $item.method
    $contentHash = $item.contentHash
    $status = $item.status
    $line = "$sourcePath;$method;$contentHash;$status"
    $lines += $line
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($CsvPath, $lines, $utf8NoBom)

Write-Host ""
Write-Host "Sincronizacion completada" -ForegroundColor Green
Write-Host "Metodos marcados como PREEXISTING: $methodsFound" -ForegroundColor Cyan

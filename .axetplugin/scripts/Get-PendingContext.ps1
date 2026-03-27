<#
.SYNOPSIS
  Obtiene el contexto de métodos pendientes de actualización (UPDATED)
  
.DESCRIPTION
  Filtra el control.csv por métodos con estado UPDATED y extrae:
  - Código fuente del método modificado
  - Código del test unitario correspondiente (si existe)
  
  Esto proporciona el contexto necesario para que la IA actualice los tests.
  
.PARAMETER CsvPath
  Ruta del archivo control.csv
  
.PARAMETER TestRoot
  Directorio raíz de tests (default: src/test/java)
  
.PARAMETER SourceRoot
  Directorio raíz del código fuente (default: src/main/java)
  
.PARAMETER OutputFormat
  Formato de salida: PSObject (default) o JSON
  
.OUTPUTS
  Array de objetos con contexto completo de métodos UPDATED
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvPath = ".axetplugin/control.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$TestRoot = "src/test/java",
    
    [Parameter(Mandatory=$false)]
    [string]$SourceRoot = "src/main/java",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("PSObject", "JSON")]
    [string]$OutputFormat = "PSObject"
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

function Get-TestFilePath {
    param(
        [string]$sourcePath,
        [string]$testRoot
    )
    
    # Convertir ruta de source a test
    # Ej: src/main/java/com/example/UserService.java -> src/test/java/com/example/UserServiceTest.java
    
    $relativePath = $sourcePath -replace [regex]::Escape($SourceRoot), $testRoot
    $testPath = $relativePath -replace "\.java$", "Test.java"
    
    return $testPath
}

function Extract-MethodBody {
    param(
        [string]$filePath,
        [string]$methodSignature
    )
    
    if (-not (Test-Path -LiteralPath $filePath)) {
        return $null
    }
    
    try {
        $content = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8
        
        # Buscar el método por su firma
        # Este es un approach simplificado, idealmente usaríamos el parser AST
        $methodPattern = [regex]::Escape($methodSignature.Split('(')[0])
        
        # Extraer contexto (50 líneas alrededor del método)
        $lines = $content -split "`r?`n"
        $methodLines = @()
        $inMethod = $false
        $braceCount = 0
        $startIndex = -1
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            # Detectar inicio del método
            if ($line -match $methodPattern -and $line -match '\(') {
                $inMethod = $true
                $startIndex = [Math]::Max(0, $i - 5)  # Incluir algunas líneas antes
                $braceCount = 0
            }
            
            if ($inMethod) {
                # Contar llaves
                $openBraces = ([regex]::Matches($line, '\{').Count)
                $closeBraces = ([regex]::Matches($line, '\}').Count)
                $braceCount += ($openBraces - $closeBraces)
                
                if ($braceCount -eq 0 -and $line -match '\}') {
                    # Fin del método
                    $endIndex = [Math]::Min($lines.Count - 1, $i + 3)  # Incluir algunas líneas después
                    $methodLines = $lines[$startIndex..$endIndex]
                    break
                }
            }
        }
        
        if ($methodLines.Count -gt 0) {
            return ($methodLines -join "`n")
        }
        
        return $null
    }
    catch {
        Write-Log "Error extrayendo método: $_" "ERROR"
        return $null
    }
}

function Get-TestMethodName {
    param([string]$methodSignature)
    
    # Convención común: testMethodName o methodName_shouldDoSomething
    $methodName = $methodSignature.Split('(')[0]
    return "test$methodName"
}

function Extract-TestMethod {
    param(
        [string]$testFilePath,
        [string]$methodSignature
    )
    
    if (-not (Test-Path -LiteralPath $testFilePath)) {
        return $null
    }
    
    try {
        $content = Get-Content -LiteralPath $testFilePath -Raw -Encoding UTF8
        
        # Buscar tests relacionados al método
        $methodName = $methodSignature.Split('(')[0]
        $testPattern = "test.*$methodName|$methodName.*Test"
        
        # Buscar todos los métodos de test que coincidan
        $matches = [regex]::Matches($content, "(@Test.*?public.*?void.*?($testPattern).*?\{)", [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        if ($matches.Count -eq 0) {
            return $null
        }
        
        # Retornar el primer test encontrado (con contexto)
        $lines = $content -split "`r?`n"
        $testMethods = @()
        
        foreach ($match in $matches) {
            $matchLine = ($content.Substring(0, $match.Index) -split "`r?`n").Count
            
            # Extraer método completo
            $inMethod = $false
            $braceCount = 0
            $methodLines = @()
            
            for ($i = [Math]::Max(0, $matchLine - 2); $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                
                if ($line -match '@Test' -or $line -match 'public.*void') {
                    $inMethod = $true
                }
                
                if ($inMethod) {
                    $methodLines += $line
                    
                    $openBraces = ([regex]::Matches($line, '\{').Count)
                    $closeBraces = ([regex]::Matches($line, '\}').Count)
                    $braceCount += ($openBraces - $closeBraces)
                    
                    if ($braceCount -eq 0 -and $line -match '\}' -and $methodLines.Count -gt 3) {
                        break
                    }
                }
            }
            
            if ($methodLines.Count -gt 0) {
                $testMethods += ($methodLines -join "`n")
            }
        }
        
        return ($testMethods -join "`n`n---`n`n")
    }
    catch {
        Write-Log "Error extrayendo test: $_" "ERROR"
        return $null
    }
}

# -------------------------------------------------
# Flujo Principal
# -------------------------------------------------

try {
    Write-Log "=== GET-PENDING-CONTEXT ===" "INFO"
    
    $cwd = (Get-Location).ProviderPath
    
    # Resolver ruta completa del CSV
    $fullCsvPath = if ([System.IO.Path]::IsPathRooted($CsvPath)) { 
        $CsvPath 
    } else { 
        Join-Path $cwd $CsvPath 
    }
    
    if (-not (Test-Path -LiteralPath $fullCsvPath)) {
        throw "Control.csv no encontrado: $fullCsvPath"
    }
    
    Write-Log "Leyendo control.csv: $fullCsvPath" "INFO"
    
    # Leer CSV y filtrar por UPDATED
    $rows = Import-Csv -LiteralPath $fullCsvPath -Delimiter ';' -Encoding UTF8
    $updatedMethods = $rows | Where-Object { $_.status -eq "UPDATED" }
    
    Write-Log "Métodos con estado UPDATED: $($updatedMethods.Count)" "INFO"
    
    if ($updatedMethods.Count -eq 0) {
        Write-Log "No hay métodos pendientes de actualización" "SUCCESS"
        
        if ($OutputFormat -eq "JSON") {
            return "[]"
        }
        else {
            return @()
        }
    }
    
    # Procesar cada método UPDATED
    $contextList = @()
    
    foreach ($method in $updatedMethods) {
        Write-Log "Procesando: $($method.method) en $($method.sourcePath)" "INFO"
        
        # Obtener ruta del archivo fuente
        $sourceFilePath = Join-Path $cwd $method.sourcePath
        
        # Obtener código del método modificado
        $methodBody = Extract-MethodBody -filePath $sourceFilePath -methodSignature $method.method
        
        # Obtener ruta del archivo de test
        $testFilePath = Get-TestFilePath -sourcePath $method.sourcePath -testRoot $TestRoot
        $testFilePathFull = Join-Path $cwd $testFilePath
        
        # Verificar si existe el archivo de test
        $testExists = Test-Path -LiteralPath $testFilePathFull
        
        # Extraer test correspondiente si existe
        $testBody = if ($testExists) {
            Extract-TestMethod -testFilePath $testFilePathFull -methodSignature $method.method
        } else {
            $null
        }
        
        $contextList += [PSCustomObject]@{
            SourcePath      = $method.sourcePath
            TestPath        = $testFilePath
            TestExists      = $testExists
            MethodSignature = $method.method
            ContentHash     = $method.contentHash
            MethodBody      = $methodBody
            TestBody        = $testBody
            Status          = $method.status
        }
        
        if ($testExists) {
            Write-Log "  ✓ Test encontrado: $testFilePath" "SUCCESS"
        }
        else {
            Write-Log "  ⚠ Test NO existe: $testFilePath" "WARN"
        }
    }
    
    # Resumen
    Write-Log "`n=== RESUMEN ===" "INFO"
    Write-Log "Total métodos UPDATED: $($contextList.Count)" "INFO"
    Write-Log "Con tests existentes: $(($contextList | Where-Object { $_.TestExists }).Count)" "SUCCESS"
    Write-Log "Sin tests: $(($contextList | Where-Object { -not $_.TestExists }).Count)" "WARN"
    
    # Output según formato
    if ($OutputFormat -eq "JSON") {
        return ($contextList | ConvertTo-Json -Depth 10)
    }
    else {
        return $contextList
    }
}
catch {
    Write-Log "ERROR CRÍTICO: $_" "ERROR"
    Write-Error $_
    exit 1
}

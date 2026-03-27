<#
.SYNOPSIS
  Actualiza el estado de un método en control.csv después de actualizar su test
  
.DESCRIPTION
  Recalcula el hash del método, valida que el proyecto compila correctamente,
  y actualiza su estado a DONE en control.csv.
  Si la compilación falla, marca el estado como ERROR_COMPILATION.
  
.PARAMETER SourcePath
  Ruta relativa del archivo fuente (ej: src/main/java/com/example/UserService.java)
  
.PARAMETER MethodSignature
  Firma del método (ej: findById(Long))
  
.PARAMETER CsvPath
  Ruta del archivo control.csv (default: .axetplugin/control.csv)
  
.PARAMETER ParserJar
  Ruta al JAR del parser
  
.PARAMETER SkipCompilation
  Si es $true, omite la validación de compilación (default: $false)
  
.OUTPUTS
  Retorna el nuevo estado del método
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory=$true)]
    [string]$MethodSignature,
    
    [Parameter(Mandatory=$false)]
    [string]$CsvPath = ".axetplugin/control.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$ParserJar = "tools/java-parser/target/java-method-parser.jar",
    
    [Parameter(Mandatory=$false)]
    [bool]$SkipCompilation = $false
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

function Get-CurrentMethodHash {
    param(
        [string]$sourcePath,
        [string]$methodSignature,
        [string]$jarPath
    )
    
    $cwd = (Get-Location).ProviderPath
    $fullPath = Join-Path $cwd $sourcePath
    
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Archivo fuente no encontrado: $fullPath"
    }
    
    # Usar el parser para obtener el hash actual
    try {
        $jsonOutput = & java -jar $jarPath $fullPath 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Error parseando archivo: $fullPath"
        }
        
        # Filtrar JSON válido
        $jsonLines = $jsonOutput | Where-Object { $_ -match '^\s*[\[\{]' }
        $jsonString = $jsonLines -join "`n"
        $methods = $jsonString | ConvertFrom-Json
        
        # Buscar el método específico
        $targetMethod = $methods | Where-Object { $_.methodSignature -eq $methodSignature }
        
        if ($null -eq $targetMethod) {
            throw "Método no encontrado: $methodSignature en $sourcePath"
        }
        
        return $targetMethod.contentHash
    }
    catch {
        Write-Log "Error obteniendo hash: $_" "ERROR"
        throw
    }
}

function Get-BuildTool {
    param([string]$projectRoot)
    
    # Detectar Maven
    if (Test-Path (Join-Path $projectRoot "pom.xml")) {
        return "maven"
    }
    
    # Detectar Gradle
    if ((Test-Path (Join-Path $projectRoot "build.gradle")) -or 
        (Test-Path (Join-Path $projectRoot "build.gradle.kts"))) {
        return "gradle"
    }
    
    return $null
}

function Test-ProjectCompilation {
    param(
        [string]$projectRoot,
        [string]$buildTool
    )
    
    Write-Log "Validando compilación del proyecto..." "INFO"
    Write-Log "Build tool detectado: $buildTool" "INFO"
    
    $originalLocation = Get-Location
    
    try {
        Set-Location $projectRoot
        
        $compileCommand = switch ($buildTool) {
            "maven" { 
                "mvn test-compile -q"
            }
            "gradle" { 
                if (Test-Path "gradlew.bat") {
                    ".\gradlew.bat testClasses --quiet"
                } else {
                    "gradle testClasses --quiet"
                }
            }
            default {
                throw "Build tool no soportado: $buildTool"
            }
        }
        
        Write-Log "Ejecutando: $compileCommand" "INFO"
        
        # Capturar output completo
        $output = Invoke-Expression $compileCommand 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Log "Compilación exitosa" "SUCCESS"
            return @{
                Success = $true
                Output = $output
            }
        }
        else {
            Write-Log "Compilación falló (exit code: $exitCode)" "ERROR"
            Write-Log "Output:" "ERROR"
            $output | ForEach-Object { Write-Log "  $_" "ERROR" }
            
            return @{
                Success = $false
                Output = $output
                ExitCode = $exitCode
            }
        }
    }
    catch {
        Write-Log "Error durante compilación: $_" "ERROR"
        return @{
            Success = $false
            Output = $_.Exception.Message
            Error = $_
        }
    }
    finally {
        Set-Location $originalLocation
    }
}

function Get-ProjectRoot {
    param([string]$sourcePath)
    
    $cwd = (Get-Location).ProviderPath
    $currentPath = Split-Path (Join-Path $cwd $sourcePath) -Parent
    
    # Buscar hacia arriba hasta encontrar pom.xml o build.gradle
    while ($currentPath -and $currentPath -ne [System.IO.Path]::GetPathRoot($currentPath)) {
        if ((Test-Path (Join-Path $currentPath "pom.xml")) -or 
            (Test-Path (Join-Path $currentPath "build.gradle")) -or
            (Test-Path (Join-Path $currentPath "build.gradle.kts"))) {
            return $currentPath
        }
        $currentPath = Split-Path $currentPath -Parent
    }
    
    # Si no se encuentra, usar el directorio actual
    return $cwd
}

# -------------------------------------------------
# Flujo Principal
# -------------------------------------------------

try {
    Write-Log "=== UPDATE-TEST-STATUS ===" "INFO"
    
    $cwd = (Get-Location).ProviderPath
    
    # Validar JAR del parser
    $jarFullPath = if ([System.IO.Path]::IsPathRooted($ParserJar)) { 
        $ParserJar 
    } else { 
        Join-Path $cwd $ParserJar 
    }
    
    if (-not (Test-Path -LiteralPath $jarFullPath)) {
        throw "JAR del parser no encontrado: $jarFullPath"
    }
    
    # Resolver ruta del CSV
    $fullCsvPath = if ([System.IO.Path]::IsPathRooted($CsvPath)) { 
        $CsvPath 
    } else { 
        Join-Path $cwd $CsvPath 
    }
    
    if (-not (Test-Path -LiteralPath $fullCsvPath)) {
        throw "Control.csv no encontrado: $fullCsvPath"
    }
    
    Write-Log "Actualizando: $MethodSignature en $SourcePath" "INFO"
    
    # Recalcular hash actual del método
    Write-Log "Recalculando hash del método..." "INFO"
    $newHash = Get-CurrentMethodHash -sourcePath $SourcePath -methodSignature $MethodSignature -jarPath $jarFullPath
    Write-Log "Nuevo hash: $newHash" "INFO"
    
    # Determinar nuevo estado (DONE o ERROR_COMPILATION)
    $newStatus = "DONE"
    $compilationResult = $null
    
    if (-not $SkipCompilation) {
        # Detectar proyecto root y build tool
        $projectRoot = Get-ProjectRoot -sourcePath $SourcePath
        $buildTool = Get-BuildTool -projectRoot $projectRoot
        
        if ($null -eq $buildTool) {
            Write-Log "No se detectó build tool (Maven/Gradle). Omitiendo validación de compilación." "WARN"
        }
        else {
            Write-Log "Proyecto root: $projectRoot" "INFO"
            
            # Validar compilación
            $compilationResult = Test-ProjectCompilation -projectRoot $projectRoot -buildTool $buildTool
            
            if (-not $compilationResult.Success) {
                $newStatus = "ERROR_COMPILATION"
                Write-Log "El test generado no compila correctamente" "ERROR"
                Write-Log "Estado será marcado como: ERROR_COMPILATION" "WARN"
            }
        }
    }
    else {
        Write-Log "Validación de compilación omitida (SkipCompilation=true)" "WARN"
    }
    
    # Leer CSV actual
    $rows = Import-Csv -LiteralPath $fullCsvPath -Delimiter ';' -Encoding UTF8
    
    # Buscar y actualizar la fila correspondiente
    $key = "$SourcePath|$MethodSignature"
    $found = $false
    $oldStatus = $null
    
    foreach ($row in $rows) {
        $rowKey = "$($row.sourcePath)|$($row.method)"
        
        if ($rowKey -eq $key) {
            $found = $true
            $oldStatus = $row.status
            
            # Actualizar hash y estado
            $row.contentHash = $newHash
            $row.status = $newStatus
            
            $statusColor = if ($newStatus -eq "DONE") { "SUCCESS" } else { "ERROR" }
            Write-Log "Estado actualizado: $oldStatus → $newStatus" $statusColor
            break
        }
    }
    
    if (-not $found) {
        throw "Método no encontrado en control.csv: $key"
    }
    
    # Escribir CSV actualizado (UTF-8 sin BOM)
    $lines = @("sourcePath;method;contentHash;status")
    
    foreach ($row in ($rows | Sort-Object sourcePath, method)) {
        $line = "{0};{1};{2};{3}" -f `
            (Escape-CsvField $row.sourcePath),
            (Escape-CsvField $row.method),
            (Escape-CsvField $row.contentHash),
            (Escape-CsvField $row.status)
        $lines += $line
    }
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($fullCsvPath, $lines, $utf8NoBom)
    
    Write-Log "CSV actualizado: $fullCsvPath" "SUCCESS"
    
    # Retornar información del update
    return [PSCustomObject]@{
        SourcePath         = $SourcePath
        MethodSignature    = $MethodSignature
        OldStatus          = $oldStatus
        NewStatus          = $newStatus
        NewHash            = $newHash
        CsvPath            = $fullCsvPath
        CompilationSuccess = if ($compilationResult) { $compilationResult.Success } else { $null }
        CompilationOutput  = if ($compilationResult) { $compilationResult.Output } else { $null }
    }
}
catch {
    Write-Log "ERROR CRÍTICO: $_" "ERROR"
    Write-Error $_
    exit 1
}

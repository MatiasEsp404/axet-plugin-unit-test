<#
.SYNOPSIS
  Actualiza el estado de un método en control.csv después de actualizar su test
  
.DESCRIPTION
  Recalcula el hash del método y actualiza su estado a DONE en control.csv.
  Este script se ejecuta después de que la IA haya actualizado el test unitario.
  
.PARAMETER SourcePath
  Ruta relativa del archivo fuente (ej: src/main/java/com/example/UserService.java)
  
.PARAMETER MethodSignature
  Firma del método (ej: findById(Long))
  
.PARAMETER CsvPath
  Ruta del archivo control.csv (default: .axetplugin/control.csv)
  
.PARAMETER ParserJar
  Ruta al JAR del parser
  
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
            $row.status = "DONE"
            
            Write-Log "Estado actualizado: $oldStatus → DONE" "SUCCESS"
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
        SourcePath      = $SourcePath
        MethodSignature = $MethodSignature
        OldStatus       = $oldStatus
        NewStatus       = "DONE"
        NewHash         = $newHash
        CsvPath         = $fullCsvPath
    }
}
catch {
    Write-Log "ERROR CRÍTICO: $_" "ERROR"
    Write-Error $_
    exit 1
}

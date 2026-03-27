<#
.SYNOPSIS
  Obtiene el contexto de métodos pendientes de actualización (UPDATED/PENDING)
  
.DESCRIPTION
  Filtra el control.csv por métodos con estado UPDATED o PENDING y extrae:
  - Código fuente del método modificado
  - Código del test unitario correspondiente (si existe)
  
  Esto proporciona el contexto necesario para que la IA actualice los tests.
  
.PARAMETER CsvPath
  Ruta del archivo control.csv
  
.PARAMETER MaxMethods
  Número máximo de métodos a procesar (default: 10)
  
.PARAMETER OutputFormat
  Formato de salida: PSObject (default) o JSON
  
.OUTPUTS
  Array de objetos con contexto completo de métodos UPDATED/PENDING
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvPath = ".axetplugin/control.csv",
    
    [Parameter(Mandatory=$false)]
    [int]$MaxMethods = 10,
    
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
    
    # Leer CSV y filtrar por UPDATED o PENDING
    $rows = Import-Csv -LiteralPath $fullCsvPath -Delimiter ';' -Encoding UTF8
    $pendingMethods = $rows | Where-Object { $_.status -eq "UPDATED" -or $_.status -eq "PENDING" }
    
    Write-Log "Métodos con estado UPDATED/PENDING: $($pendingMethods.Count)" "INFO"
    
    if ($pendingMethods.Count -eq 0) {
        Write-Log "No hay métodos pendientes de actualización" "SUCCESS"
        
        if ($OutputFormat -eq "JSON") {
            return "[]"
        }
        else {
            return @()
        }
    }
    
    # Limitar a MaxMethods
    if ($pendingMethods.Count -gt $MaxMethods) {
        Write-Log "Limitando procesamiento a $MaxMethods métodos" "WARN"
        $pendingMethods = $pendingMethods | Select-Object -First $MaxMethods
    }
    
    # Procesar cada método PENDING/UPDATED
    $contextList = @()
    
    foreach ($method in $pendingMethods) {
        Write-Log "Procesando: $($method.method) en $($method.sourcePath)" "INFO"
        
        # Obtener ruta del archivo fuente
        $sourceFilePath = Join-Path $cwd $method.sourcePath
        
        # Leer archivo completo
        $sourceContent = if (Test-Path -LiteralPath $sourceFilePath) {
            Get-Content -LiteralPath $sourceFilePath -Raw -Encoding UTF8
        } else {
            $null
        }
        
        $contextList += [PSCustomObject]@{
            SourcePath      = $method.sourcePath
            MethodSignature = $method.method
            ContentHash     = $method.contentHash
            SourceContent   = $sourceContent
            Status          = $method.status
        }
        
        if ($sourceContent) {
            Write-Log "  OK Archivo leído: $($method.sourcePath)" "SUCCESS"
        } else {
            Write-Log "  ERROR Archivo no encontrado: $($method.sourcePath)" "ERROR"
        }
    }
    
    # Resumen
    Write-Log "" "INFO"
    Write-Log "=== RESUMEN ===" "INFO"
    Write-Log "Total métodos procesados: $($contextList.Count)" "INFO"
    Write-Log "Archivos encontrados: $(($contextList | Where-Object { $_.SourceContent }).Count)" "SUCCESS"
    $missing = @($contextList | Where-Object { -not $_.SourceContent })
    Write-Log "Archivos faltantes: $($missing.Count)" "WARN"
    
    # Output según formato
    if ($OutputFormat -eq "JSON") {
        return ($contextList | ConvertTo-Json -Depth 10)
    }
    else {
        return $contextList
    }
}
catch {
    Write-Log "ERROR CRITICO: $($_.Exception.Message)" "ERROR"
    Write-Error $_
    exit 1
}

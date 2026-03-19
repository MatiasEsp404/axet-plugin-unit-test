<#
.SYNOPSIS
  Aplica exclusiones automáticas a métodos en el archivo control.csv
  
.DESCRIPTION
  Marca como EXCLUDED métodos que según lineamientos no deben testearse:
  - Constructores y getters/setters en clases de excepción
  - Métodos de exception handlers
  - Event listeners
  - Configuraciones simples
  
.PARAMETER CsvPath
  Ruta del archivo control.csv a procesar
  
.PARAMETER DryRun
  Si se especifica, solo muestra qué se excluiría sin modificar el archivo
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvPath = ".axetplugin/control.csv",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
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
        default   { Write-Host $Message }
    }
}

function Should-Exclude {
    param(
        [string]$sourcePath,
        [string]$method
    )
    
    # Normalizar ruta para comparaciones
    $pathLower = $sourcePath.ToLower()
    $methodLower = $method.ToLower()
    
    # REGLA 1: Excepciones - constructores y getters simples
    if ($pathLower -match '[\\/]exceptions?[\\/].*exception\.java$') {
        # Excluir constructores
        if ($methodLower -match '^\w+Exception\(') {
            return $true, "Constructor de excepción"
        }
        # Excluir getters simples
        if ($methodLower -match '^get\w+\(\s*\)$') {
            return $true, "Getter simple en excepción"
        }
    }
    
    # REGLA 2: Exception Handlers - todos los métodos
    if ($pathLower -match 'exceptionhandler\.java$' -or 
        $pathLower -match '[\\/]handlers?[\\/].*handler\.java$') {
        return $true, "Exception handler"
    }
    
    # REGLA 3: Event Listeners
    if ($pathLower -match 'listener\.java$' -or 
        $methodLower -match '^on[A-Z]\w+Event\(') {
        return $true, "Event listener"
    }
    
    # REGLA 4: Configuraciones - métodos simples (@Bean)
    if ($pathLower -match '[\\/]config(uration)?[\\/]' -or 
        $pathLower -match 'config\.java$') {
        # Solo excluir métodos que parecen configuraciones simples
        if ($methodLower -match '^(get|create|build)\w+(Bean|Config|Factory)\(') {
            return $true, "Método de configuración"
        }
    }
    
    # REGLA 5: DTOs - solo getters y setters
    if ($pathLower -match '[\\/]dto(s)?[\\/]' -or $pathLower -match 'dto\.java$') {
        if ($methodLower -match '^(get|set|is)\w+\(') {
            return $true, "Getter/Setter en DTO"
        }
    }
    
    return $false, ""
}

# -------------------------------------------------
# Flujo Principal
# -------------------------------------------------

try {
    Write-ColoredMessage "`n=== APLICAR EXCLUSIONES AUTOMÁTICAS ===" "Info"
    
    if ($DryRun) {
        Write-ColoredMessage "Modo: DRY RUN (solo simulación)" "Warning"
    }
    
    # Validar existencia del archivo
    if (-not (Test-Path -LiteralPath $CsvPath)) {
        Write-ColoredMessage "`nERROR: Archivo no encontrado: $CsvPath" "Error"
        Write-ColoredMessage "Ejecute primero: generate-control-csv.ps1" "Warning"
        exit 1
    }
    
    # Leer CSV
    $csv = Import-Csv -LiteralPath $CsvPath -Delimiter ';' -Encoding UTF8
    
    if ($csv.Count -eq 0) {
        Write-ColoredMessage "`nADVERTENCIA: El archivo CSV está vacío" "Warning"
        exit 0
    }
    
    Write-ColoredMessage "Total métodos: $($csv.Count)" "Gray"
    
    # Procesar exclusiones
    $excluded = 0
    $alreadyExcluded = 0
    $exclusionReasons = @{}
    
    foreach ($row in $csv) {
        # Solo procesar métodos PENDING
        if ($row.status -ne 'PENDING') {
            if ($row.status -eq 'EXCLUDED') {
                $alreadyExcluded++
            }
            continue
        }
        
        $shouldExclude, $reason = Should-Exclude -sourcePath $row.sourcePath -method $row.method
        
        if ($shouldExclude) {
            $excluded++
            
            # Contabilizar razones
            if (-not $exclusionReasons.ContainsKey($reason)) {
                $exclusionReasons[$reason] = 0
            }
            $exclusionReasons[$reason]++
            
            # Mostrar detalle
            $fileName = Split-Path $row.sourcePath -Leaf
            Write-ColoredMessage "  [EXCLUDE] $fileName :: $($row.method)" "Yellow"
            Write-ColoredMessage "            Razón: $reason" "Gray"
            
            # Marcar como excluido (si no es dry run)
            if (-not $DryRun) {
                $row.status = 'EXCLUDED'
            }
        }
    }
    
    # Resumen de exclusiones
    Write-ColoredMessage "`n=== RESUMEN DE EXCLUSIONES ===" "Info"
    Write-ColoredMessage "Ya excluidos previamente: $alreadyExcluded" "Gray"
    Write-ColoredMessage "Métodos a excluir: $excluded" "Warning"
    
    if ($excluded -gt 0) {
        Write-ColoredMessage "`nPor razón:" "Info"
        foreach ($reason in $exclusionReasons.Keys | Sort-Object) {
            Write-ColoredMessage "  - $reason : $($exclusionReasons[$reason])" "Yellow"
        }
    }
    
    # Guardar cambios (si no es dry run)
    if (-not $DryRun -and $excluded -gt 0) {
        Write-ColoredMessage "`nGuardando cambios..." "Info"
        
        # Generar líneas CSV usando punto y coma como separador
        $lines = @("sourcePath;method;contentHash;status")
        
        foreach ($row in $csv) {
            # Escapar campos que contengan punto y coma o comillas
            $sourcePath = $row.sourcePath
            $method = $row.method
            $contentHash = $row.contentHash
            $status = $row.status
            
            # Escape simple
            if ($sourcePath -match '[;"]') { $sourcePath = '"' + ($sourcePath -replace '"', '""') + '"' }
            if ($method -match '[;"]') { $method = '"' + ($method -replace '"', '""') + '"' }
            if ($contentHash -match '[;"]') { $contentHash = '"' + ($contentHash -replace '"', '""') + '"' }
            if ($status -match '[;"]') { $status = '"' + ($status -replace '"', '""') + '"' }
            
            $lines += "$sourcePath;$method;$contentHash;$status"
        }
        
        # Escribir archivo (UTF-8 sin BOM)
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines((Resolve-Path $CsvPath).Path, $lines, $utf8NoBom)
        
        Write-ColoredMessage "Archivo actualizado: $CsvPath" "Success"
    }
    elseif ($DryRun -and $excluded -gt 0) {
        Write-ColoredMessage "`nNo se realizaron cambios (DRY RUN)" "Warning"
        Write-ColoredMessage "Ejecute sin -DryRun para aplicar cambios" "Info"
    }
    elseif ($excluded -eq 0) {
        Write-ColoredMessage "`nNo se encontraron métodos para excluir" "Success"
    }
    
    Write-ColoredMessage ""
}
catch {
    Write-ColoredMessage "`nERROR: $_" "Error"
    Write-ColoredMessage $_.ScriptStackTrace "Error"
    exit 1
}

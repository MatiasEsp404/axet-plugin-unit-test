<#
.SYNOPSIS
  Orquestador maestro del Agentic Workflow para generación/actualización de tests unitarios
  
.DESCRIPTION
  Este script automatiza el proceso completo:
  1. Sincroniza el inventario de métodos (Sync-TestInventory)
  2. Identifica métodos PENDING que requieren tests
  3. Para cada método PENDING:
     - Obtiene contexto del código fuente
     - Genera/actualiza el test unitario (requiere intervención del LLM)
     - Valida compilación
     - Actualiza estado en control.csv
  4. Genera reporte final con estadísticas
  
.PARAMETER SourceRoot
  Ruta raíz donde están los archivos .java a analizar (default: tools/java-parser/test-samples)
  
.PARAMETER CsvPath
  Ruta del archivo control.csv (default: .axetplugin/control.csv)
  
.PARAMETER ParserJar
  Ruta al JAR del parser (default: tools/java-parser/target/java-method-parser.jar)
  
.PARAMETER SkipCompilation
  Si es $true, omite validación de compilación (útil para debugging)
  
.PARAMETER InteractiveMode
  Si es $true, espera confirmación del usuario después de mostrar el contexto de cada método
  
.OUTPUTS
  Reporte final con estadísticas de procesamiento
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SourceRoot = "tools/java-parser/test-samples",
    
    [Parameter(Mandatory=$false)]
    [string]$CsvPath = ".axetplugin/control.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$ParserJar = "tools/java-parser/target/java-method-parser.jar",
    
    [Parameter(Mandatory=$false)]
    [bool]$SkipCompilation = $false,
    
    [Parameter(Mandatory=$false)]
    [bool]$InteractiveMode = $true
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
        "TITLE" { "Magenta" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-Section {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host " $Title" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
}

function Get-Statistics {
    param([string]$csvPath)
    
    $rows = Import-Csv -LiteralPath $csvPath -Delimiter ';' -Encoding UTF8
    
    $stats = @{
        Total = $rows.Count
        PENDING = ($rows | Where-Object { $_.status -eq "PENDING" }).Count
        DONE = ($rows | Where-Object { $_.status -eq "DONE" }).Count
        PREEXISTING = ($rows | Where-Object { $_.status -eq "PREEXISTING" }).Count
        EXCLUDED = ($rows | Where-Object { $_.status -eq "EXCLUDED" }).Count
        ERROR_COMPILATION = ($rows | Where-Object { $_.status -eq "ERROR_COMPILATION" }).Count
    }
    
    return $stats
}

function Show-Statistics {
    param(
        [hashtable]$stats,
        [string]$title = "ESTADÍSTICAS ACTUALES"
    )
    
    Write-Host ""
    Write-Host "─── $title ───" -ForegroundColor Cyan
    Write-Host "Total métodos         : $($stats.Total)" -ForegroundColor White
    Write-Host "PENDING               : $($stats.PENDING)" -ForegroundColor Yellow
    Write-Host "DONE                  : $($stats.DONE)" -ForegroundColor Green
    Write-Host "PREEXISTING           : $($stats.PREEXISTING)" -ForegroundColor Cyan
    Write-Host "EXCLUDED              : $($stats.EXCLUDED)" -ForegroundColor Gray
    Write-Host "ERROR_COMPILATION     : $($stats.ERROR_COMPILATION)" -ForegroundColor Red
    
    if ($stats.Total -gt 0) {
        $progress = [math]::Round(($stats.DONE + $stats.PREEXISTING) * 100.0 / $stats.Total, 1)
        Write-Host "Progreso              : $progress%" -ForegroundColor $(if ($progress -eq 100) { "Green" } else { "Yellow" })
    }
    Write-Host ""
}

# -------------------------------------------------
# Flujo Principal
# -------------------------------------------------

try {
    $cwd = (Get-Location).ProviderPath
    $fullCsvPath = if ([System.IO.Path]::IsPathRooted($CsvPath)) { $CsvPath } else { Join-Path $cwd $CsvPath }
    
    Write-Section "AGENTIC WORKFLOW - ORQUESTADOR MAESTRO"
    
    Write-Log "Directorio de trabajo: $cwd" "INFO"
    Write-Log "Control CSV: $fullCsvPath" "INFO"
    Write-Log "Source Root: $SourceRoot" "INFO"
    Write-Log "Modo interactivo: $InteractiveMode" "INFO"
    
    # =========================================
    # FASE 1: SINCRONIZAR INVENTARIO
    # =========================================
    
    Write-Section "FASE 1: SINCRONIZACIÓN DE INVENTARIO"
    
    Write-Log "Ejecutando Sync-TestInventory.ps1..." "INFO"
    
    $syncScript = Join-Path $cwd ".axetplugin\scripts\Sync-TestInventory.ps1"
    
    if (-not (Test-Path -LiteralPath $syncScript)) {
        throw "Script no encontrado: $syncScript"
    }
    
    & $syncScript -SourceRoot $SourceRoot -CsvPath $CsvPath -ParserJar $ParserJar
    
    if ($LASTEXITCODE -ne 0) {
        throw "Error ejecutando Sync-TestInventory.ps1"
    }
    
    Write-Log "Sincronización completada" "SUCCESS"
    
    # =========================================
    # FASE 2: ANALIZAR ESTADO ACTUAL
    # =========================================
    
    Write-Section "FASE 2: ANÁLISIS DE ESTADO"
    
    if (-not (Test-Path -LiteralPath $fullCsvPath)) {
        throw "Control CSV no encontrado después de sincronización: $fullCsvPath"
    }
    
    $initialStats = Get-Statistics -csvPath $fullCsvPath
    Show-Statistics -stats $initialStats -title "ESTADÍSTICAS INICIALES"
    
    # Obtener métodos PENDING
    $rows = Import-Csv -LiteralPath $fullCsvPath -Delimiter ';' -Encoding UTF8
    $pendingMethods = $rows | Where-Object { $_.status -eq "PENDING" }
    
    if ($pendingMethods.Count -eq 0) {
        Write-Log "No hay métodos PENDING. El inventario está sincronizado." "SUCCESS"
        Write-Section "PROCESO COMPLETADO"
        exit 0
    }
    
    Write-Log "Encontrados $($pendingMethods.Count) métodos que requieren generación/actualización de tests" "WARN"
    
    # =========================================
    # FASE 3: PROCESAR MÉTODOS PENDING
    # =========================================
    
    Write-Section "FASE 3: PROCESAMIENTO DE MÉTODOS PENDING"
    
    Write-Host ""
    Write-Host "IMPORTANTE: Este script mostrará el contexto de cada método PENDING." -ForegroundColor Yellow
    Write-Host "Deberás generar/actualizar los tests manualmente o usar el LLM." -ForegroundColor Yellow
    Write-Host ""
    
    if ($InteractiveMode) {
        Write-Host "Presiona ENTER para continuar o CTRL+C para cancelar..." -ForegroundColor Cyan
        Read-Host
    }
    
    # Contadores para estadísticas finales
    $processedCount = 0
    $successCount = 0
    $errorCompilationCount = 0
    $skippedCount = 0
    $results = @()
    
    foreach ($method in $pendingMethods) {
        $processedCount++
        
        Write-Host ""
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
        Write-Host " [$processedCount/$($pendingMethods.Count)] Procesando método" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
        Write-Host "Clase  : $($method.sourcePath)" -ForegroundColor White
        Write-Host "Método : $($method.method)" -ForegroundColor White
        Write-Host "Hash   : $($method.contentHash)" -ForegroundColor Gray
        Write-Host ""
        
        # Obtener contexto del método usando Get-PendingContext.ps1
        Write-Log "Obteniendo contexto del método..." "INFO"
        
        try {
            $contextScript = Join-Path $cwd ".axetplugin\scripts\Get-PendingContext.ps1"
            
            $contextParams = @{
                SourcePath = $method.sourcePath
                MethodSignature = $method.method
                CsvPath = $CsvPath
                ParserJar = $ParserJar
            }
            
            $context = & $contextScript @contextParams
            
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Error obteniendo contexto del método" "ERROR"
                $skippedCount++
                continue
            }
            
            Write-Host "───── CONTEXTO DEL MÉTODO ─────" -ForegroundColor Cyan
            Write-Host $context -ForegroundColor White
            Write-Host "────────────────────────────────" -ForegroundColor Cyan
            Write-Host ""
            
            # Aquí es donde el LLM debe intervenir para generar/actualizar el test
            Write-Host "ACCIÓN REQUERIDA:" -ForegroundColor Yellow
            Write-Host "1. Analiza el código del método mostrado arriba" -ForegroundColor Yellow
            Write-Host "2. Genera/actualiza el test unitario correspondiente" -ForegroundColor Yellow
            Write-Host "3. Guarda el archivo de test en la ubicación correcta" -ForegroundColor Yellow
            Write-Host ""
            
            if ($InteractiveMode) {
                Write-Host "¿Test generado/actualizado? (s/n/skip): " -ForegroundColor Cyan -NoNewline
                $response = Read-Host
                
                if ($response -eq "skip" -or $response -eq "s") {
                    if ($response -eq "skip") {
                        Write-Log "Método omitido por el usuario" "WARN"
                        $skippedCount++
                        continue
                    }
                }
                elseif ($response -ne "s") {
                    Write-Log "Método omitido (respuesta: $response)" "WARN"
                    $skippedCount++
                    continue
                }
            }
            
            # Actualizar estado y validar compilación
            Write-Log "Actualizando estado del método..." "INFO"
            
            $updateScript = Join-Path $cwd ".axetplugin\scripts\Update-TestStatus.ps1"
            
            $updateParams = @{
                SourcePath = $method.sourcePath
                MethodSignature = $method.method
                CsvPath = $CsvPath
                ParserJar = $ParserJar
                SkipCompilation = $SkipCompilation
            }
            
            $updateResult = & $updateScript @updateParams
            
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Error actualizando estado del método" "ERROR"
                $skippedCount++
                continue
            }
            
            # Registrar resultado
            $results += [PSCustomObject]@{
                SourcePath = $method.sourcePath
                Method = $method.method
                OldStatus = $updateResult.OldStatus
                NewStatus = $updateResult.NewStatus
                CompilationSuccess = $updateResult.CompilationSuccess
            }
            
            if ($updateResult.NewStatus -eq "DONE") {
                Write-Log "✓ Método actualizado a DONE" "SUCCESS"
                $successCount++
            }
            elseif ($updateResult.NewStatus -eq "ERROR_COMPILATION") {
                Write-Log "✗ Método marcado como ERROR_COMPILATION" "ERROR"
                $errorCompilationCount++
            }
        }
        catch {
            Write-Log "Error procesando método: $_" "ERROR"
            $skippedCount++
        }
        
        Write-Host ""
    }
    
    # =========================================
    # FASE 4: REPORTE FINAL
    # =========================================
    
    Write-Section "FASE 4: REPORTE FINAL"
    
    $finalStats = Get-Statistics -csvPath $fullCsvPath
    Show-Statistics -stats $finalStats -title "ESTADÍSTICAS FINALES"
    
    Write-Host "─── RESUMEN DE PROCESAMIENTO ───" -ForegroundColor Magenta
    Write-Host "Métodos procesados    : $processedCount" -ForegroundColor White
    Write-Host "Exitosos (DONE)       : $successCount" -ForegroundColor Green
    Write-Host "Errores compilación   : $errorCompilationCount" -ForegroundColor Red
    Write-Host "Omitidos              : $skippedCount" -ForegroundColor Yellow
    Write-Host ""
    
    if ($results.Count -gt 0) {
        Write-Host "─── DETALLE DE CAMBIOS ───" -ForegroundColor Cyan
        foreach ($result in $results) {
            $statusIcon = if ($result.NewStatus -eq "DONE") { "✓" } else { "✗" }
            $statusColor = if ($result.NewStatus -eq "DONE") { "Green" } else { "Red" }
            
            Write-Host "$statusIcon " -ForegroundColor $statusColor -NoNewline
            Write-Host "$($result.Method)" -ForegroundColor White -NoNewline
            Write-Host " [$($result.OldStatus) → $($result.NewStatus)]" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Recomendaciones finales
    if ($errorCompilationCount -gt 0) {
        Write-Host "⚠ ATENCIÓN: Hay métodos con ERROR_COMPILATION" -ForegroundColor Red
        Write-Host "  Revisa los tests generados y corrígelos manualmente." -ForegroundColor Yellow
        Write-Host "  Luego ejecuta Sync-TestInventory.ps1 para resincronizar." -ForegroundColor Yellow
        Write-Host ""
    }
    
    if ($finalStats.PENDING -gt 0) {
        Write-Host "ℹ INFO: Aún quedan $($finalStats.PENDING) métodos PENDING" -ForegroundColor Cyan
        Write-Host "  Ejecuta este script nuevamente para procesarlos." -ForegroundColor Cyan
        Write-Host ""
    }
    
    Write-Section "PROCESO COMPLETADO"
    
    Write-Log "Orquestador finalizado exitosamente" "SUCCESS"
    exit 0
}
catch {
    Write-Log "ERROR CRÍTICO: $_" "ERROR"
    Write-Error $_
    exit 1
}

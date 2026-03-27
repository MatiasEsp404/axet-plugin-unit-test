<#
.SYNOPSIS
  Extrae hashes de métodos Java usando el CLI AST-based
  
.DESCRIPTION
  Escanea archivos Java en un directorio y retorna un objeto con información
  de cada método (firma + hash SHA-256). Usa el CLI java-method-parser.jar.
  
.PARAMETER Root
  Directorio raíz a escanear (relativo o absoluto)
  
.PARAMETER ParserJar
  Ruta al JAR del parser (por defecto: tools/java-parser/target/java-method-parser.jar)
  
.PARAMETER OutputFormat
  Formato de salida: PSObject (default) o JSON
  
.OUTPUTS
  Array de objetos con: SourcePath, MethodSignature, ContentHash
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Root,
    
    [Parameter(Mandatory=$false)]
    [string]$ParserJar = "tools/java-parser/target/java-method-parser.jar",
    
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

function To-PosixPath {
    param([string]$path)
    return ($path -replace "\\", "/")
}

function Get-RelativePathSafe {
    param(
        [string]$from,
        [string]$to
    )
    
    try {
        $fromFull = [System.IO.Path]::GetFullPath($from)
        $toFull = [System.IO.Path]::GetFullPath($to)
        
        $fromUri = New-Object System.Uri($fromFull.TrimEnd('\', '/') + "\")
        $toUri = New-Object System.Uri($toFull)
        $relativeUri = $fromUri.MakeRelativeUri($toUri)
        
        return [System.Uri]::UnescapeDataString($relativeUri.ToString())
    }
    catch {
        return $to
    }
}

function Invoke-JavaParser {
    param(
        [string]$FilePath,
        [string]$JarPath
    )
    
    try {
        # Capturar stdout y stderr por separado
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "java"
        $psi.Arguments = "-jar `"$JarPath`" `"$FilePath`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        [void]$process.Start()
        
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        
        $process.WaitForExit()
        
        if ($process.ExitCode -ne 0) {
            Write-Log "Error parseando: $(Split-Path $FilePath -Leaf) - $stderr" "WARN"
            return @()
        }
        
        if ([string]::IsNullOrWhiteSpace($stdout)) {
            return @()
        }
        
        # Parsear JSON con encoding correcto
        return $stdout | ConvertFrom-Json
    }
    catch {
        Write-Log "Excepcion procesando archivo: $_" "ERROR"
        return @()
    }
}

# -------------------------------------------------
# Flujo Principal
# -------------------------------------------------

try {
    Write-Log "=== GET-METHOD-HASHES (AST-based) ===" "INFO"
    
    # Obtener directorio actual
    $cwd = (Get-Location).ProviderPath
    
    # Validar JAR del parser
    $jarFullPath = if ([System.IO.Path]::IsPathRooted($ParserJar)) { 
        $ParserJar 
    } else { 
        Join-Path $cwd $ParserJar 
    }
    
    if (-not (Test-Path -LiteralPath $jarFullPath)) {
        throw @"
ERROR: JAR del parser no encontrado: $jarFullPath

Construya el parser ejecutando:
  cd tools/java-parser
  mvn clean package
"@
    }
    
    Write-Log "Parser CLI: $jarFullPath" "INFO"
    
    # Validar directorio raíz
    if (-not (Test-Path -LiteralPath $Root)) {
        throw "ERROR: Directorio no encontrado: $Root"
    }
    
    $rootFull = (Resolve-Path -LiteralPath $Root).ProviderPath
    Write-Log "Escaneando: $rootFull" "INFO"
    
    # Buscar archivos Java
    $javaFiles = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Filter "*.java" -ErrorAction Stop
    Write-Log "Archivos Java encontrados: $($javaFiles.Count)" "INFO"
    
    if ($javaFiles.Count -eq 0) {
        throw "No se encontraron archivos .java en: $Root"
    }
    
    # Procesar cada archivo
    $allMethods = @()
    $filesProcessed = 0
    $filesWithErrors = 0
    
    foreach ($file in $javaFiles) {
        $filesProcessed++
        $relPath = To-PosixPath (Get-RelativePathSafe -from $cwd -to $file.FullName)
        
        Write-Progress -Activity "Procesando archivos Java" `
                       -Status "[$filesProcessed/$($javaFiles.Count)] $relPath" `
                       -PercentComplete (($filesProcessed / $javaFiles.Count) * 100)
        
        $methods = Invoke-JavaParser -FilePath $file.FullName -JarPath $jarFullPath
        
        if ($methods.Count -eq 0) {
            $filesWithErrors++
            continue
        }
        
        foreach ($method in $methods) {
            $allMethods += [PSCustomObject]@{
                SourcePath      = $relPath
                MethodSignature = $method.methodSignature
                ContentHash     = $method.contentHash
                ClassName       = $method.className
            }
        }
    }
    
    Write-Progress -Activity "Procesando archivos Java" -Completed
    
    # Resumen
    Write-Log "Archivos procesados: $filesProcessed" "SUCCESS"
    Write-Log "Archivos con errores: $filesWithErrors" $(if ($filesWithErrors -gt 0) { "WARN" } else { "INFO" })
    Write-Log "Métodos extraídos: $($allMethods.Count)" "SUCCESS"
    
    # Output según formato solicitado
    if ($OutputFormat -eq "JSON") {
        return ($allMethods | ConvertTo-Json -Depth 10)
    }
    else {
        return $allMethods
    }
}
catch {
    Write-Log "ERROR CRÍTICO: $_" "ERROR"
    Write-Error $_
    exit 1
}

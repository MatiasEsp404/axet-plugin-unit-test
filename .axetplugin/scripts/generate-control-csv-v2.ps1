<#
.SYNOPSIS
  Genera/actualiza control.csv usando el CLI Java AST-based (v2 mejorada)
  
.DESCRIPTION
  Versión mejorada que usa JavaParser (AST) en lugar de Regex para parsear archivos Java.
  Requiere el CLI java-method-parser.jar construido previamente.
  
.PARAMETER Root
  Ruta del directorio raíz a escanear (relativa o absoluta)
  
.PARAMETER CsvPath
  Ruta donde se guardará el archivo control.csv
  
.PARAMETER ParserJar
  Ruta al JAR del parser (por defecto: tools/java-parser/target/java-method-parser.jar)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Root = "sp-business\src\main\java",
    
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

function Escape-CsvField {
    param([string]$field)
    
    if ($field -match '[;"\r\n]') {
        return '"' + ($field -replace '"', '""') + '"'
    }
    return $field
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
        Write-ColoredMessage "Error calculando ruta relativa: $_" "Warning"
        return $to
    }
}

# -------------------------------------------------
# Función para extraer métodos usando CLI Java
# -------------------------------------------------

function Get-MethodHashesWithCLI {
    param(
        [string]$filePath,
        [string]$jarPath
    )
    
    $methods = @()
    
    try {
        # Ejecutar CLI Java y capturar JSON
        $jsonOutput = & java -jar $jarPath $filePath 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColoredMessage "  [WARN] Error ejecutando CLI para: $(Split-Path $filePath -Leaf)" "Warning"
            return $methods
        }
        
        # Parsear JSON
        $parsedMethods = $jsonOutput | ConvertFrom-Json
        
        foreach ($method in $parsedMethods) {
            $methods += [PSCustomObject]@{
                Signature = $method.methodSignature
                Hash      = $method.contentHash
            }
        }
    }
    catch {
        Write-ColoredMessage "  [ERROR] Procesando métodos: $_" "Error"
    }
    
    return $methods
}

# -------------------------------------------------
# Función para leer CSV existente
# -------------------------------------------------

function Read-ExistingControl {
    param([string]$csvFile)
    
    $dict = @{}
    
    if (-not (Test-Path -LiteralPath $csvFile)) {
        return $dict
    }
    
    try {
        $rows = Import-Csv -LiteralPath $csvFile -Delimiter ';' -Encoding UTF8
        
        foreach ($row in $rows) {
            $key = "$($row.sourcePath)|$($row.method)"
            $dict[$key] = @{
                status = $row.status
                hash   = $row.contentHash
            }
        }
        
        Write-ColoredMessage "CSV existente cargado: $($dict.Count) registros" "Gray"
    }
    catch {
        Write-ColoredMessage "Error leyendo CSV existente: $_" "Warning"
    }
    
    return $dict
}

# -------------------------------------------------
# Flujo Principal
# -------------------------------------------------

try {
    Write-ColoredMessage "`n=== GENERADOR DE CONTROL CSV (AST-based v2) ===" "Info"
    
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
ERROR: No se encontró el JAR del parser: $jarFullPath

Para construir el parser, ejecute:
  cd tools/java-parser
  mvn clean package

"@
    }
    
    Write-ColoredMessage "Parser CLI: $jarFullPath" "Gray"
    Write-ColoredMessage "Escaneando: $Root`n" "Info"
    
    # Validar que existe el directorio raíz
    if (-not (Test-Path -LiteralPath $Root)) {
        throw "ERROR: Ruta no encontrada: $Root"
    }
    
    $rootFull = (Resolve-Path -LiteralPath $Root).ProviderPath
    Write-ColoredMessage "Ruta completa: $rootFull" "Gray"
    
    # Buscar todos los archivos .java
    $javaFiles = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Filter "*.java" -ErrorAction Stop
    Write-ColoredMessage "Archivos Java encontrados: $($javaFiles.Count)`n" "Info"
    
    if ($javaFiles.Count -eq 0) {
        throw "No se encontraron archivos .java en: $Root"
    }
    
    # Leer CSV existente
    $existingData = Read-ExistingControl -csvFile $CsvPath
    
    # Lista para almacenar nuevos registros
    $newList = @()
    $filesProcessed = 0
    $methodsFound = 0
    $methodsNew = 0
    $methodsModified = 0
    $methodsPreexisting = 0
    $filesWithErrors = 0
    
    # Procesar cada archivo Java usando el CLI
    foreach ($file in $javaFiles) {
        $filesProcessed++
        $relPath = To-PosixPath (Get-RelativePathSafe -from $cwd -to $file.FullName)
        
        Write-ColoredMessage "[$filesProcessed/$($javaFiles.Count)] Procesando: $(Split-Path $relPath -Leaf)" "Gray"
        
        try {
            $methods = Get-MethodHashesWithCLI -filePath $file.FullName -jarPath $jarFullPath
            
            if ($methods.Count -eq 0) {
                $filesWithErrors++
                continue
            }
            
            foreach ($method in $methods) {
                $methodsFound++
                $key = "$relPath|$($method.Signature)"
                $status = "PENDING"
                
                if ($existingData.ContainsKey($key)) {
                    $old = $existingData[$key]
                    
                    if ($old.hash -eq $method.Hash) {
                        # Hash igual: mantener estado
                        $status = $old.status
                        if ($status -eq "DONE") {
                            $status = "PREEXISTING"
                            $methodsPreexisting++
                        }
                    }
                    else {
                        # Hash diferente: marcar como modificado
                        $status = "PENDING"
                        $methodsModified++
                        Write-ColoredMessage "  [Modificado] $($method.Signature)" "Warning"
                    }
                }
                else {
                    # Método nuevo
                    $methodsNew++
                }
                
                $newList += [PSCustomObject]@{
                    sourcePath  = $relPath
                    method      = $method.Signature
                    contentHash = $method.Hash
                    status      = $status
                }
            }
        }
        catch {
            Write-ColoredMessage "  ERROR procesando archivo: $_" "Error"
            $filesWithErrors++
        }
    }
    
    # Crear directorio para CSV si no existe
    $fullCsvPath = if ([System.IO.Path]::IsPathRooted($CsvPath)) { 
        $CsvPath 
    } else { 
        Join-Path $cwd $CsvPath 
    }
    
    $csvDir = Split-Path -Parent $fullCsvPath
    if ($csvDir -and -not (Test-Path $csvDir)) {
        New-Item -ItemType Directory -Path $csvDir -Force | Out-Null
        Write-ColoredMessage "`nDirectorio creado: $csvDir" "Success"
    }
    
    # Generar líneas CSV
    $lines = @("sourcePath;method;contentHash;status")
    
    foreach ($item in ($newList | Sort-Object sourcePath, method)) {
        $line = "{0};{1};{2};{3}" -f `
            (Escape-CsvField $item.sourcePath),
            (Escape-CsvField $item.method),
            (Escape-CsvField $item.contentHash),
            (Escape-CsvField $item.status)
        $lines += $line
    }
    
    # Escribir archivo CSV (UTF-8 sin BOM)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($fullCsvPath, $lines, $utf8NoBom)
    
    # Resumen
    Write-ColoredMessage "`n=== RESUMEN ===" "Info"
    Write-ColoredMessage "Archivos procesados: $filesProcessed" "Success"
    Write-ColoredMessage "Archivos con errores: $filesWithErrors" $(if ($filesWithErrors -gt 0) { "Warning" } else { "Gray" })
    Write-ColoredMessage "Métodos encontrados: $methodsFound" "Success"
    Write-ColoredMessage "Métodos nuevos: $methodsNew" "Success"
    Write-ColoredMessage "Métodos modificados: $methodsModified" "Warning"
    Write-ColoredMessage "Métodos preexistentes: $methodsPreexisting" "Gray"
    Write-ColoredMessage "`nCSV generado: $fullCsvPath" "Success"
    Write-ColoredMessage "Total registros: $($newList.Count)" "Success"
    Write-ColoredMessage "`nNOTA: Esta versión usa JavaParser (AST) - sin problemas de Regex" "Info"
}
catch {
    Write-ColoredMessage "`nERROR CRÍTICO: $_" "Error"
    Write-ColoredMessage $_.ScriptStackTrace "Error"
    exit 1
}

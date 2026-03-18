<#
.SYNOPSIS
  Genera/actualiza control.csv con granularidad de MÉTODO y soporte para sobrecarga.
  
.DESCRIPTION
  Escanea archivos Java en un directorio, extrae métodos con sus firmas y genera/actualiza
  un archivo CSV de control con hash MD5 del cuerpo de cada método.
  
.PARAMETER Root
  Ruta del directorio raíz a escanear (relativa o absoluta)
  
.PARAMETER CsvPath
  Ruta donde se guardará el archivo control.csv
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Root = "sp-business\src\main\java",
    
    [Parameter(Mandatory=$false)]
    [string]$CsvPath = ".axetplugin/control.csv"
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
    
    if ($field -match '[,"\r\n]') {
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
        # Normalizar rutas
        $fromFull = [System.IO.Path]::GetFullPath($from)
        $toFull = [System.IO.Path]::GetFullPath($to)
        
        # Usar Uri para calcular ruta relativa
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
# Función para extraer métodos y calcular hashes
# -------------------------------------------------

function Get-MethodHashes {
    param([string]$filePath)
    
    $methods = @()
    
    try {
        $content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
        
        # Regex mejorado para capturar métodos (excluye constructores y clases internas)
        # Captura: modificadores, tipo retorno, nombre método, parámetros
        $methodPattern = '(?m)^\s*(?:public|protected|private|static|\s)+[\w\<\>\[\],\s]+\s+(\w+)\s*\(([^)]*)\)\s*(?:throws\s+[\w\s,]+)?\s*\{'
        
        $regex = [regex]::new($methodPattern)
        $matches = $regex.Matches($content)
        
        foreach ($match in $matches) {
            $methodName = $match.Groups[1].Value
            $parametersRaw = $match.Groups[2].Value.Trim()
            
            # Normalizar parámetros: eliminar nombres de variables, dejar solo tipos
            $parameters = $parametersRaw -replace '\s+', ' ' -replace '\s*,\s*', ','
            
            # Si los parámetros tienen nombres de variables, intentar extraer solo tipos
            if ($parameters -match '\w+\s+\w+') {
                # Patrón para extraer tipos: TipoGenerico<T> nombreVar, Tipo nombreVar
                $paramTypes = @()
                $paramParts = $parameters -split ','
                foreach ($part in $paramParts) {
                    $part = $part.Trim()
                    if ($part) {
                        # Extraer tipo (todo menos la última palabra que es el nombre de variable)
                        if ($part -match '^(.+?)\s+\w+$') {
                            $paramTypes += $matches.Groups[1].Value.Trim()
                        }
                        else {
                            $paramTypes += $part
                        }
                    }
                }
                $parameters = $paramTypes -join ','
            }
            
            # Firma única del método
            $signature = "$methodName($parameters)"
            
            # Extraer cuerpo del método usando conteo de llaves
            $startIndex = $match.Index
            $braceStart = $content.IndexOf('{', $startIndex)
            
            if ($braceStart -eq -1) { continue }
            
            $braceCount = 1
            $currentPos = $braceStart + 1
            
            while ($braceCount -gt 0 -and $currentPos -lt $content.Length) {
                $char = $content[$currentPos]
                if ($char -eq '{') { $braceCount++ }
                elseif ($char -eq '}') { $braceCount-- }
                $currentPos++
            }
            
            if ($braceCount -ne 0) {
                Write-ColoredMessage "  [WARN] Llaves desbalanceadas en método: $signature" "Warning"
                continue
            }
            
            $methodBody = $content.Substring($startIndex, $currentPos - $startIndex)
            
            # Calcular hash MD5
            $md5 = [System.Security.Cryptography.MD5]::Create()
            $hashBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($methodBody))
            $hashString = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
            
            $methods += [PSCustomObject]@{
                Signature = $signature
                Hash      = $hashString
            }
        }
    }
    catch {
        Write-ColoredMessage "Error extrayendo métodos: $_" "Error"
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
        $rows = Import-Csv -LiteralPath $csvFile -Encoding UTF8
        
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
    Write-ColoredMessage "`n=== GENERADOR DE CONTROL CSV ===" "Info"
    Write-ColoredMessage "Escaneando: $Root`n" "Info"
    
    # Obtener directorio actual
    $cwd = (Get-Location).ProviderPath
    
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
    
    # Procesar cada archivo Java
    foreach ($file in $javaFiles) {
        $filesProcessed++
        $relPath = To-PosixPath (Get-RelativePathSafe -from $cwd -to $file.FullName)
        
        Write-ColoredMessage "[$filesProcessed/$($javaFiles.Count)] Procesando: $(Split-Path $relPath -Leaf)" "Gray"
        
        try {
            $methods = Get-MethodHashes -filePath $file.FullName
            
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
    
    # Generar líneas CSV con escape apropiado
    $lines = @("sourcePath,method,contentHash,status")
    
    foreach ($item in ($newList | Sort-Object sourcePath, method)) {
        $line = "{0},{1},{2},{3}" -f `
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
    Write-ColoredMessage "Métodos encontrados: $methodsFound" "Success"
    Write-ColoredMessage "Métodos nuevos: $methodsNew" "Success"
    Write-ColoredMessage "Métodos modificados: $methodsModified" "Warning"
    Write-ColoredMessage "Métodos preexistentes: $methodsPreexisting" "Gray"
    Write-ColoredMessage "`nCSV generado: $fullCsvPath" "Success"
    Write-ColoredMessage "Total registros: $($newList.Count)" "Success"
}
catch {
    Write-ColoredMessage "`nERROR CRÍTICO: $_" "Error"
    Write-ColoredMessage $_.ScriptStackTrace "Error"
    exit 1
}

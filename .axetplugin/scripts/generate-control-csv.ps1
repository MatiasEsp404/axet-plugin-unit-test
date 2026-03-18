<#
.SYNOPSIS
  Genera/actualiza control.csv con granularidad de MÉTODO y soporte para sobrecarga.
#>

param(
    [string]$Root = "sp-business\src\main\java",
    [string]$CsvPath = ".axetplugin/control.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -------------------------------------------------
# Funciones de Procesamiento de Código
# -------------------------------------------------

function Get-MethodHashes([string]$filePath) {
    $content = [System.IO.File]::ReadAllText($filePath)
    $methods = @()
    
    # Regex mejorado para capturar Nombre (Grupo 1) y Parámetros (Grupo 2)
    # Soporta genéricos <T>, arrays [] y múltiples modificadores
    $methodRegex = [regex]'(?:public|protected|private|static|\s) +[\w\<\>\[\]]+\s+(\w+)\s*\(([^\)]*)\)\s*\{'
    $matches = $methodRegex.Matches($content)

    foreach ($match in $matches) {
        $methodName = $match.Groups[1].Value
        $parameters = $match.Groups[2].Value.Trim() -replace '\s+', ' ' # Limpia espacios extra
        
        # Firma única: nombre + parámetros entre paréntesis
        $fullSignature = "$methodName($parameters)"
        
        $startIndex = $match.Index
        $braceStart = $content.IndexOf('{', $startIndex)
        
        # Algoritmo de conteo de llaves para capturar el cuerpo exacto
        $braceCount = 1
        $currentPos = $braceStart + 1
        while ($braceCount -gt 0 -and $currentPos -lt $content.Length) {
            if ($content[$currentPos] -eq '{') { $braceCount++ }
            elseif ($content[$currentPos] -eq '}') { $braceCount-- }
            $currentPos++
        }
        
        $methodBody = $content.Substring($startIndex, $currentPos - $startIndex)
        
        # Hash MD5 del contenido del método
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $hashBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($methodBody))
        $hashString = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
        
        $methods += [PSCustomObject]@{
            Signature = $fullSignature
            Hash      = $hashString
        }
    }
    return $methods
}

# -------------------------------------------------
# Funciones de Utilidad (Basadas en el original)
# -------------------------------------------------

function To-PosixPath([string]$path) {
    return ($path -replace "\\", "/")
}

function Read-ExistingControl([string]$CsvFile) {
    $dict = @{}
    if (-not (Test-Path -LiteralPath $CsvFile)) { return $dict }
    
    # Import-Csv facilita la lectura del estado previo
    $rows = Import-Csv -LiteralPath $CsvFile
    foreach ($r in $rows) {
        # La llave es Ruta + Firma del Método para evitar duplicados por sobrecarga
        $key = "$($r.sourcePath)|$($r.method)"
        $dict[$key] = @{ 
            status = $r.status; 
            hash = $r.contentHash 
        }
    }
    return $dict
}

# -------------------------------------------------
# Flujo Principal
# -------------------------------------------------

Write-Host "Escaneando métodos en: $Root" -ForegroundColor Cyan

$cwd = (Get-Location).ProviderPath
# Validación de existencia del directorio
if (-not (Test-Path -LiteralPath $Root)) { throw "Ruta no encontrada: $Root" }
$rootFull = (Resolve-Path -LiteralPath $Root).ProviderPath

$javaFiles = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Filter "*.java"
$existingData = Read-ExistingControl -CsvFile $CsvPath

$newList = @()

foreach ($file in $javaFiles) {
    $relPath = To-PosixPath ([System.IO.Path]::GetRelativePath($cwd, $file.FullName))
    
    try {
        $methodsFound = Get-MethodHashes -filePath $file.FullName
        
        foreach ($m in $methodsFound) {
            $key = "$relPath|$($m.Signature)"
            $status = "PENDING"
            
            if ($existingData.ContainsKey($key)) {
                $old = $existingData[$key]
                # Si el hash es igual, mantenemos el estado o pasamos a PREEXISTING
                if ($old.hash -eq $m.Hash) {
                    $status = $old.status
                    if ($status -eq "DONE") { $status = "PREEXISTING" }
                } else {
                    # Si el hash cambió, forzamos PENDING para que la IA lo actualice
                    Write-Host "  [Modificado] $($m.Signature) en $relPath" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  [Nuevo]      $($m.Signature)" -ForegroundColor Gray
            }

            $newList += [PSCustomObject]@{
                sourcePath  = $relPath
                method      = $m.Signature
                contentHash = $m.Hash
                status      = $status
            }
        }
    } catch {
        Write-Warning "Error procesando $relPath: $($_.Exception.Message)"
    }
}

# -------------------------------------------------
# Escritura manual UTF-8 sin BOM (Requisito original)
# -------------------------------------------------

$fullCsv = if ([System.IO.Path]::IsPathRooted($CsvPath)) { $CsvPath } else { Join-Path $cwd $CsvPath }
$csvParent = Split-Path -Parent $fullCsv
if ($csvParent -and -not (Test-Path $csvParent)) { New-Item -ItemType Directory -Path $csvParent | Out-Null }

$lines = @("sourcePath,method,contentHash,status")
foreach ($item in ($newList | Sort-Object sourcePath, method)) {
    $lines += "$($item.sourcePath),$($item.method),$($item.contentHash),$($item.status)"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($fullCsv, $lines, $utf8NoBom)

Write-Host "`nActualización completada. Total métodos rastreados: $($newList.Count)" -ForegroundColor Green
# Catálogo de Comandos CLI - Agentic Workflow para Tests Unitarios

## Visión General

Este catálogo implementa el patrón **Agentic Workflow** para mantenimiento automático de tests unitarios en proyectos Java Spring Boot. La arquitectura separa:

- **Capa Determinista (Scripts Locales)**: Parseo AST, hashing, escaneo de archivos
- **Capa de Razonamiento (LLM)**: Análisis de código, generación/actualización de tests

## Componentes del Sistema

### 1. Java Parser CLI (AST-based)

**Ubicación**: `tools/java-parser/`

Utilidad Java ligera construida con **JavaParser** (Apache 2.0) que analiza código Java mediante AST.

**Construcción**:
```bash
cd tools/java-parser
mvn clean package
```

**Uso directo**:
```bash
java -jar tools/java-parser/target/java-method-parser.jar <archivo.java>
```

**Output** (JSON):
```json
[
  {
    "className": "UserService",
    "methodSignature": "createUser(UserDTO)",
    "contentHash": "a1b2c3..."
  }
]
```

**Características**:
- Soporte para sobrecarga de métodos
- Hash SHA-256 de cuerpos normalizados (sin espacios/comentarios)
- Manejo robusto de lambdas, clases anidadas, genéricos

---

### 2. Get-MethodHashes.ps1

**Propósito**: Escanear directorio Java y extraer firmas + hashes de métodos

**Uso**:
```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Get-MethodHashes.ps1 -Root <carpeta>
```

**Parámetros**:
- `-Root`: Directorio raíz a escanear (relativo o absoluto)
- `-ParserJar`: Ruta al JAR del parser (default: `tools/java-parser/target/java-method-parser.jar`)
- `-OutputFormat`: `PSObject` o `JSON` (default: `PSObject`)

**Ejemplo**:
```powershell
# Escanear proyecto
.\Get-MethodHashes.ps1 -Root "src/main/java"

# Output JSON
.\Get-MethodHashes.ps1 -Root "src" -OutputFormat JSON
```

**Output**:
```
[2026-03-27 16:01:52] [SUCCESS] Métodos extraídos: 156
```

---

### 3. Sync-TestInventory.ps1

**Propósito**: Sincronizar `control.csv` comparando hashes actuales vs registrados

**Uso**:
```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Sync-TestInventory.ps1 -Root <carpeta>
```

**Parámetros**:
- `-Root`: Directorio raíz del código fuente
- `-CsvPath`: Ubicación del control.csv (default: `.axetplugin/control.csv`)

**Ejemplo**:
```powershell
.\Sync-TestInventory.ps1 -Root "src/main/java"
```

**Lógica de Estados**:
- **PENDING**: Método nuevo sin test
- **UPDATED**: Método modificado (hash diferente), test desactualizado
- **DONE**: Test sincronizado
- **PREEXISTING**: Era DONE en ejecución anterior, sin cambios
- **EXCLUDED**: No debe testearse según lineamientos

**Output**:
```
=== RESUMEN DE SINCRONIZACIÓN ===
Métodos nuevos (PENDING): 16
Métodos modificados (UPDATED): 3
Métodos sin cambios: 142
Total registros: 161
```

---

### 4. Get-PendingContext.ps1

**Propósito**: Extraer contexto quirúrgico para métodos PENDING/UPDATED

**Uso**:
```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Get-PendingContext.ps1
```

**Parámetros**:
- `-CsvPath`: Ruta al control.csv (default: `.axetplugin/control.csv`)
- `-MaxMethods`: Límite de métodos a procesar (default: 10)
- `-OutputFormat`: `PSObject` o `JSON`

**Ejemplo**:
```powershell
# Obtener contexto de primeros 5 métodos pendientes
.\Get-PendingContext.ps1 -MaxMethods 5
```

**Output** (por cada método):
```json
{
  "SourcePath": "src/.../UserService.java",
  "MethodSignature": "createUser(UserDTO)",
  "MethodSource": "public User createUser(UserDTO dto) { ... }",
  "ExistingTest": "...(si existe)...",
  "Status": "UPDATED"
}
```

---

### 5. Update-TestStatus.ps1

**Propósito**: Post-procesamiento después de actualizar test (recalcular hash, marcar DONE)

**Uso**:
```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Update-TestStatus.ps1 -SourcePath <archivo> -Method <firma>
```

**Parámetros**:
- `-SourcePath`: Ruta del archivo .java (formato POSIX)
- `-Method`: Firma del método (ej. `createUser(UserDTO)`)
- `-CsvPath`: Ruta al control.csv (default: `.axetplugin/control.csv`)

**Ejemplo**:
```powershell
.\Update-TestStatus.ps1 -SourcePath "src/main/java/UserService.java" -Method "createUser(UserDTO)"
```

**Salida**:
```
[SUCCESS] Estado actualizado: DONE
[SUCCESS] Nuevo hash: a1b2c3d4...
```

---

## Formato del control.csv

```csv
sourcePath;method;contentHash;status
src/main/java/UserService.java;createUser(UserDTO);a1b2c3...;PENDING
src/main/java/UserService.java;deleteUser(Long);b2c3d4...;DONE
```

**Columnas**:
- `sourcePath`: Ruta POSIX relativa desde workspace
- `method`: Firma con tipos de parámetros
- `contentHash`: SHA-256 del cuerpo normalizado
- `status`: PENDING | UPDATED | DONE | PREEXISTING | EXCLUDED

---

## Workflow Completo (Ejemplo)

### Paso 1: Primera Sincronización
```powershell
# Construir parser si no existe
cd tools/java-parser
mvn clean package
cd ../..

# Sincronizar estado inicial
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Sync-TestInventory.ps1 -Root "src/main/java"
```

### Paso 2: Obtener Contexto Pendiente
```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Get-PendingContext.ps1 -MaxMethods 5 -OutputFormat JSON > pending.json
```

### Paso 3: Generar/Actualizar Tests
(El LLM analiza `pending.json` y genera/actualiza tests basándose en lineamientos)

### Paso 4: Actualizar Estado
```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Update-TestStatus.ps1 `
  -SourcePath "src/main/java/UserService.java" `
  -Method "createUser(UserDTO)"
```

### Paso 5: Re-sincronizar
```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Sync-TestInventory.ps1 -Root "src/main/java"
```

---

## Compliance y Restricciones

✅ **Open Source**: JavaParser (Apache 2.0), Gson (Apache 2.0)  
✅ **Ejecución Local**: Sin servicios externos  
✅ **Privacidad**: Datos permanecen en máquina local  
✅ **Costo Cero**: Sin licencias comerciales  

---

## Troubleshooting

### Error: "JAR del parser no encontrado"
```powershell
cd tools/java-parser
mvn clean package
```

### Error: "Parsing failed"
Verificar que el archivo Java compile correctamente:
```bash
javac <archivo.java>
```

### Control.csv con encoding incorrecto
El CSV debe ser UTF-8 sin BOM. Si hay problemas:
```powershell
# Re-sincronizar forzando recreación
Remove-Item .axetplugin/control.csv
.\Sync-TestInventory.ps1 -Root "src/main/java"
```

### Métodos no detectados
Verificar que el parser procesa correctamente:
```bash
java -jar tools/java-parser/target/java-method-parser.jar <archivo.java>
```

---

## Notas de Implementación

- **Normalización**: El hash ignora formato (espacios, saltos de línea, comentarios)
- **Sobrecarga**: Métodos con mismos nombres pero diferentes parámetros son distinguidos
- **Granularidad**: CSV opera a nivel de método individual
- **Idempotencia**: Re-ejecutar `Sync-TestInventory.ps1` es seguro

---

## Referencias

- [AGENT_WORKFLOW.md](../AGENT_WORKFLOW.md) - Arquitectura conceptual
- [tools/java-parser/README.md](../tools/java-parser/README.md) - Detalles del parser
- JavaParser: https://javaparser.org/

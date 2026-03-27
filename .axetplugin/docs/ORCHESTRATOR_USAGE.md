# Guía de Uso del Orquestador Maestro (Run-Audit.ps1)

## Descripción General

El **Orquestador Maestro** (`Run-Audit.ps1`) automatiza el flujo completo del Agentic Workflow para generación y mantenimiento de tests unitarios en proyectos Java Spring Boot.

## Características Principales

✅ **Sincronización automática** del inventario de métodos usando AST  
✅ **Detección de cambios** mediante hashing SHA-256  
✅ **Validación de compilación** antes de marcar tests como completados  
✅ **Human-in-the-loop**: Respeta correcciones manuales del desarrollador  
✅ **Reportes detallados** con estadísticas de progreso  
✅ **100% local**: Cumple compliance corporativo (NTT DATA)

---

## Estados del Control CSV

El archivo `control.csv` mantiene el estado de cada método:

| Estado | Descripción |
|--------|-------------|
| **PENDING** | Método nuevo o modificado que requiere test |
| **DONE** | Test generado/actualizado exitosamente en esta ejecución |
| **PREEXISTING** | Test existente y código sin cambios desde última ejecución |
| **EXCLUDED** | Método que no debe testearse (getters, constructores simples, etc.) |
| **ERROR_COMPILATION** | Test generado pero no compila correctamente |

---

## Uso Básico

### Comando Simple

```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Run-Audit.ps1
```

Este comando ejecutará el flujo completo en modo interactivo.

---

## Parámetros Disponibles

### `-SourceRoot` (Opcional)
Ruta raíz donde están los archivos `.java` a analizar.

**Default**: `tools/java-parser/test-samples`

**Ejemplo**:
```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Run-Audit.ps1 -SourceRoot "src/main/java"
```

### `-CsvPath` (Opcional)
Ruta del archivo de control CSV.

**Default**: `.axetplugin/control.csv`

### `-ParserJar` (Opcional)
Ruta al JAR del parser AST de Java.

**Default**: `tools/java-parser/target/java-method-parser.jar`

### `-SkipCompilation` (Opcional)
Omite la validación de compilación (útil para debugging).

**Default**: `$false`

**Ejemplo**:
```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Run-Audit.ps1 -SkipCompilation $true
```

### `-InteractiveMode` (Opcional)
Modo interactivo que solicita confirmación después de mostrar cada método.

**Default**: `$true`

**Ejemplo** (modo no interactivo para CI/CD):
```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Run-Audit.ps1 -InteractiveMode $false
```

---

## Flujo del Orquestador

### FASE 1: Sincronización de Inventario

1. Ejecuta `Sync-TestInventory.ps1`
2. Escanea todos los archivos `.java` usando el parser AST
3. Calcula hash SHA-256 de cada método
4. Actualiza `control.csv` con estados:
   - **PENDING**: Método nuevo o hash modificado
   - **PREEXISTING**: Método existía como DONE y hash no cambió
   - **EXCLUDED**: Métodos previamente marcados como excluidos

### FASE 2: Análisis de Estado

1. Lee el `control.csv` generado
2. Filtra métodos con estado `PENDING`
3. Muestra estadísticas iniciales
4. Si no hay métodos PENDING, termina exitosamente

### FASE 3: Procesamiento de Métodos PENDING

Para cada método en estado PENDING:

1. **Obtiene contexto** usando `Get-PendingContext.ps1`:
   - Código fuente del método
   - Tests existentes (si los hay)
   - Metadata útil

2. **Muestra contexto al usuario** (o LLM)

3. **Espera confirmación** (en modo interactivo):
   - Usuario genera/actualiza el test
   - Usuario confirma: `s` (sí), `n` (no), `skip`

4. **Valida compilación** usando `Update-TestStatus.ps1`:
   - Detecta build tool (Maven/Gradle)
   - Ejecuta `mvn test-compile` o `gradle testClasses`
   - Actualiza estado según resultado:
     - ✅ **DONE**: Compilación exitosa
     - ❌ **ERROR_COMPILATION**: Falló la compilación

5. **Actualiza control.csv** inmediatamente

### FASE 4: Reporte Final

1. Muestra estadísticas finales
2. Detalla cambios realizados
3. Provee recomendaciones si hay errores

---

## Ejemplos de Uso

### Caso 1: Proyecto Nuevo (Primera Ejecución)

```powershell
# Ejecutar en la raíz del proyecto Java
cd C:\Projects\my-java-project

# Ejecutar orquestador apuntando al código fuente
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Run-Audit.ps1 `
  -SourceRoot "src/main/java/com/example"
```

**Output esperado**:
```
═══════════════════════════════════════════════════════════════
 FASE 1: SINCRONIZACIÓN DE INVENTARIO
═══════════════════════════════════════════════════════════════

[2026-03-27 16:00:00] [SUCCESS] Control CSV generado: 45 métodos detectados

═══════════════════════════════════════════════════════════════
 FASE 2: ANÁLISIS DE ESTADO
═══════════════════════════════════════════════════════════════

─── ESTADÍSTICAS INICIALES ───
Total métodos         : 45
PENDING               : 32
DONE                  : 0
PREEXISTING           : 0
EXCLUDED              : 13
ERROR_COMPILATION     : 0
Progreso              : 0%

[2026-03-27 16:00:01] [WARN] Encontrados 32 métodos que requieren generación/actualización de tests
```

### Caso 2: Actualización de Código Existente

Cuando modificas un método en tu código fuente:

```powershell
# Después de modificar UserService.java
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Run-Audit.ps1
```

El orquestador detectará automáticamente que el hash del método cambió y lo marcará como `PENDING`, mientras que los demás métodos permanecerán como `PREEXISTING`.

### Caso 3: Modo No Interactivo (Para Scripts o CI/CD)

```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Run-Audit.ps1 `
  -InteractiveMode $false `
  -SkipCompilation $true
```

**Nota**: En modo no interactivo, el orquestador solo muestra el contexto pero NO genera tests automáticamente. Está diseñado para que un LLM (como GPT-4) lea el contexto y genere los tests.

---

## Integración con LLM (GPT-4, Claude, etc.)

El orquestador está diseñado para trabajar en conjunto con un LLM:

1. **Orquestador muestra contexto** del método PENDING
2. **LLM analiza** el código fuente
3. **LLM genera** el test unitario siguiendo lineamientos
4. **Orquestador valida** que el test compile correctamente
5. **Orquestador actualiza** el estado a DONE o ERROR_COMPILATION

---

## Manejo de Errores de Compilación

Si un método queda en estado `ERROR_COMPILATION`:

1. Revisa el archivo de test generado
2. Corrige los errores manualmente (imports, tipos, mocks, etc.)
3. Ejecuta el orquestador nuevamente:

```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Run-Audit.ps1
```

El orquestador **detectará automáticamente** que corregiste el test (hash cambió), revalidará la compilación y actualizará el estado a DONE si ahora compila correctamente.

---

## Respeto a Correcciones Manuales (Human-in-the-Loop)

### Principio Fundamental

El orquestador **NUNCA** regenera tests de métodos en estado `DONE` o `PREEXISTING` a menos que el **código fuente del método** cambie.

### Escenario Ejemplo

1. LLM genera un test para `calculateTotal()`
2. Test pasa validación → Estado: `DONE`
3. **Desarrollador mejora manualmente el test** (agrega casos edge)
4. Desarrollador ejecuta orquestador nuevamente
5. Orquestador calcula hash del **método original** (no del test)
6. Hash no cambió → Estado pasa de `DONE` a `PREEXISTING`
7. **Test manual se respeta** ✅

### Cuándo SE Regeneran Tests

Solo si el **código fuente del método** cambia:

```java
// Antes
public int calculateTotal(List<Item> items) {
    return items.stream().mapToInt(Item::getPrice).sum();
}

// Después (modificado)
public int calculateTotal(List<Item> items, double discount) {
    int total = items.stream().mapToInt(Item::getPrice).sum();
    return (int) (total * (1 - discount));  // <- Lógica cambió
}
```

En este caso:
- Hash del método cambia
- Estado pasa de `PREEXISTING` a `PENDING`
- Orquestador solicita regenerar/actualizar el test

---

## Build Tool Detection

El orquestador detecta automáticamente el build tool del proyecto:

### Maven
Busca `pom.xml` en el directorio del proyecto.

**Comando de compilación**: `mvn test-compile -q`

### Gradle
Busca `build.gradle` o `build.gradle.kts`.

**Comando de compilación**:
- Con wrapper: `.\gradlew.bat testClasses --quiet`
- Sin wrapper: `gradle testClasses --quiet`

### Sin Build Tool Detectado

Si no se encuentra Maven ni Gradle, el orquestador:
- Muestra un WARNING
- Omite validación de compilación
- Marca el método como `DONE` (sin validar)

---

## Troubleshooting

### Error: "JAR del parser no encontrado"

**Causa**: El JAR `java-method-parser.jar` no existe o no está compilado.

**Solución**:
```powershell
cd tools/java-parser
mvn clean package
```

### Error: "Control CSV no encontrado después de sincronización"

**Causa**: El script `Sync-TestInventory.ps1` falló silenciosamente.

**Solución**:
1. Ejecuta manualmente:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Sync-TestInventory.ps1
   ```
2. Revisa errores en el output

### Warning: "No se detectó build tool"

**Causa**: El proyecto no tiene `pom.xml` ni `build.gradle`.

**Solución**: Si es un proyecto con build tool:
- Asegúrate de ejecutar el script desde la raíz del proyecto
- Verifica que `pom.xml` o `build.gradle` existan

### Método queda en ERROR_COMPILATION constantemente

**Causa**: El test generado tiene errores sintácticos o de dependencias.

**Solución**:
1. Abre el archivo de test manualmente
2. Revisa los errores de compilación
3. Corrige (imports, tipos, mocks, etc.)
4. Ejecuta `mvn test-compile` manualmente para verificar
5. Ejecuta el orquestador nuevamente

---

## Scripts Relacionados

El orquestador utiliza internamente estos scripts:

| Script | Propósito |
|--------|-----------|
| **Sync-TestInventory.ps1** | Sincroniza inventario y detecta cambios |
| **Get-PendingContext.ps1** | Extrae contexto de métodos PENDING |
| **Update-TestStatus.ps1** | Valida compilación y actualiza estado |
| **count-pending.ps1** | Muestra estadísticas del CSV |

Puedes ejecutarlos individualmente si necesitas debugging.

---

## Mejores Prácticas

### 1. Ejecuta el orquestador después de cada cambio significativo

```powershell
# Después de crear nuevos métodos o modificar existentes
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Run-Audit.ps1
```

### 2. Usa modo interactivo para control fino

En modo interactivo puedes decidir método por método si generar el test o no.

### 3. Revisa ERROR_COMPILATION inmediatamente

No acumules errores. Corrígelos tan pronto aparezcan.

### 4. Combina con control de versiones

```bash
# Antes de commit
git status
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Run-Audit.ps1

# Si todo está DONE o PREEXISTING
git add .
git commit -m "feat: Agregar tests para nuevos métodos"
```

### 5. Para CI/CD, usa modo no interactivo

```yaml
# .github/workflows/test-audit.yml
- name: Run Test Audit
  run: |
    powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/Run-Audit.ps1 `
      -InteractiveMode $false `
      -SkipCompilation $false
```

---

## Límites y Restricciones

### ❌ NO soportado

- Proyectos sin build tool (sin Maven ni Gradle)
- Lenguajes distintos a Java
- Tests no basados en JUnit 5

### ✅ Soportado

- Java 8+
- Maven 3+
- Gradle 6+
- JUnit Jupiter 5.x
- Mockito 5.x
- Spring Boot 2.x y 3.x

---

## Soporte y Contribuciones

Para reportar issues o contribuir mejoras, consulta la documentación principal del proyecto.

---

**Última actualización**: 27/03/2026  
**Versión del orquestador**: 1.0.0  
**Compatibilidad**: Windows 10+, PowerShell 5.1+

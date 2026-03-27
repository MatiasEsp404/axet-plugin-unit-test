# AUDITORÍA DE SCRIPTS - .axetplugin/scripts

**Fecha:** 27/03/2026  
**Propósito:** Documentar los dos workflows coexistentes en el proyecto

---

## 📋 RESUMEN EJECUTIVO

El proyecto implementa **DOS workflows válidos** para diferentes casos de uso:

1. **Workflow Orquestado** (Original): Human-in-the-loop con orquestador maestro
2. **Workflow Agéntico** (Nuevo): Agente LLM autónomo con supervisión mínima

**Total scripts:** 11  
**Scripts workflow orquestado:** 5  
**Scripts workflow agéntico:** 3  
**Scripts compartidos/utilidad:** 3

---

## 🔄 WORKFLOW 1: ORQUESTADO (Human-in-the-Loop)

### Descripción
Diseñado para desarrolladores que desean control manual sobre cada paso del proceso.

### Documentación
- `README.md` (sección Catálogo de Scripts)
- `.axetplugin/CATALOG_README.md`
- `.axetplugin/docs/ORCHESTRATOR_USAGE.md`

### Scripts Activos

#### 1. **Run-Audit.ps1** ⭐ Orquestador Maestro
- **Propósito**: Ejecuta el flujo completo de auditoría con pasos manuales
- **Características**:
  - Modo interactivo (confirma cada acción)
  - Validación de compilación automática
  - Detección de build tool (Maven/Gradle)
  - Reportes detallados
- **Documentación**: `.axetplugin/docs/ORCHESTRATOR_USAGE.md`
- **Comando**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .axetplugin\scripts\Run-Audit.ps1 -Root "src/main/java"
  ```

#### 2. **Sync-TestInventory.ps1**
- **Propósito**: Sincronizar inventario de métodos con código fuente
- **Usado por**: Run-Audit.ps1 (Fase 1)
- **Estados que maneja**: PENDING, UPDATED, DONE, PREEXISTING, EXCLUDED, ERROR_COMPILATION
- **Comando**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .axetplugin\scripts\Sync-TestInventory.ps1 -Root "src/main/java"
  ```

#### 3. **Get-PendingContext.ps1**
- **Propósito**: Extraer contexto quirúrgico de métodos PENDING/UPDATED
- **Usado por**: Run-Audit.ps1 (Fase 2) o manualmente por desarrollador
- **Output**: JSON con código fuente del método y test existente (si hay)
- **Comando**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .axetplugin\scripts\Get-PendingContext.ps1 -Status "PENDING,UPDATED"
  ```

#### 4. **Update-TestStatus.ps1**
- **Propósito**: Validar compilación y actualizar estado post-generación
- **Usado por**: Run-Audit.ps1 (Fase 3) o manualmente
- **Características**:
  - Detecta build tool automáticamente
  - Valida compilación antes de marcar DONE
  - Si falla → ERROR_COMPILATION
- **Comando**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .axetplugin\scripts\Update-TestStatus.ps1 `
    -SourcePath "src/main/java/UserService.java" `
    -Method "createUser(UserDTO)"
  ```

#### 5. **Get-MethodHashes.ps1**
- **Propósito**: Componente interno - Extraer hashes de métodos usando AST parser
- **Usado por**: Sync-TestInventory.ps1 (internamente)
- **No se llama directamente**: Es un wrapper del parser Java
- **Comando** (uso directo si necesario):
  ```powershell
  powershell -ExecutionPolicy Bypass -File .axetplugin\scripts\Get-MethodHashes.ps1 -Root "src/main/java"
  ```

### Estados del Workflow Orquestado

| Estado | Significado |
|--------|-------------|
| PENDING | Método nuevo sin test |
| **UPDATED** | Método modificado, test desactualizado |
| DONE | Test generado/actualizado y compila |
| PREEXISTING | Test existente sin cambios |
| **ERROR_COMPILATION** | Test no compila |
| EXCLUDED | No requiere test |

### Flujo Típico

```
1. Run-Audit.ps1
   ├─ Ejecuta Sync-TestInventory.ps1
   │  └─ Usa Get-MethodHashes.ps1 → Actualiza control.csv
   ├─ Ejecuta Get-PendingContext.ps1
   │  └─ Muestra métodos PENDING/UPDATED al usuario
   ├─ Usuario genera/actualiza test (manual o con LLM)
   └─ Ejecuta Update-TestStatus.ps1
      └─ Valida compilación → Actualiza estado a DONE o ERROR_COMPILATION
```

---

## 🤖 WORKFLOW 2: AGÉNTICO (LLM Autónomo)

### Descripción
Diseñado para agentes LLM que automatizan completamente la generación de tests con supervisión mínima.

### Documentación
- `.axetrules/tests-builder-agent.md` (instrucciones para el agente)

### Scripts Activos

#### 1. **generate-control-csv.ps1**
- **Propósito**: Generar/actualizar control.csv con granularidad de método
- **Diferencia con Sync-TestInventory.ps1**:
  - Más simple: Solo genera CSV, no orquesta
  - Pensado para ser llamado por el agente
  - Estados más simples (sin UPDATED ni ERROR_COMPILATION)
- **Comando**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .axetplugin\scripts\generate-control-csv.ps1 -Root "src/main/java"
  ```

#### 2. **apply-exclusions.ps1**
- **Propósito**: Marcar automáticamente métodos como EXCLUDED según lineamientos
- **Usado en**: PASO 1 del workflow agéntico (opcional)
- **Comando**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .axetplugin\scripts\apply-exclusions.ps1
  ```

#### 3. **count-pending.ps1**
- **Propósito**: Mostrar estadísticas del control.csv
- **Usado en**: PASO 1 y PASO 3 del workflow agéntico
- **Comando**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .axetplugin\scripts\count-pending.ps1
  ```

### Estados del Workflow Agéntico

| Estado | Significado |
|--------|-------------|
| PENDING | Método nuevo o modificado que requiere test |
| DONE | Test generado exitosamente |
| PREEXISTING | Test existente sin cambios |
| EXCLUDED | No requiere test |

**Nota**: Este workflow NO usa estados UPDATED ni ERROR_COMPILATION. El agente detecta cambios comparando hashes y marca como PENDING directamente.

### Flujo Típico

```
1. Agente LLM ejecuta generate-control-csv.ps1
   └─ Genera control.csv con métodos en estado PENDING
2. Agente LLM ejecuta apply-exclusions.ps1 (opcional)
   └─ Marca métodos excluidos automáticamente
3. Agente LLM ejecuta count-pending.ps1
   └─ Verifica cuántos métodos PENDING hay
4. Agente LLM procesa cada método PENDING:
   ├─ Lee archivo fuente
   ├─ Carga lineamientos
   ├─ Genera/actualiza test
   ├─ Verifica que el archivo existe (list_files)
   └─ Marca como DONE en CSV (replace_in_file)
5. Agente LLM ejecuta count-pending.ps1 nuevamente
   └─ Muestra resumen final
```

---

## 🔧 SCRIPTS COMPARTIDOS/UTILIDAD

### 1. **check-empty-status.ps1**
- **Propósito**: Debug - Detectar registros sin estado en CSV
- **Usado en**: Ambos workflows (debug)
- **Comando**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .axetplugin\scripts\check-empty-status.ps1
  ```

### 2. **sync-existing-tests.ps1**
- **Propósito**: Sincronizar tests pre-existentes con control.csv
- **Usado en**: Inicialización de proyecto con tests existentes
- **Comando**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .axetplugin\scripts\sync-existing-tests.ps1
  ```

### 3. **generate-control-csv-v2.ps1**
- **Estado**: ⚠️ EXPERIMENTAL
- **Propósito**: Versión alternativa usando JavaParser (más robusta que v1)
- **Diferencia**: Usa AST en lugar de Regex, maneja código complejo mejor
- **Nota**: Si funciona bien, podría reemplazar a generate-control-csv.ps1

---

## 📊 COMPARACIÓN DE WORKFLOWS

### Cuándo Usar Cada Uno

| Criterio | Workflow Orquestado | Workflow Agéntico |
|----------|---------------------|-------------------|
| **Control manual** | ✅ Alto | ⚠️ Bajo |
| **Velocidad** | 🐌 Lento (intervención humana) | 🚀 Rápido (automatizado) |
| **Validación** | ✅ Compilación automática | ⚠️ Manual (IDE) |
| **Escalabilidad** | ❌ Baja (procesa 1 a 1) | ✅ Alta (procesa en lote) |
| **Mejor para** | Proyectos nuevos, aprendizaje | Proyectos grandes, mantenimiento |
| **Complejidad** | 🟡 Media | 🟢 Baja (para el usuario) |
| **Dependencias** | Maven/Gradle, Javac | Solo parser Java |

### Diferencias Clave

#### Estados
- **Orquestado**: Usa 6 estados (incluye UPDATED, ERROR_COMPILATION)
- **Agéntico**: Usa 4 estados (más simple)

#### Validación
- **Orquestado**: Valida compilación automáticamente con Maven/Gradle
- **Agéntico**: Confía en el IDE del usuario para validar

#### Orquestación
- **Orquestado**: Run-Audit.ps1 coordina todos los pasos
- **Agéntico**: El agente LLM coordina directamente

#### Human-in-the-Loop
- **Orquestado**: Sí, requiere confirmación manual
- **Agéntico**: No, automatización completa

---

## 🎯 RECOMENDACIONES DE USO

### Para Nuevos Proyectos
**Usar Workflow Orquestado** con Run-Audit.ps1:
- Te permite aprender el proceso
- Control fino sobre cada test generado
- Validación de compilación integrada

### Para Proyectos Grandes (100+ clases)
**Usar Workflow Agéntico** con agente LLM:
- Procesamiento en lote eficiente
- Menor intervención manual
- Más rápido para mantenimiento continuo

### Para CI/CD
**Usar Workflow Orquestado en modo no interactivo**:
```powershell
powershell -ExecutionPolicy Bypass -File .axetplugin\scripts\Run-Audit.ps1 `
  -InteractiveMode $false `
  -Root "src/main/java"
```

### Para Migración de Proyecto Existente
1. Ejecutar `sync-existing-tests.ps1` primero
2. Luego elegir uno de los dos workflows según preferencia

---

## ⚠️ NOTAS IMPORTANTES

### Compatibilidad de CSV
Ambos workflows usan el mismo formato de `control.csv`:
```csv
sourcePath,method,contentHash,status
```

**Sin embargo**:
- Si usaste workflow orquestado y tienes estados UPDATED o ERROR_COMPILATION
- Y luego cambias a workflow agéntico
- El agente LLM ignorará esos estados y los tratará como PENDING

**Recomendación**: Elige un workflow y mantente en él para un proyecto específico.

### Scripts "Obsoletos" son en Realidad Específicos de Workflow

Mi análisis inicial fue incorrecto. Scripts como:
- `Get-MethodHashes.ps1`: Componente interno del workflow orquestado
- `Sync-TestInventory.ps1`: Script principal del workflow orquestado
- `Get-PendingContext.ps1`: Extrae contexto en workflow orquestado
- `Update-TestStatus.ps1`: Valida y actualiza en workflow orquestado

**NO son obsoletos**, solo pertenecen al workflow orquestado.

---

## 📝 NOTAS FINALES

Este proyecto demuestra flexibilidad arquitectónica:
- **Workflow Orquestado**: Para quienes prefieren control manual
- **Workflow Agéntico**: Para quienes confían en automatización LLM

Ambos son válidos y están activamente soportados según la documentación.

**Última actualización:** 27/03/2026  
**Análisis basado en:**
- README.md
- .axetplugin/CATALOG_README.md
- .axetplugin/docs/ORCHESTRATOR_USAGE.md
- .axetrules/tests-builder-agent.md

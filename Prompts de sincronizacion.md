# Prompts de Sincronización - Agentic Workflow

Este documento contiene los prompts recomendados para trabajar con el sistema de generación automática de tests unitarios basado en el archivo de control CSV.

> **📌 IMPORTANTE:** Este documento cubre **ambos workflows** del proyecto:
> - **Workflow Orquestado** (Human-in-the-Loop con Run-Audit.ps1)
> - **Workflow Agéntico** (LLM Autónomo)
> 
> Consulta [SCRIPTS_AUDIT.md](.axetplugin/docs/SCRIPTS_AUDIT.md) para entender las diferencias entre workflows.

---

## 🤔 ¿Qué Workflow Debo Usar?

### Usa el Workflow Orquestado Si...
- ✅ Prefieres **control manual** sobre cada paso
- ✅ Trabajas en un **proyecto nuevo o mediano** (<100 clases)
- ✅ Necesitas **validación de compilación automática** (Maven/Gradle)
- ✅ Quieres **revisar cada test** antes de confirmar
- ✅ Estás **aprendiendo** el sistema

**Prompt recomendado:**
```
Genera los tests para los métodos UPDATED en el CSV
```

### Usa el Workflow Agéntico Si...
- ✅ Necesitas **automatización completa** sin intervención manual
- ✅ Trabajas en un **proyecto grande** (100+ clases)
- ✅ Prefieres **procesamiento en lote** eficiente
- ✅ Confías en el **IDE para validar** compilación
- ✅ Quieres **mantenimiento continuo** automatizado

**Prompt recomendado:**
```
Genera tests unitarios para el proyecto en {carpeta_proyecto} siguiendo el workflow agéntico definido en .axetrules/tests-builder-agent.md
```

---

## 🎯 Prompts Principales

### A. Workflow Orquestado (Human-in-the-Loop)

#### Para Sincronizar Tests de Métodos UPDATED

```
Genera los tests para los métodos UPDATED en el CSV
```

**Workflow:** Orquestado  
**Cuándo usarlo:**
- Cuando hay métodos marcados como `UPDATED` en `.axetplugin/control.csv`
- Para sincronizar tests después de modificar el código fuente
- Como parte del workflow regular de mantenimiento

**Qué hace automáticamente:**
1. Lee `.axetplugin/control.csv`
2. Filtra métodos con `status=UPDATED`
3. Carga lineamientos generales y específicos según tipo de clase
4. Genera o actualiza los tests correspondientes
5. Marca como `DONE` en el CSV tras verificación exitosa

**Nota:** El estado `UPDATED` solo existe en el Workflow Orquestado.

---

### B. Workflow Agéntico (LLM Autónomo)

#### Para Generar Tests Automáticamente

```
Genera tests unitarios para el proyecto en {carpeta_proyecto} siguiendo el workflow agéntico definido en .axetrules/tests-builder-agent.md
```

**Workflow:** Agéntico  
**Cuándo usarlo:**
- Para automatización completa sin intervención manual
- En proyectos grandes (100+ clases)
- Para procesamiento en lote eficiente

**Qué hace automáticamente:**
1. Ejecuta `generate-control-csv.ps1` para escanear métodos
2. Ejecuta `apply-exclusions.ps1` (opcional)
3. Lee control.csv y filtra métodos `PENDING`
4. Para cada método PENDING:
   - Carga lineamientos apropiados
   - Genera/actualiza test
   - Verifica físicamente que el archivo existe
   - Marca como `DONE` en el CSV
5. Muestra resumen final con estadísticas

**Nota:** Este workflow NO usa estados `UPDATED` ni `ERROR_COMPILATION`.

---

## 📝 Prompts Alternativos

### Prompt Detallado - Workflow Orquestado

```
Necesito actualizar los tests unitarios para los métodos en estado UPDATED.
Por favor:
1. Revisa el archivo .axetplugin/control.csv
2. Identifica los métodos con status=UPDATED
3. Genera/actualiza los tests correspondientes según los lineamientos
4. Marca como DONE cuando finalices

Carpeta del proyecto: {ruta_del_proyecto}
```

**Workflow:** Orquestado  
**Cuándo usarlo:**
- Primera vez usando el sistema
- Cuando trabajas con múltiples proyectos
- Para documentar el proceso en un ticket o issue

---

### Prompt Detallado - Workflow Agéntico

```
Actúa como agente generador de tests unitarios según .axetrules/tests-builder-agent.md

Proyecto: {ruta_del_proyecto}

Ejecuta el flujo completo:
1. Inicializa control.csv
2. Aplica exclusiones automáticas
3. Genera tests para todos los métodos PENDING
4. Muestra resumen final
```

**Workflow:** Agéntico  
**Cuándo usarlo:**
- Primera vez usando el workflow agéntico
- Para automatización completa
- En proyectos grandes que requieren procesamiento masivo

---

### Prompt para Clase Específica

**Workflow Orquestado:**
```
Genera tests para los métodos UPDATED de {NombreClase} en el CSV
```

**Workflow Agéntico:**
```
Genera tests para los métodos PENDING de {NombreClase} en el CSV
```

**Ejemplo (Orquestado):**
```
Genera tests para los métodos UPDATED de UserService en el CSV
```

**Ejemplo (Agéntico):**
```
Genera tests para los métodos PENDING de UserService en el CSV
```

**Cuándo usarlo:**
- Cuando solo quieres procesar una clase específica
- Para revisiones incrementales por módulo
- En code reviews enfocados

---

## 🔍 Prompts de Consulta

### Ver Estado Actual

**Workflow Orquestado:**
```
Muestra qué métodos están en estado UPDATED
```

**Workflow Agéntico:**
```
Muestra qué métodos están en estado PENDING
```

**Qué devuelve:**
- Lista de métodos que requieren atención
- Clase a la que pertenecen
- Hashes actuales vs anteriores (si aplica)

---

### Ver Estadísticas Completas

```
Muestra las estadísticas del control.csv
```

**Qué devuelve (Workflow Orquestado):**
- Total de métodos por estado (PENDING, UPDATED, DONE, PREEXISTING, ERROR_COMPILATION, EXCLUDED)
- Progreso general del proyecto
- Métodos pendientes por clase

**Qué devuelve (Workflow Agéntico):**
- Total de métodos por estado (PENDING, DONE, PREEXISTING, EXCLUDED)
- Progreso general del proyecto
- Métodos pendientes por clase

---

## ⚡ Prompts de Operaciones Especiales

### Regeneración Completa (⚠️ Usar con Precaución)

```
Regenera todos los tests del proyecto ignorando estados previos
```

**Cuándo usarlo:**
- Después de cambios masivos en lineamientos
- Para migrar a nuevas versiones de JUnit/Mockito
- Al refactorizar la estructura de packages

**⚠️ Advertencia:** Esto procesará TODOS los métodos, incluso los marcados como DONE o PREEXISTING.

---

### Reiniciar Control CSV

```
Regenera el control.csv desde cero escaneando la carpeta {ruta_proyecto}
```

**Cuándo usarlo:**
- Después de borrar el CSV accidentalmente
- Al iniciar en un nuevo proyecto
- Para detectar métodos nuevos agregados manualmente

**Ejemplo:**
```
Regenera el control.csv desde cero escaneando la carpeta tools/java-parser/test-samples
```

---

### Aplicar Exclusiones Automáticas

```
Aplica las reglas de exclusión automática al control.csv
```

**Qué hace:**
- Marca como `EXCLUDED` los métodos que no deben testearse según lineamientos
- Preserva estados existentes (no sobreescribe DONE)
- Ejemplos: getters/setters en DTOs, constructores de excepciones, métodos `run()` de Runnable

---

## 🎓 Prompts para Escenarios Específicos

### Procesar Solo Controllers

```
Genera tests solo para los Controllers marcados como UPDATED en el CSV
```

### Procesar Solo Services

```
Genera tests solo para los Services marcados como UPDATED en el CSV
```

### Revisar Método Específico

```
Revisa por qué el método {ClassName}.{methodName} está marcado como UPDATED
```

**Ejemplo:**
```
Revisa por qué el método UserService.createUser(UserDTO) está marcado como UPDATED
```

---

## 🛠️ Prompts de Mantenimiento

### Verificar Integridad del CSV

```
Verifica que todos los tests en DONE tengan sus archivos correspondientes
```

### Limpiar Entradas Obsoletas

```
Limpia del CSV los métodos que ya no existen en el código fuente
```

### Sincronizar Hashes

```
Recalcula los hashes de todos los métodos y actualiza el CSV
```

---

## 📊 Flujo de Trabajo Recomendado

### 1️⃣ **Después de Modificar Código**

```bash
# Terminal: Ver qué cambió
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/count-pending.ps1

# Prompt para el agente:
Genera los tests para los métodos UPDATED en el CSV
```

### 2️⃣ **Al Iniciar en Nuevo Proyecto**

```
Inicializa el control.csv para el proyecto en {ruta_proyecto}
```

### 3️⃣ **Antes de Hacer Commit**

```bash
# Terminal: Verificar estado
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/count-pending.ps1

# Si hay PENDING o UPDATED, usar:
Genera los tests para los métodos UPDATED en el CSV
```

### 4️⃣ **En Code Review**

```
Muestra qué tests se generaron o actualizaron desde el último commit
```

---

## 🎯 Consejos de Uso

### ✅ Buenas Prácticas

1. **Usar el prompt corto cuando sea posible:**
   ```
   Genera los tests para los métodos UPDATED en el CSV
   ```

2. **Verificar con count-pending.ps1 antes y después:**
   ```bash
   powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/count-pending.ps1
   ```

3. **Procesar incrementalmente:** Es mejor sincronizar frecuentemente que acumular muchos métodos UPDATED.

4. **Confiar en el workflow:** El agente seguirá automáticamente los lineamientos correctos según el tipo de clase.

### ❌ Evitar

1. **No pedir regeneración completa sin necesidad:** Puede sobrescribir tests personalizados.

2. **No editar el CSV manualmente:** Usa los scripts de PowerShell o el agente.

3. **No ignorar métodos UPDATED por mucho tiempo:** El drift puede hacer más difícil la sincronización.

---

## 🔗 Referencias Rápidas

### Scripts Disponibles

| Script | Uso |
|--------|-----|
| `generate-control-csv.ps1` | Genera/actualiza el CSV desde el código fuente |
| `count-pending.ps1` | Muestra estadísticas del CSV |
| `apply-exclusions.ps1` | Marca automáticamente métodos que no deben testearse |

### Estados del CSV

#### Workflow Orquestado (6 estados)

| Estado | Significado | Acción Requerida |
|--------|-------------|------------------|
| `PENDING` | Método nuevo detectado | Generar test |
| `UPDATED` | Método modificado (hash cambió) | Actualizar test |
| `DONE` | Test generado/actualizado y compila | Ninguna |
| `PREEXISTING` | Test ya existía, código sin cambios | Ninguna |
| `ERROR_COMPILATION` | Test generado pero no compila | Corregir errores |
| `EXCLUDED` | No debe testearse según lineamientos | Ninguna |

#### Workflow Agéntico (4 estados)

| Estado | Significado | Acción Requerida |
|--------|-------------|------------------|
| `PENDING` | Método nuevo o modificado | Generar/actualizar test |
| `DONE` | Test generado exitosamente | Ninguna |
| `PREEXISTING` | Test existente sin cambios | Ninguna |
| `EXCLUDED` | No debe testearse según lineamientos | Ninguna |

> **Nota:** El workflow agéntico no usa estados `UPDATED` ni `ERROR_COMPILATION`. Los cambios se detectan vía hash y se marcan directamente como `PENDING`.

---

## 📞 Soporte y Troubleshooting

### Problema: El CSV no se actualiza

**Prompt:**
```
Verifica que el CSV se esté actualizando correctamente después de generar tests
```

### Problema: Tests no se generan

**Prompt:**
```
Explica por qué no se están generando tests para los métodos UPDATED
```

### Problema: Lineamientos no se aplican

**Prompt:**
```
Muestra qué lineamientos se están aplicando para la clase {ClassName}
```

---

## 📄 Licencia y Compliance

Este sistema está diseñado para cumplir con:
- ✅ **Ejecución 100% local** (privacidad de datos)
- ✅ **Licencias Open Source permisivas** (Apache 2.0, MIT)
- ✅ **Costo cero** (sin dependencias comerciales)
- ✅ **Compliance corporativo** (apto para entornos NTT DATA)

---

**Última actualización:** 27/03/2026  
**Versión del sistema:** 1.0  
**Autor:** Claudio Matías Correa Espínola

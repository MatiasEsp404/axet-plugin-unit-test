# Java Method Parser CLI

**Versión:** 1.0.0  
**Licencia:** Apache 2.0 (todas las dependencias)

## Descripción

Utilidad CLI ligera basada en **JavaParser** (AST) para extraer información precisa de métodos Java. Diseñada específicamente para el "Agentic Workflow" de mantenimiento de tests unitarios.

## Características

✅ **Parseo basado en AST** - Sin problemas de Regex con estructuras complejas  
✅ **Soporte para sobrecarga** - Distingue métodos por tipos de parámetros  
✅ **Hash SHA-256 normalizado** - Detecta cambios reales (ignora formato y comentarios)  
✅ **Output JSON** - Fácilmente integrable con PowerShell  
✅ **100% Open Source** - JavaParser (Apache 2.0), Gson (Apache 2.0)  
✅ **Ejecución local** - Cero dependencias externas, sin SaaS

## Tecnologías

| Dependencia | Versión | Licencia |
|------------|---------|----------|
| JavaParser | 3.25.8  | Apache 2.0 |
| Gson       | 2.10.1  | Apache 2.0 |
| Maven      | 3.x     | Apache 2.0 |
| Java       | 11+     | GPL with Classpath Exception |

## Construcción

### Requisitos Previos

- **Java JDK 11+** instalado
- **Maven 3.x** instalado
- Variables de entorno configuradas: `JAVA_HOME`, `PATH`

### Compilar JAR Ejecutable

```powershell
cd tools/java-parser
mvn clean package
```

Esto genera: `target/java-method-parser.jar` (fat JAR con todas las dependencias)

## Uso

### Sintaxis

```bash
java -jar java-method-parser.jar <archivo.java>
```

### Ejemplo

```powershell
java -jar tools/java-parser/target/java-method-parser.jar src/main/java/com/example/UserService.java
```

### Output JSON

```json
[
  {
    "className": "UserService",
    "methodSignature": "findById(Long)",
    "contentHash": "a3f5e7d9c1b2a4f6e8d0c2b4a6f8e0d2c4b6a8f0e2d4c6b8a0f2e4d6c8b0a2f4"
  },
  {
    "className": "UserService",
    "methodSignature": "save(User)",
    "contentHash": "b4f6e8d0c2b4a6f8e0d2c4b6a8f0e2d4c6b8a0f2e4d6c8b0a2f4e6d8c0b2a4f6"
  }
]
```

### Campos del Output

- **className**: Nombre de la clase principal
- **methodSignature**: Firma del método con tipos de parámetros (ej: `metodo(String,int,List<T>)`)
- **contentHash**: Hash SHA-256 del código normalizado (sin comentarios ni formato)

## Integración con PowerShell

### Script v2 (AST-based)

El script `.axetplugin/scripts/generate-control-csv-v2.ps1` integra este CLI:

```powershell
# Generar control.csv usando AST
powershell -ExecutionPolicy Bypass -File .axetplugin/scripts/generate-control-csv-v2.ps1 -Root "src/main/java"
```

### Ejemplo de Integración

```powershell
# Parsear archivo y procesar resultado
$jsonOutput = java -jar tools/java-parser/target/java-method-parser.jar MyClass.java
$methods = $jsonOutput | ConvertFrom-Json

foreach ($method in $methods) {
    Write-Host "Método: $($method.methodSignature)"
    Write-Host "Hash: $($method.contentHash)"
}
```

## Casos de Uso Soportados

### ✅ Sobrecarga de Métodos

```java
public void process(String data) { }
public void process(String data, boolean validate) { }
public void process(List<String> items) { }
```

**Output:**
- `process(String)`
- `process(String,boolean)`
- `process(List<String>)`

### ✅ Métodos con Genéricos

```java
public <T> List<T> filter(List<T> items, Predicate<T> condition) { }
```

**Output:**
- `filter(List<T>,Predicate<T>)`

### ✅ Lambdas y Clases Anónimas

```java
public void complexMethod() {
    Runnable task = () -> { /* lambda */ };
    Thread t = new Thread(new Runnable() {
        public void run() { /* anónima */ }
    });
}
```

**Output:**
- `complexMethod()` - Método principal
- `run()` - Método de clase anónima

### ✅ Normalización de Hash

El hash ignora:
- Comentarios (`//`, `/* */`, `/** */`)
- Espacios en blanco excesivos
- Formato/indentación

**Cambios detectados:**
- Lógica del método
- Nombre de variables
- Condiciones, loops
- Llamadas a métodos

**Cambios ignorados:**
- Reformateo de código
- Agregar/eliminar comentarios
- Cambios de indentación

## Arquitectura Técnica

### Flujo de Procesamiento

```
Archivo.java
    ↓
[JavaParser] → AST (CompilationUnit)
    ↓
[Extractor] → Lista de MethodDeclaration
    ↓
[Normalizer] → Eliminar comentarios y normalizar espacios
    ↓
[Hasher] → SHA-256 del código normalizado
    ↓
[Formatter] → JSON Output
```

### Clases Principales

1. **JavaMethodParserCLI.java**
   - Punto de entrada principal
   - Manejo de argumentos CLI
   - Coordinación del flujo

2. **MethodInfo.java**
   - POJO para método parseado
   - Serialización JSON con Gson

### Ventajas vs Regex

| Aspecto | Regex (v1) | AST (v2) |
|---------|-----------|---------|
| **Precisión** | ⚠️ Falla con estructuras anidadas | ✅ 100% preciso |
| **Lambdas** | ❌ No soporta | ✅ Soporta completamente |
| **Clases anónimas** | ❌ Falla | ✅ Detecta métodos internos |
| **Genéricos** | ⚠️ Limitado | ✅ Soporte completo |
| **Mantenibilidad** | ⚠️ Regex complejo | ✅ API estándar |
| **Performance** | 🚀 Muy rápido | ⚡ Rápido suficiente |

## Troubleshooting

### Error: "Archivo no encontrado"

```
ERROR: Archivo no encontrado: src/main/java/MyClass.java
```

**Solución:** Verificar que la ruta es correcta y el archivo existe.

### Error: "No se pudo parsear"

```
Errores de parseo:
  - Expected ';', got 'public'
```

**Causa:** Archivo Java con errores de sintaxis  
**Solución:** Corregir errores de compilación en el archivo fuente

### JAR no encontrado en PowerShell

```
ERROR: No se encontró el JAR del parser
```

**Solución:**
```powershell
cd tools/java-parser
mvn clean package
```

## Compliance y Seguridad

### ✅ Requisitos NTT DATA

- **Licencias:** 100% Open Source permisivo (Apache 2.0)
- **Ejecución:** 100% local, sin llamadas a APIs externas
- **Privacidad:** Código fuente nunca sale del entorno local
- **Costo:** $0 en licencias

### ✅ Dependencias Auditadas

```xml
<!-- pom.xml -->
<dependencies>
    <!-- JavaParser - Apache License 2.0 -->
    <dependency>
        <groupId>com.github.javaparser</groupId>
        <artifactId>javaparser-core</artifactId>
        <version>3.25.8</version>
    </dependency>
    
    <!-- Gson - Apache License 2.0 -->
    <dependency>
        <groupId>com.google.code.gson</groupId>
        <artifactId>gson</artifactId>
        <version>2.10.1</version>
    </dependency>
</dependencies>
```

## Testing Manual

### Archivo de Prueba

Se incluye `test-samples/SampleService.java` con casos de uso complejos:

```powershell
# Probar el CLI
java -jar target/java-method-parser.jar test-samples/SampleService.java
```

**Resultado esperado:**
- 5 métodos principales detectados
- 1 método de clase anónima
- Hashes únicos por método

## Roadmap (Futuras Mejoras)

- [ ] **Modo batch:** Procesar múltiples archivos en una sola invocación
- [ ] **Filtros:** Excluir getters/setters simples
- [ ] **Metadata adicional:** Anotaciones, modificadores, línea de inicio
- [ ] **Performance:** Caché de AST para re-escaneos
- [ ] **Output CSV:** Alternativa al JSON

## Contribución

Este es un proyecto de investigación personal para uso interno en NTT DATA.

**Contacto:** [Tu email o equipo]

## Licencia

Apache License 2.0 - Ver `LICENSE` en la raíz del proyecto.

---

**Documentación del Proyecto Principal:** Ver `/AGENT_WORKFLOW.md`  
**Scripts PowerShell:** Ver `/.axetplugin/scripts/`

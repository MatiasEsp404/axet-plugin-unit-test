# Axet Plugin - Unit Test Generator

Este proyecto proporciona un conjunto de scripts, reglas (rules) y habilidades (skills) diseñados para guiar un Agente de Inteligencia Artificial ("Axet") en la automatización de la escritura y mantenimiento de **pruebas unitarias para proyectos Java Spring Boot**.

El objetivo primario de esta herramienta es optimizar los tokens y tiempo de inferencia del agente AI, dirigiéndolo a probar exclusivamente código que aporta verdadero valor al negocio y manteniendo un seguimiento granular (método por método) de qué partes del código ya han sido testeadas.

---

## Arquitectura y Funcionamiento

La solución se divide en tres componentes principales:

### 1. Script de Seguimiento (`generate-control-csv.ps1`)
Un script en **PowerShell** responsable de escanear el código fuente Java del proyecto y registrar su estado en un archivo `control.csv`.
- **Granularidad de Método:** Escanea las clases Java, utilizando Expresiones Regulares para aislar y procesar la firma de cada método (teniendo en cuenta la sobrecarga).
- **Hashing MD5 (Función Inteligente):** Genera un hash único basado en el *cuerpo* del método. Si se cambia la lógica de un método específico, solo ese método pasará a estado `PENDING`, mientras que el resto mantendrá su estado actual (`DONE` o `PREEXISTING`), ahorrando valiosos recursos de IA en reprocesar clases enteras.

### 2. Reglas Base del Agente (`tests-builder-agent.md`)
Las instrucciones "núcleo" (System Prompt o rol base) del agente Axet. Le indican cómo interactuar con el archivo de control generado por el script de PowerShell:
- Itera sobre el `control.csv` buscando los métodos en estado `PENDING`.
- Genera (o actualiza) los archivos de pruebas (`*Test.java`) según las tecnologías limitadas: **JUnit 4.8.1** y **Mockito 2.28.2**.
- Se encarga de cambiar el estado a `DONE` cuando ha validado que el código de la prueba se ha guardado físicamente en disco.

### 3. Lineamientos por Capa (`.axetplugin/skills/`)
Instrucciones detalladas de comportamiento basadas en las mejores prácticas de testing para Spring Boot. El objetivo es eliminar "ruido visual" y evitar testear los frameworks:

**Alta Prioridad (CÓDIGO QUE SÍ SE TESTEA):**
*   **Services (`lineamientos-services`):** El corazón de la lógica de negocio. Se requiere la creación de *mocks* para todas las dependencias y validar múltiples caminos de ejecución, ignorando los simples delegadores.
*   **Validators (`lineamientos-validators`):** Validadores personalizados (ej. `ConstraintValidator`). Foco en probar el método `isValid`.
*   **Mappers (`lineamientos-mappers`):** Mappers de `MapStruct` que contengan implementaciones manuales, delegaciones o lógicas `@AfterMapping/BeforeMapping`.

**Desestimados intencionalmente (NUNCA SE TESTEAN UNITARIAMENTE):**
*   **Controllers:** Deben probarse con `MockMvc` a nivel de integración.
*   **Repositories:** Son generados por JPA. Probarlos es probar Spring.
*   **DTOs / Entities:** Son simples POJOs sin lógica evaluable. Las validaciones allí aplicadas se verifican en otra capa superior.
*   **Exception Handlers & Interceptors/Filters:** Dependen del contexto Web para funcionar fielmente.
*   **FeignClients & Configurations:** Dependen fuertemente del contexto de Spring y Autoconfiguración.

*(Cualquier clase que entre en el listado desestimado será omitida y marcada automáticamente como `EXCLUDED` por el propio Agente).*

---

## Cómo Iniciar

1. Asegúrate de tener **PowerShell** disponible.
2. Inicia el agente "Axet" suministrando la carpeta (ruta) del proyecto destino.
3. El agente ejecutará el script `.axetplugin/scripts/generate-control-csv.ps1 -Root {carpeta_proyecto}` inicializando o actualizando el `control.csv`.
4. El agente leerá los registros `PENDING`, aplicará las SKILLS específicas según el tipo de clase y escribirá los tests solo donde amerite.

> **Nota para el Agente Axet**: En todo momento debes acatar tus instrucciones en `.axetrules/tests-builder-agent.md` y NO generar pruebas o archivos innecesarios para capas desestimadas.

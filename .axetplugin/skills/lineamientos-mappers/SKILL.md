---
name: lineamientos-mappers
description: Skill ejecutable para generar tests unitarios sobre Mappers. Guía para omitir interfaces MapStruct generadas automáticamente y cubrir mappers con lógica custom, @AfterMapping o @BeforeMapping.
---

# SKILL: Testing de Mappers (MapStruct)

## 🎯 1. OBJETIVO Y ALCANCE
- **SÍ TESTEAR:** Interfaces o clases abstractas anotadas con `@Mapper` que contengan métodos con lógica custom (ej. `@AfterMapping`, `@BeforeMapping`, expresiones Java complejas en `@Mapping(expression = "java(...)")`, o métodos `default` con lógica).
- **NO TESTEAR:** Interfaces de MapStruct puramente declarativas (solo firmas de métodos o `@Mapping` simples de campo a campo). El código generado por MapStruct ya está testeado por la librería. Si el mapper no tiene lógica custom, aborta y marca como EXCLUDED.

## 🔍 2. PRERREQUISITOS (Investigación previa)
Antes de generar el código, DEBES:
1. Leer la interfaz/clase del Mapper.
2. Buscar anotaciones `@AfterMapping`, `@BeforeMapping`, métodos `default` con cuerpo (ej. conversiones de String a Date), o `@Mapping(expression = ...)`.
3. Si la interfaz solo posee declaraciones de firma sin lógica (ej. `Destino toDto(Origen origen)` o mapeos declarativos directos con `@Mapping(target = x, source = y)`), detener el proceso INMEDIATAMENTE y marcar la clase como EXCLUDED en el CSV. Probar estos casos automáticos es pérdida de tiempo.
4. Si encuentras lógica custom real, identifica qué campos se están modificando o calculando en esa lógica.

## ⚙️ 3. ALGORITMO DE EJECUCIÓN
Sigue estos pasos en orden para generar el archivo `*Test.java`:

1.  **Configuración de la Clase:**
    - Anota la clase con `@ExtendWith(MockitoExtension.class)`.
    - Añade `@DisplayName("Tests del mapper [Nombre]")`.
2.  **Instanciación del Mapper:**
    - Instancia el mapper usando `Mappers.getMapper(NombreMapper.class)`. NO uses `@InjectMocks` ni `@Autowired` a menos que el mapper inyecte otros componentes de Spring (en cuyo caso, usa `@InjectMocks` sobre la implementación generada `NombreMapperImpl`).
3.  **Generación de Tests (Por cada lógica custom):**
    - Crea un test enfocado EXCLUSIVAMENTE en la lógica custom (ej. el método `@AfterMapping`).
    - Nomenclatura: `metodo_whenCondicion_shouldResultado`.
    - **Bloque Given:** Crea la entidad/DTO de origen con los datos necesarios para disparar la lógica custom.
    - **Bloque When:** Llama al método principal de mapeo (ej. `toDTO(entity)`).
    - **Bloque Then:** Verifica que el campo modificado por la lógica custom tenga el valor esperado (`assertEquals(esperado, resultado.getCampo())`).

## ⚠️ 4. REGLAS ESTRICTAS Y ANTI-PATRONES
- ❌ **PROHIBIDO** testear el mapeo básico de campos (ej. que `entity.nombre` se mapeó a `dto.nombre`). Solo testea la lógica custom.
- ❌ **PROHIBIDO** usar `@SpringBootTest` para testear mappers. Son clases utilitarias que deben testearse rápido.

## ✅ 5. CHECKLIST DE AUTOCORRECCIÓN
Antes de guardar el archivo, verifica mentalmente:
- [ ] ¿El mapper realmente tiene lógica custom (`@AfterMapping`, `default`, etc.)?
- [ ] ¿Instancié el mapper correctamente usando `Mappers.getMapper(...)`?
- [ ] ¿El test verifica específicamente el resultado de la lógica custom y no el mapeo estándar?

## 📄 6. EJEMPLO DE REFERENCIA

**Ejemplo de Mapper con lógica:**
```java
@Mapper(componentModel = "spring")
public interface DocumentoMapper {

    DocumentoDTO toDTO(DocumentoEntity entity);

    @AfterMapping
    default void calcularEstado(@MappingTarget DocumentoDTO dto, DocumentoEntity entity) {
        if (entity.getFechaVencimiento().isBefore(LocalDate.now())) {
            dto.setEstado("VENCIDO");
        } else {
            dto.setEstado("VIGENTE");
        }
    }
}
```

**Test Ejemplo:**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("Tests del mapper de Documento")
class DocumentoMapperTest {

    private DocumentoMapper mapper = Mappers.getMapper(DocumentoMapper.class);

    @Test
    @DisplayName("Debe establecer el estado como VENCIDO cuando la fecha de vencimiento ya pasó")
    void toDTO_whenVencido_shouldSetEstadoVencido() {
        // given
        DocumentoEntity entity = new DocumentoEntity();
        entity.setFechaVencimiento(LocalDate.now().minusDays(1));

        // when
        DocumentoDTO result = mapper.toDTO(entity);

        // then
        assertEquals("VENCIDO", result.getEstado());
    }

    @Test
    @DisplayName("Debe establecer el estado como VIGENTE cuando la fecha de vencimiento es futura")
    void toDTO_whenVigente_shouldSetEstadoVigente() {
        // given
        DocumentoEntity entity = new DocumentoEntity();
        entity.setFechaVencimiento(LocalDate.now().plusDays(1));

        // when
        DocumentoDTO result = mapper.toDTO(entity);

        // then
        assertEquals("VIGENTE", result.getEstado());
    }
}
```
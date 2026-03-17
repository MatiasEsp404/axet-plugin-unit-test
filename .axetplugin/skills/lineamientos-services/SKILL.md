---
name: lineamientos-services
description: Skill ejecutable para generar tests unitarios sobre Services y Business Logic. Guía para cubrir clases @Service y @Component con lógica de negocio, mockeando sus dependencias.
---

# SKILL: Testing de Services y Business Logic

## 🎯 1. OBJETIVO Y ALCANCE
- **SÍ TESTEAR:** Toda clase anotada con `@Service` o `@Component` que contenga lógica de negocio, validaciones, llamadas a repositorios o clientes externos.
- **ALCANCE:** Verificar que la lógica de negocio se ejecute correctamente, que las dependencias se llamen con los parámetros adecuados y que se manejen las excepciones esperadas.

## 🔍 2. PRERREQUISITOS (Investigación previa)
Antes de generar el código, DEBES:
1. Identificar todas las dependencias inyectadas en el Service (ej. `Repository`, `Mapper`, otros `Services`).
2. Identificar los métodos públicos del Service que contienen lógica real (cálculos, validaciones, orquestación de llamadas múltiples). 
3. IGNORA métodos que sean simples delegadores directos a un repositorio (ej. `public User findById(Long id) { return repo.findById(id); }`) sin lógica adicional. Los tests unitarios aquí son ruido.
4. Para cada método con lógica real, identificar los diferentes caminos de ejecución (ej. if/else, try/catch, validaciones previas) para crear un test por cada camino.

## ⚙️ 3. ALGORITMO DE EJECUCIÓN
Sigue estos pasos en orden para generar el archivo `*Test.java`:

1.  **Configuración de la Clase:**
    - Anota la clase con `@ExtendWith(MockitoExtension.class)`.
    - Añade `@DisplayName("Tests del servicio [Nombre]")`.
2.  **Inyección de Dependencias:**
    - Inyecta la clase bajo test usando `@InjectMocks`.
    - Mockea TODAS las dependencias del servicio usando `@Mock`.
3.  **Generación de Tests (Por cada camino de ejecución):**
    - Crea un método de test con nomenclatura: `nombreMetodo_whenCondicion_shouldResultado`.
    - **Bloque Given:** Prepara los datos de prueba. Configura los mocks usando `when(mock.metodo(...)).thenReturn(...)` o `willThrow(...)`.
    - **Bloque When:** Llama al método del servicio.
    - **Bloque Then:**
        - Verifica el resultado retornado (`assertNotNull`, `assertEquals`).
        - Verifica que las dependencias fueron llamadas correctamente usando `verify(mock).metodo(...)`.
        - Si el método lanza una excepción, usa `assertThatThrownBy(() -> service.metodo(...)).isInstanceOf(...)`.

## ⚠️ 4. REGLAS ESTRICTAS Y ANTI-PATRONES
- ❌ **PROHIBIDO** usar `@SpringBootTest` para testear servicios unitariamente. Usa Mockito puro.
- ❌ **PROHIBIDO** usar dependencias reales. Todo lo que no sea la clase bajo test debe ser un `@Mock`.

## ✅ 5. CHECKLIST DE AUTOCORRECCIÓN
Antes de guardar el archivo, verifica mentalmente:
- [ ] ¿Mockeé todas las dependencias inyectadas en el servicio?
- [ ] ¿Creé tests para los casos de éxito y los casos de error (excepciones)?
- [ ] ¿Usé `verify()` para asegurar que el servicio interactúa correctamente con sus dependencias?

## 📄 6. EJEMPLO DE REFERENCIA

**Ejemplo de Service:**
```java
@Service
@RequiredArgsConstructor
public class HistorialService {
    private final HistorialRepository repository;
    private final HistorialMapper mapper;

    public HistorialResponse getHistorial(String procesoId, Integer pageIndex, Integer pageSize) {
        Page<HistorialEntity> page = repository.findByProcesoId(
            procesoId, PageRequest.of(pageIndex, pageSize)
        );
        return mapper.toResponse(page);
    }
}
```

**Test Ejemplo:**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("Tests del servicio de Historial")
class HistorialServiceTest {

    @Mock
    private HistorialRepository repository;

    @Mock
    private HistorialMapper mapper;

    @InjectMocks
    private HistorialService service;

    @Test
    @DisplayName("Debe retornar la respuesta mapeada cuando se proporciona un ID de proceso válido")
    void getHistorial_whenValidProcesoId_shouldReturnMappedResponse() {
        // given
        String procesoId = "PROC-123";
        Page<HistorialEntity> page = new PageImpl<>(List.of(new HistorialEntity()));
        HistorialResponse expectedResponse = new HistorialResponse();

        when(repository.findByProcesoId(eq(procesoId), any(PageRequest.class))).thenReturn(page);
        when(mapper.toResponse(page)).thenReturn(expectedResponse);

        // when
        HistorialResponse result = service.getHistorial(procesoId, 0, 10);

        // then
        assertNotNull(result);
        assertEquals(expectedResponse, result);
        verify(repository).findByProcesoId(eq(procesoId), any(PageRequest.class));
        verify(mapper).toResponse(page);
    }
}
```
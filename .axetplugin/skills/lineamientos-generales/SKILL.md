---
name: lineamientos-generales
description: Skill Maestro. Usarlo al crear o revisar tests unitarios en general. Guía con lineamientos globales de anotaciones, buenas prácticas, reglas de SonarQube y checklist de calidad para Spring Boot 3.4+.
---

# SKILL MAESTRO: Lineamientos Generales de Testing
## Spring Boot 3.5.5 + spring-boot-starter-test

## 🎯 1. OBJETIVO Y ALCANCE GLOBAL
Este documento define las reglas universales que aplican a TODOS los tests generados. Debes leer este archivo UNA SOLA VEZ al inicio de tu ejecución y mantener estas reglas en mente para cualquier tipo de clase que proceses.

### ❌ NO TESTEAR UNITARIAMENTE (Exclusiones Globales)
- Records sin lógica
- Interfaces MapStruct
- Interfaces FeignClient
- Interfaces de Controller (OpenAPI Generator)
- `@Configuration` sin lógica (OpenApi, Jackson, Cors básicos)
- Repositories JPA simples (solo métodos heredados)

### ✅ TESTEAR UNITARIAMENTE (Inclusiones Globales)
- `@Service` y `@Component` con lógica
- Implementaciones de Controllers (`@WebMvcTest` + `@MockitoBean`)
- `@Configuration` con lógica (WebConfig, registros de interceptors)
- DTOs
- Interceptors, Filters, Handlers
- Exception Handlers (`@RestControllerAdvice`)
- Validators personalizados
- Feign ErrorDecoders con lógica
- Utilidades y Helpers

## ⚙️ 2. REGLAS DE ANOTACIONES (Spring Boot 3.4+)

| Escenario | Anotación | Clase de Test | Razón |
|-----------|-----------|---------------|-------|
| **Controller tests** | `@MockitoBean` | `@WebMvcTest` | Necesitas Spring Context para mappings/serialización |
| **Service/Component** | `@Mock` + `@InjectMocks` | `@ExtendWith(MockitoExtension.class)` | No necesitas Spring Context, tests más rápidos |
| **Repository tests** | N/A | `@DataJpaTest` | Tests de integración con BD embebida |
| **Integration tests** | `@MockitoBean` | `@SpringBootTest` | Test E2E con contexto completo |

### ⚠️ DEPRECADOS (PROHIBIDO USAR)
- ❌ `@MockBean` (usar `@MockitoBean`)
- ❌ `@SpyBean` (usar `@MockitoSpyBean`)

## ⚠️ 3. REGLAS ESTRICTAS DE SONARQUBE Y CALIDAD

### 3.1 Nomenclatura y Documentación
- **Nombre del método:** `methodName_whenCondition_shouldExpectedBehavior`
- **@DisplayName obligatorio:** Todos los tests y clases deben tener `@DisplayName` con descripción clara en español.

### 3.2 Assertions Obligatorias
- Todo test **DEBE tener al menos una assertion** (AssertJ preferido) o un `verify()` de Mockito.
- **Evitar:** Tests sin assertions (SonarQube: java:S2699).

### 3.3 Manejo de Excepciones
- Usar `assertThatThrownBy()` en lugar de `@Test(expected = ...)`.
- ❌ **PROHIBIDO** usar `throws Exception` en la firma del método de test (SonarQube: java:S5778).

### 3.4 Sin Magic Numbers ni Strings Hardcodeados
- Definir **constantes** (`private static final`) para todos los valores numéricos y strings repetidos (SonarQube: java:S109, java:S1192).

### 3.5 Complejidad Cognitiva Baja
- ❌ **PROHIBIDO** usar if/else, loops, o estructuras anidadas en tests (SonarQube: java:S3776).
- Un test = un solo camino de ejecución.

### 3.6 Setup Común
- Usar `@BeforeEach` para código de inicialización compartido.

## ✅ 4. CHECKLIST DE AUTOCORRECCIÓN GLOBAL
Antes de dar por terminado CUALQUIER archivo de test, verifica:
- [ ] ¿El nombre de la clase termina en `Test`?
- [ ] ¿Todos los métodos siguen el patrón `_when_should`?
- [ ] ¿Todos los métodos y la clase tienen `@DisplayName` en español?
- [ ] ¿Eliminé todos los `throws Exception` de las firmas de los métodos?
- [ ] ¿Reemplacé todos los `@MockBean` por `@MockitoBean`?
- [ ] ¿Extraje los strings y números repetidos a constantes `private static final`?
- [ ] ¿Cada test tiene al menos un `assert` o `verify`?
```java
// ❌ MALO
@Test
void testService() {
    service.doSomething();
    // Sin assertions - SonarQube lo marca como smell
}
```
```java
// ✅ BUENO
@Test
void doSomething_shouldProcessCorrectly() {
    // when
    Result result = service.doSomething();

    // then
    assertThat(result).isNotNull();
    verify(repository).save(any());
}
```

---

### ❌ Smell: Exception instances should not be thrown in tests
```java
// ❌ MALO
@Test
void testException() throws Exception {
    service.methodThatThrows();
}
```
```java
// ✅ BUENO
@Test
void methodThatThrows_shouldThrowCustomException() {
    assertThatThrownBy(() -> service.methodThatThrows())
        .isInstanceOf(CustomException.class)
        .hasMessage("Error esperado");
}
```

---

### ❌ Smell: Tests should not use magic numbers
```java
// ❌ MALO
@Test
void test() {
    when(repository.findById(123)).thenReturn(entity);
    assertEquals(10, result.getSize());
}
```
```java
// ✅ BUENO
class MyServiceTest {
    private static final Long ENTITY_ID = 123L;
    private static final int EXPECTED_SIZE = 10;

    @Test
    void findById_whenValidId_shouldReturnEntity() {
        when(repository.findById(ENTITY_ID)).thenReturn(Optional.of(entity));
        assertEquals(EXPECTED_SIZE, result.getSize());
    }
}
```

---

### ❌ Smell: Cognitive Complexity
```java
// ❌ MALO
@Test
void complexTest() {
    if (condition1) {
        if (condition2) {
            for (Item item : items) {
                if (item.isValid()) {
                    // Demasiada complejidad - SonarQube penaliza esto
                }
            }
        }
    }
}
```
```java
// ✅ BUENO - Dividir en múltiples tests simples
@Test
void condition1AndCondition2_whenItemValid_shouldProcess() {
    assertThat(result).isTrue();
}

@Test
void condition1False_shouldNotProcess() {
    assertThat(result).isFalse();
}

@Test
void condition2False_shouldNotProcess() {
    assertThat(result).isFalse();
}
```

---

### ❌ Smell: Tests should not have too many assertions
```java
// ❌ MALO
@Test
void testEverything() {
    assertEquals(expected1, result.getField1());
    assertEquals(expected2, result.getField2());
    assertEquals(expected3, result.getField3());
    assertEquals(expected4, result.getField4());
    assertEquals(expected5, result.getField5());
    assertEquals(expected6, result.getField6());
}
```
```java
// ✅ BUENO - Usar assertions agrupadas o dividir tests
@Test
void createEntity_shouldSetAllFieldsCorrectly() {
    Entity result = service.create(request);

    assertThat(result)
        .extracting("field1", "field2", "field3")
        .containsExactly(expected1, expected2, expected3);

    assertThat(result.getStatus()).isEqualTo(Status.ACTIVE);
}

@Test
void createEntity_shouldSetTimestampsCorrectly() {
    assertThat(result.getCreatedAt()).isNotNull();
    assertThat(result.getUpdatedAt()).isNotNull();
}
```

---

### ✅ Estructura Recomendada para Evitar Smells
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("Tests del servicio de Historial")
class HistorialServiceTest {

    // CONSTANTES - Evita magic numbers y strings
    private static final String PROCESO_ID = "PROC-123";
    private static final int DEFAULT_PAGE_INDEX = 0;
    private static final int DEFAULT_PAGE_SIZE = 10;
    private static final String ERROR_MESSAGE = "Proceso no encontrado";

    @Mock
    private HistorialRepository repository;

    @Mock
    private HistorialMapper mapper;

    @InjectMocks
    private HistorialService service;

    private HistorialEntity testEntity;
    private HistorialResponse testResponse;

    @BeforeEach
    void setUp() {
        testEntity = HistorialEntity.builder()
            .procesoId(PROCESO_ID)
            .estado("ACTIVO")
            .build();

        testResponse = HistorialResponse.builder()
            .procesoId(PROCESO_ID)
            .build();
    }

    @Test
    void getHistorial_whenValidParameters_shouldReturnResponse() {
        // given
        Page<HistorialEntity> page = new PageImpl<>(List.of(testEntity));
        when(repository.findByProcesoId(eq(PROCESO_ID), any(PageRequest.class)))
            .thenReturn(page);
        when(mapper.toResponse(page)).thenReturn(testResponse);

        // when
        HistorialResponse result = service.getHistorial(
            PROCESO_ID,
            DEFAULT_PAGE_INDEX,
            DEFAULT_PAGE_SIZE
        );

        // then
        assertThat(result)
            .isNotNull()
            .isEqualTo(testResponse);

        verify(repository).findByProcesoId(eq(PROCESO_ID), any(PageRequest.class));
        verify(mapper).toResponse(page);
    }

    @Test
    void getHistorial_whenProcesoIdNotFound_shouldThrowException() {
        // given
        when(repository.findByProcesoId(anyString(), any(PageRequest.class)))
            .thenThrow(new EntityNotFoundException(ERROR_MESSAGE));

        // when & then
        assertThatThrownBy(() ->
            service.getHistorial(PROCESO_ID, DEFAULT_PAGE_INDEX, DEFAULT_PAGE_SIZE)
        )
        .isInstanceOf(EntityNotFoundException.class)
        .hasMessage(ERROR_MESSAGE);

        verify(repository).findByProcesoId(eq(PROCESO_ID), any(PageRequest.class));
        verify(mapper, never()).toResponse(any());
    }

    @Test
    void getHistorial_shouldCreatePageRequestWithCorrectParameters() {
        // given
        ArgumentCaptor<PageRequest> pageRequestCaptor =
            ArgumentCaptor.forClass(PageRequest.class);

        when(repository.findByProcesoId(anyString(), any(PageRequest.class)))
            .thenReturn(Page.empty());
        when(mapper.toResponse(any())).thenReturn(testResponse);

        int customPageIndex = 2;
        int customPageSize = 20;

        // when
        service.getHistorial(PROCESO_ID, customPageIndex, customPageSize);

        // then
        verify(repository).findByProcesoId(eq(PROCESO_ID), pageRequestCaptor.capture());

        PageRequest capturedPageRequest = pageRequestCaptor.getValue();
        assertThat(capturedPageRequest.getPageNumber()).isEqualTo(customPageIndex);
        assertThat(capturedPageRequest.getPageSize()).isEqualTo(customPageSize);
    }
}
```

---

### Checklist al finalizar

- [ ] ✅ Todos los tests tienen nombres descriptivos `methodName_when_should`
- [ ] ✅ Todos los tests y clases tienen `@DisplayName` en español
- [ ] ✅ Todos los tests tienen al menos una assertion
- [ ] ✅ No hay números mágicos (usar constantes)
- [ ] ✅ No hay strings hardcodeados repetidos (usar constantes)
- [ ] ✅ Excepciones testeadas con `assertThatThrownBy()`
- [ ] ✅ No hay lógica compleja en tests (if, loops, etc.)
- [ ] ✅ Setup común en `@BeforeEach` para evitar duplicación
- [ ] ✅ Usar AssertJ en vez de assertEquals cuando sea posible
- [ ] ✅ Verificaciones de Mockito son específicas, no genéricas
- [ ] ✅ Tests son independientes (pueden ejecutarse en cualquier orden)

---

## Ejemplos de Assertions Recomendadas
```java
// JUnit 5 + AssertJ
import static org.assertj.core.api.Assertions.*;

@Test
void ejemplo_assertions() {
    // Assertions básicas
    assertThat(result).isNotNull();
    assertThat(result).isEqualTo(expected);
    assertThat(list).hasSize(3);
    assertThat(list).contains("item1", "item2");

    // Assertions de excepciones
    assertThatThrownBy(() -> service.method())
        .isInstanceOf(EntityNotFoundException.class)
        .hasMessage("Entidad no encontrada");

    // Assertions de Optional
    assertThat(optional).isPresent();
    assertThat(optional).contains(expectedValue);

    // Verify de Mockito
    verify(repository).save(any(Entity.class));
    verify(service, times(2)).method();
    verify(service, never()).deleteMethod();
}
```
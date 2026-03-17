---
name: lineamientos-validators
description: Skill ejecutable para generar tests unitarios sobre Validators personalizados. Guía para cubrir custom validators con lógica de validación que implementen ConstraintValidator.
---

# SKILL: Testing de Validators Personalizados

## 🎯 1. OBJETIVO Y ALCANCE
- **SÍ TESTEAR:** Clases que implementan `ConstraintValidator<Anotacion, Tipo>` y contienen lógica de validación custom en su método `isValid`.
- **ALCANCE:** Verificar que el validador retorne `true` para casos válidos, `false` para casos inválidos, y maneje correctamente los casos borde (como valores `null` o vacíos).

## 🔍 2. PRERREQUISITOS (Investigación previa)
Antes de generar el código, DEBES:
1. Identificar la clase que implementa `ConstraintValidator`.
2. Identificar el tipo de dato que valida (ej. `String`, `ObjetoDTO`).
3. Analizar la lógica dentro del método `isValid` para determinar cuáles son los casos válidos y cuáles los inválidos.
4. IGNORAR validadores que solo deleguen en otras validaciones estándar o que no tengan lógica compleja evaluada (ej. si su `isValid` es solo devolver `true` para hacer que pase o está vacío). No gastar tiempo en casos irrelevantes.
5. Identificar si el validador delega la validación de nulos a `@NotNull` (retornando `true` cuando el valor es null).

## ⚙️ 3. ALGORITMO DE EJECUCIÓN
Sigue estos pasos en orden para generar el archivo `*Test.java`:

1.  **Configuración de la Clase:**
    - Anota la clase con `@ExtendWith(MockitoExtension.class)`.
    - Añade `@DisplayName("Tests del validador [Nombre]")`.
2.  **Inyección de Dependencias:**
    - Instancia el validador manualmente en un método `@BeforeEach` o inyéctalo con `@InjectMocks` si tiene dependencias.
    - Mockea `ConstraintValidatorContext` usando `@Mock`.
3.  **Generación de Tests (Por cada caso de validación):**
    - Crea un test para el caso válido (`isValid_whenValidFormat_shouldReturnTrue`).
    - Crea tests para los casos inválidos (`isValid_whenInvalidFormat_shouldReturnFalse`).
    - Crea un test para el caso nulo (`isValid_whenNull_shouldReturnTrue` o `False` según la lógica).
    - **Bloque Given:** Prepara el valor a validar.
    - **Bloque When:** Llama a `validator.isValid(valor, context)`.
    - **Bloque Then:** Verifica el resultado booleano (`assertTrue(result)` o `assertFalse(result)`).

## ⚠️ 4. REGLAS ESTRICTAS Y ANTI-PATRONES
- ❌ **PROHIBIDO** levantar el contexto de validación de Spring (`ValidatorFactory`) para testear la lógica interna de un `ConstraintValidator`. Testéalo como un POJO simple llamando a `isValid`.
- ❌ **PROHIBIDO** olvidar testear el caso donde el valor de entrada es `null`.

## ✅ 5. CHECKLIST DE AUTOCORRECCIÓN
Antes de guardar el archivo, verifica mentalmente:
- [ ] ¿Mockeé `ConstraintValidatorContext`?
- [ ] ¿Creé tests para los casos válidos, inválidos y nulos?
- [ ] ¿Verifiqué el resultado booleano de `isValid`?

## 📄 6. EJEMPLO DE REFERENCIA

**Ejemplo de Validator:**
```java
public class CuitValidator implements ConstraintValidator<ValidCuit, String> {
    @Override
    public boolean isValid(String cuit, ConstraintValidatorContext context) {
        if (cuit == null || cuit.isEmpty()) {
            return true; // @NotNull se encarga de esto
        }
        return cuit.matches("\\d{2}-\\d{8}-\\d{1}");
    }
}
```

**Test Ejemplo:**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("Tests del validador de CUIT")
class CuitValidatorTest {

    private CuitValidator validator;

    @Mock
    private ConstraintValidatorContext context;

    @BeforeEach
    void setUp() {
        validator = new CuitValidator();
    }

    @Test
    @DisplayName("Debe retornar true cuando el formato del CUIT es válido")
    void isValid_whenValidFormat_shouldReturnTrue() {
        assertTrue(validator.isValid("20-12345678-9", context));
    }

    @Test
    @DisplayName("Debe retornar false cuando el formato del CUIT es inválido")
    void isValid_whenInvalidFormat_shouldReturnFalse() {
        assertFalse(validator.isValid("20-123456-9", context));
    }

    @Test
    @DisplayName("Debe retornar true cuando el CUIT es null (validación delegada a @NotNull)")
    void isValid_whenNull_shouldReturnTrue() {
        assertTrue(validator.isValid(null, context));
    }
}
```
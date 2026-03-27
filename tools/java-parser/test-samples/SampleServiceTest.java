package com.example.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.*;

/**
 * Tests unitarios para SampleService
 * Generados automáticamente por Agentic Workflow
 * Cumple con lineamientos de Spring Boot 3.5.5 y SonarQube
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("Tests del servicio SampleService")
class SampleServiceTest {

    // Constantes para evitar magic numbers y strings (SonarQube: java:S109, java:S1192)
    private static final String VALID_INPUT_HELLO = "hello";
    private static final String VALID_INPUT_WORLD = "world";
    private static final String EXPECTED_UPPER_HELLO = "HELLO";
    private static final String EXPECTED_UPPER_WORLD = "WORLD";
    private static final String EMPTY_STRING = "";
    private static final String FILTER_CRITERIA_AP = "ap";
    private static final String FILTER_CRITERIA_XYZ = "xyz";
    private static final String FILTER_CRITERIA_10 = "10";
    private static final String COMPLEX_METHOD_PARAM = "test";
    private static final String ERROR_MESSAGE_NULL_INPUT = "Input cannot be null";
    
    private static final String ITEM_APPLE = "apple";
    private static final String ITEM_BANANA = "banana";
    private static final String ITEM_APRICOT = "apricot";
    private static final String ITEM_CHERRY = "cherry";
    
    private static final Integer NUMBER_100 = 100;
    private static final Integer NUMBER_200 = 200;
    private static final Integer NUMBER_105 = 105;
    private static final Integer NUMBER_305 = 305;
    
    private static final int EXPECTED_FILTERED_SIZE_TWO = 2;

    private SampleService sampleService;

    @BeforeEach
    void setUp() {
        sampleService = new SampleService();
    }

    // ===== Tests para initialize() =====

    @Test
    @DisplayName("Debe ejecutarse sin errores cuando se inicializa el servicio")
    void initialize_shouldExecuteWithoutErrors() {
        // when & then
        assertThatCode(() -> sampleService.initialize())
            .doesNotThrowAnyException();
    }

    // ===== Tests para processData(String) =====

    @Test
    @DisplayName("Debe retornar texto en mayúsculas y trimmeado cuando se proporciona entrada válida")
    void processData_whenValidInput_shouldReturnUpperCaseAndTrimmed() {
        // when
        String result = sampleService.processData(VALID_INPUT_HELLO);

        // then
        assertThat(result)
            .isNotNull()
            .isEqualTo(EXPECTED_UPPER_HELLO);
    }

    @Test
    @DisplayName("Debe remover espacios en blanco al inicio y final del texto")
    void processData_whenInputWithWhitespace_shouldTrimAndReturnUpperCase() {
        // given
        String inputWithSpaces = "  hello  ";
        
        // when
        String result = sampleService.processData(inputWithSpaces);

        // then
        assertThat(result)
            .isNotNull()
            .isEqualTo(EXPECTED_UPPER_HELLO);
    }

    @Test
    @DisplayName("Debe retornar cadena vacía cuando se proporciona cadena vacía")
    void processData_whenEmptyString_shouldReturnEmptyString() {
        // when
        String result = sampleService.processData(EMPTY_STRING);

        // then
        assertThat(result)
            .isNotNull()
            .isEmpty();
    }

    @Test
    @DisplayName("Debe retornar cadena vacía cuando la entrada es null")
    void processData_whenNullInput_shouldReturnEmptyString() {
        // when
        String result = sampleService.processData(null);

        // then
        assertThat(result)
            .isNotNull()
            .isEmpty();
    }

    // ===== Tests para processData(String, boolean) =====

    @Test
    @DisplayName("Debe retornar texto en mayúsculas cuando entrada válida y validación activa")
    void processDataWithValidation_whenValidInputAndValidateTrue_shouldReturnUpperCase() {
        // when
        String result = sampleService.processData(VALID_INPUT_HELLO, true);

        // then
        assertThat(result)
            .isNotNull()
            .isEqualTo(EXPECTED_UPPER_HELLO);
    }

    @Test
    @DisplayName("Debe lanzar IllegalArgumentException cuando entrada null y validación activa")
    void processDataWithValidation_whenNullInputAndValidateTrue_shouldThrowIllegalArgumentException() {
        // when & then
        assertThatThrownBy(() -> sampleService.processData(null, true))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage(ERROR_MESSAGE_NULL_INPUT);
    }

    @Test
    @DisplayName("Debe retornar cadena vacía cuando entrada null y validación desactivada")
    void processDataWithValidation_whenNullInputAndValidateFalse_shouldReturnEmptyString() {
        // when
        String result = sampleService.processData(null, false);

        // then
        assertThat(result)
            .isNotNull()
            .isEmpty();
    }

    @Test
    @DisplayName("Debe retornar texto en mayúsculas cuando entrada válida y validación desactivada")
    void processDataWithValidation_whenValidInputAndValidateFalse_shouldReturnUpperCase() {
        // when
        String result = sampleService.processData(VALID_INPUT_WORLD, false);

        // then
        assertThat(result)
            .isNotNull()
            .isEqualTo(EXPECTED_UPPER_WORLD);
    }

    // ===== Tests para filterList(List<T>, String) =====

    @Test
    @DisplayName("Debe retornar lista filtrada cuando hay coincidencias con el criterio")
    void filterList_whenValidCriteria_shouldReturnFilteredList() {
        // given
        List<String> items = Arrays.asList(ITEM_APPLE, ITEM_BANANA, ITEM_APRICOT, ITEM_CHERRY);

        // when
        List<String> result = sampleService.filterList(items, FILTER_CRITERIA_AP);

        // then
        assertThat(result)
            .isNotNull()
            .hasSize(EXPECTED_FILTERED_SIZE_TWO)
            .contains(ITEM_APPLE, ITEM_APRICOT);
    }

    @Test
    @DisplayName("Debe retornar lista vacía cuando no hay coincidencias con el criterio")
    void filterList_whenNoMatches_shouldReturnEmptyList() {
        // given
        List<String> items = Arrays.asList(ITEM_APPLE, ITEM_BANANA, ITEM_CHERRY);

        // when
        List<String> result = sampleService.filterList(items, FILTER_CRITERIA_XYZ);

        // then
        assertThat(result)
            .isNotNull()
            .isEmpty();
    }

    @Test
    @DisplayName("Debe retornar lista vacía cuando la lista de entrada está vacía")
    void filterList_whenEmptyList_shouldReturnEmptyList() {
        // given
        List<String> items = Arrays.asList();

        // when
        List<String> result = sampleService.filterList(items, FILTER_CRITERIA_AP);

        // then
        assertThat(result)
            .isNotNull()
            .isEmpty();
    }

    @Test
    @DisplayName("Debe filtrar correctamente lista de enteros según criterio")
    void filterList_whenIntegerList_shouldFilterCorrectly() {
        // given
        List<Integer> items = Arrays.asList(NUMBER_100, NUMBER_200, NUMBER_105, NUMBER_305);

        // when
        List<Integer> result = sampleService.filterList(items, FILTER_CRITERIA_10);

        // then
        assertThat(result)
            .isNotNull()
            .hasSize(EXPECTED_FILTERED_SIZE_TWO)
            .contains(NUMBER_100, NUMBER_105);
    }

    // ===== Tests para complexMethod(String) =====

    @Test
    @DisplayName("Debe ejecutarse sin errores cuando se proporciona parámetro válido")
    void complexMethod_whenValidParam_shouldExecuteWithoutErrors() {
        // when & then
        assertThatCode(() -> sampleService.complexMethod(COMPLEX_METHOD_PARAM))
            .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Debe manejar correctamente cuando el parámetro es null")
    void complexMethod_whenNullParam_shouldHandleGracefully() {
        // when & then
        assertThatCode(() -> sampleService.complexMethod(null))
            .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Debe ejecutarse sin errores cuando el parámetro está vacío")
    void complexMethod_whenEmptyParam_shouldExecuteWithoutErrors() {
        // when & then
        assertThatCode(() -> sampleService.complexMethod(EMPTY_STRING))
            .doesNotThrowAnyException();
    }
}

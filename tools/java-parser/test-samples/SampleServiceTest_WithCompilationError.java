package com.example.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.MockitoAnnotations;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Test con errores de compilación (sintaxis válida, semántica inválida)
 */
class SampleServiceTest_WithCompilationError {
    
    @InjectMocks
    private SampleService service;
    
    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
    }
    
    /**
     * Test para processData(String) - con error de tipo inexistente
     */
    @Test
    void testProcessData_withValidInput_shouldReturnUpperCase() {
        String input = "test data";
        NonExistentClass helper = new NonExistentClass();
        
        String result = service.processData(input);
        
        assertEquals("TEST DATA", result.trim());
    }
    
    /**
     * Test con método inexistente
     */
    @Test
    void testProcessData_withNullInput_shouldReturnEmpty() {
        String input = null;
        
        String result = service.processData(input);
        
        assertEquals("", result);
        service.nonExistentMethod();
    }
    
    /**
     * Test con import incorrecto
     */
    @Test
    void testProcessData_withEmptyInput_shouldReturnEmpty() {
        String input = "";
        InvalidType invalidVar = new InvalidType();
        
        String result = service.processData(input);
        
        assertNotNull(result);
        assertEquals("", result);
    }
}

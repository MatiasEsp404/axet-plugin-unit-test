package com.nttdata.sample;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.util.Arrays;
import java.util.List;

/**
 * Tests unitarios para SampleService
 * Generado como parte de la prueba de concepto del Agentic Workflow
 */
public class SampleServiceTest {
    
    private SampleService sampleService;
    
    @BeforeEach
    public void setUp() {
        sampleService = new SampleService();
    }
    
    @Test
    public void testProcessData_withValidData_shouldReturnProcessedString() {
        // Arrange
        String input = "test";
        boolean flag = true;
        
        // Act
        String result = sampleService.processData(input, flag);
        
        // Assert
        assertNotNull(result);
        assertTrue(result.contains("PROCESSED"));
        assertTrue(result.contains("test"));
    }
    
    @Test
    public void testProcessData_withFlagFalse_shouldReturnOriginalString() {
        // Arrange
        String input = "test";
        boolean flag = false;
        
        // Act
        String result = sampleService.processData(input, flag);
        
        // Assert
        assertNotNull(result);
        assertEquals("test", result);
    }
    
    @Test
    public void testProcessData_withNullInput_shouldHandleGracefully() {
        // Arrange
        String input = null;
        boolean flag = true;
        
        // Act & Assert
        assertDoesNotThrow(() -> sampleService.processData(input, flag));
    }
    
    @Test
    public void testCalculateSum_withValidList_shouldReturnCorrectSum() {
        // Arrange
        List<Integer> numbers = Arrays.asList(1, 2, 3, 4, 5);
        
        // Act
        int result = sampleService.calculateSum(numbers);
        
        // Assert
        assertEquals(15, result);
    }
    
    @Test
    public void testCalculateSum_withEmptyList_shouldReturnZero() {
        // Arrange
        List<Integer> numbers = Arrays.asList();
        
        // Act
        int result = sampleService.calculateSum(numbers);
        
        // Assert
        assertEquals(0, result);
    }
    
    @Test
    public void testFilterItems_withValidPredicate_shouldFilterCorrectly() {
        // Arrange
        List<String> items = Arrays.asList("apple", "banana", "cherry", "date");
        
        // Act
        List<String> result = sampleService.filterItems(items, s -> s.startsWith("a"));
        
        // Assert
        assertNotNull(result);
        assertEquals(1, result.size());
        assertEquals("apple", result.get(0));
    }
    
    @Test
    public void testTransformData_withValidInput_shouldTransformCorrectly() {
        // Arrange
        String input = "test";
        
        // Act
        String result = sampleService.transformData(input);
        
        // Assert
        assertNotNull(result);
        assertTrue(result.length() > input.length());
    }
    
    @Test
    public void testValidateInput_withValidString_shouldReturnTrue() {
        // Arrange
        String input = "validString123";
        
        // Act
        boolean result = sampleService.validateInput(input);
        
        // Assert
        assertTrue(result);
    }
    
    @Test
    public void testValidateInput_withInvalidString_shouldReturnFalse() {
        // Arrange
        String input = "";
        
        // Act
        boolean result = sampleService.validateInput(input);
        
        // Assert
        assertFalse(result);
    }
}

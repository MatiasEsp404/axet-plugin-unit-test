package com.example.service;

import java.util.List;

/**
 * Clase de ejemplo para probar el parser AST
 */
public class SampleService {
    
    // Método simple sin parámetros
    public void initialize() {
        System.out.println("Initializing service");
    }
    
    // Método con un parámetro
    public String processData(String input) {
        return input.toUpperCase();
    }
    
    // Método con múltiples parámetros (sobrecarga)
    public String processData(String input, boolean validate) {
        if (validate && input == null) {
            throw new IllegalArgumentException("Input cannot be null");
        }
        return input != null ? input.toUpperCase() : "";
    }
    
    // Método con genéricos
    public <T> List<T> filterList(List<T> items, String criteria) {
        // Lógica compleja con comentarios
        /* 
         * Este comentario debe ser ignorado
         * al calcular el hash
         */
        return items.stream()
            .filter(item -> item.toString().contains(criteria))
            .collect(java.util.stream.Collectors.toList());
    }
    
    // Método con lambdas y clases anónimas (caso complejo)
    public void complexMethod(String param) {
        Runnable task = () -> {
            System.out.println("Lambda expression");
            if (param != null) {
                System.out.println(param);
            }
        };
        
        Thread thread = new Thread(new Runnable() {
            @Override
            public void run() {
                System.out.println("Anonymous inner class");
            }
        });
        
        task.run();
        thread.start();
    }
}

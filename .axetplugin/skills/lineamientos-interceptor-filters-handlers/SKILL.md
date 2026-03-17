---
name: lineamientos-interceptor-filters-handlers
description: Skill ejecutable para generar tests unitarios sobre Interceptors, Filters y Handlers. Guía ajustada para OMITIR la generación de estos tests.
---

# SKILL: Testing de Interceptors, Filters y Handlers

## 🎯 1. OBJETIVO Y ALCANCE
- **❌ NO TESTEAR:** Clases que actúan como Filtros (`Filter`), interceptores de Spring MVC (`HandlerInterceptor`) u otros manejadores genéricos de peticiones web.
- **MOTIVO:** A menos que contengan lógica puramente aislada (algo que es raro), estas clases interceptan requests y manejan cabeceras que requieren los contextos web completos para su correcta ejecución. Testearlos unitariamente no otorga el nivel de confianza necesario ni es el enfoque adecuado comparado con tests de integración.

## 🛑 2. ACCIÓN REQUERIDA
Detén el proceso INMEDIATAMENTE y marca esta clase como **EXCLUDED** en el archivo `control.csv`. No generes ningún archivo de prueba.
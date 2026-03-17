---
name: lineamientos-controllers
description: Skill ejecutable para generar tests unitarios sobre REST Controllers. Guía ajustada para OMITIR la generación de estos tests.
---

# SKILL: Testing de Controllers

## 🎯 1. OBJETIVO Y ALCANCE
- **❌ NO TESTEAR:** Clases anotadas con `@RestController` o `@Controller` encargadas de la exposición de APIs.
- **MOTIVO:** En una arquitectura correcta de Spring, los controladores deben ser "thin" (delgados), delegando toda su responsabilidad a componentes de servicio correspondientes. Al probarlos unitariamente instanciando directamente la clase de Java se pierde enormemente el valor de las validaciones, parseo, manejo de excepciones y binding de URL. Todo controlador debe probarse mediante pruebas de integración (por ejemplo, con `MockMvc`).

## 🛑 2. ACCIÓN REQUERIDA
Detén el proceso INMEDIATAMENTE y marca esta clase como **EXCLUDED** en el archivo `control.csv`. No gastes créditos en tests unitarios para controladores.
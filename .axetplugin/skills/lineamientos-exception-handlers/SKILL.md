---
name: lineamientos-exception-handlers
description: Skill ejecutable para generar tests unitarios sobre Exception Handlers. Guía ajustada para OMITIR la generación de estos tests.
---

# SKILL: Testing de Exception Handlers

## 🎯 1. OBJETIVO Y ALCANCE
- **❌ NO TESTEAR:** Clases anotadas con `@ControllerAdvice` o que manejen excepciones globales.
- **MOTIVO:** Estas clases generalmente poseen lógica de transformación de errores que dependene fuertemente del contexto de Spring y se prueban mejor, con mayor seguridad y confiabilidad a través de tests de integración (como `@WebMvcTest`). Generar test unitarios para estas clases es propenso a errores y no garantiza que la serialización de los mensajes ni los filtros operen correctamente.

## 🛑 2. ACCIÓN REQUERIDA
Detén el proceso INMEDIATAMENTE y marca esta clase como **EXCLUDED** en el archivo `control.csv`. No intentes generar tests unitarios para Exception Handlers.

---
name: lineamientos-dtos
description: Skill ejecutable para generar tests unitarios sobre DTOs y Entidades. Guía ajustada para OMITIR OBLIGATORIAMENTE la generación de estos tests.
---

# SKILL: Testing de DTOs y POJOs

## 🎯 1. OBJETIVO Y ALCANCE
- **❌ NO TESTEAR NUNCA:** Clases que funcionan como Data Transfer Objects (DTOs), Entities o simples POJOs (Plain Old Java Objects).
- **MOTIVO:** Probar getters, setters, constructores o el estado de un POJO carece totalmente de valor, generando pruebas ruidosas que consumen tiempo de cómputo inútilmente y no detectan defectos reales en el código. Las validaciones incluidas mediante anotaciones (Bean Validation, `@NotNull`, etc.) deben verificarse en los servicios de negocio o capas de integración.

## 🛑 2. ACCIÓN REQUERIDA
Detén el proceso INMEDIATAMENTE, sin condiciones, y marca esta clase como **EXCLUDED** en el archivo `control.csv`. Jamás se deben escribir test unitarios para entidades o DTOs.

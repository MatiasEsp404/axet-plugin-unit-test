---
name: lineamientos-configuraciones
description: Skill ejecutable para generar tests unitarios sobre Configuraciones. Guía ajustada para OMITIR la generación de estos tests.
---

# SKILL: Testing de Configuraciones

## 🎯 1. OBJETIVO Y ALCANCE
- **❌ NO TESTEAR:** Clases anotadas con `@Configuration` destinadas a crear beans para el ecosistema o contexto.
- **MOTIVO:** Comprobar si un método genera y expone un determinado Bean dentro del contexto de inyección de dependencias de Spring Boot es probar la funcionalidad del framework. Salvo que la configuración posea una regla de selección compleja ajena al motor (lo cual es sumamente raro), un test unitario aquí no tiene lugar.

## 🛑 2. ACCIÓN REQUERIDA
Detén el proceso INMEDIATAMENTE y marca esta clase como **EXCLUDED** en el archivo `control.csv`. Ignora todas las configuraciones generadas en este módulo.
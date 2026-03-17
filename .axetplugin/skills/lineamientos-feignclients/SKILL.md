---
name: lineamientos-feignclients
description: Skill ejecutable para generar tests unitarios sobre Feign Clients. Guía ajustada para OMITIR la generación de estos tests.
---

# SKILL: Testing de Feign Clients

## 🎯 1. OBJETIVO Y ALCANCE
- **❌ NO TESTEAR:** Interfaces anotadas con `@FeignClient`.
- **MOTIVO:** Estas interfaces carecen de lógica de implementación en Java para ser probadas. Todo el cuerpo es autogenerado en tiempo de ejecución. La verificación de un cliente HTTP Feign debe hacerse estrictamente integrándolo con tecnologías como `WireMock` o validado mediante pruebas de Contrato, de lo contrario se estará probando código abstracto con cero rigor lógico.

## 🛑 2. ACCIÓN REQUERIDA
Detén el proceso INMEDIATAMENTE y marca esta clase como **EXCLUDED** en el archivo `control.csv`. Jamás generes prueba para feign clients con este agente.

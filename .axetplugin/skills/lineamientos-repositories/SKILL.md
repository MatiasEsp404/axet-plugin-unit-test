---
name: lineamientos-repositories
description: Skill ejecutable para generar tests unitarios sobre Repositories de Spring Data. Guía ajustada para OMITIR la generación de estos tests.
---

# SKILL: Testing de Repositories

## 🎯 1. OBJETIVO Y ALCANCE
- **❌ NO TESTEAR:** Interfaces que extiendan o implementen `JpaRepository`, `CrudRepository` o equivalentes de Spring Data, o cualquier clase anotada con `@Repository`. 
- **MOTIVO:** Estas clases en la gran mayoría de casos solo confían en consultas JPA generadas automáticamente. Probar un repositorio base unitariamente consistiría en probar directamente el framework. Las pruebas que involucren persistencia deben hacerse mediante `@DataJpaTest` o configuraciones H2 (pruebas de integración). Si el agente es netamente unitario, aquí sobra la acción.

## 🛑 2. ACCIÓN REQUERIDA
Detén el proceso INMEDIATAMENTE y marca esta clase como **EXCLUDED** en el archivo `control.csv`. No escribas tests unitarios para repositorios.
# Métodos No Testeados

Registro de métodos que no pudieron ser testeados durante la generación automática de tests unitarios.

| Clase | Método | Motivo | Recomendación |
|-------|--------|--------|---------------|
| DigitalizacionServiceImpl | digitalizar() | Dependencias complejas (RestTemplate, reflection, múltiples servicios) y lógica orquestada hacen difícil el test unitario | Considerar refactorizar separando: 1) indexación RCE, 2) búsqueda automática, 3) derivación. Evaluar tests de integración. |

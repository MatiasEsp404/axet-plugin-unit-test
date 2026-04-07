# Métodos No Testeados

Este archivo registra los métodos que no pudieron ser testeados unitariamente, junto con el motivo y las recomendaciones.

| Clase | Método | Motivo | Recomendación |
|-------|--------|--------|---------------|
| RepositorioDocumentoServiceImpl | borrarArchivoWebDav | Método sin implementación (vacío) | Implementar lógica o eliminar método si no se usa |
| RepositorioDocumentoServiceImpl | copiarArchivo (2 sobrecargas) | Métodos sin implementación (vacíos) | Implementar lógica o eliminar métodos si no se usan |
| RepositorioDocumentoServiceImpl | borrarCarpeta | Método sin implementación (vacío) | Implementar lógica o eliminar método si no se usa |
| DigitalizacionServiceImpl | digitalizar() | Dependencias complejas (RestTemplate, reflection, múltiples servicios) y lógica orquestada hacen difícil el test unitario | Considerar refactorizar separando: 1) indexación RCE, 2) búsqueda automática, 3) derivación. Evaluar tests de integración. |

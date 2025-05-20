# Tech Debt Log

Este archivo rastrea la deuda técnica identificada durante el desarrollo.

## Configuración y Seguridad

### 1. Gestión del Token de Mapbox

- **Fecha Identificada:** 2024-07-31
- **Descripción:** Actualmente, el token de Mapbox está hardcodeado en `lib/backend/services/geocoding_service_adapter.dart` como una constante pública. Si bien esto fue una decisión consciente para la fase de desarrollo actual, no es una práctica recomendada para entornos de producción o para repositorios que puedan volverse públicos.
- **Impacto Potencial:**
  - **Seguridad:** Exponer tokens directamente en el código fuente versionado puede llevar a su abuso si el código se filtra o el repositorio es público.
  - **Mantenibilidad:** Cambiar el token requiere una modificación directa del código y una nueva compilación. Dificulta el uso de diferentes tokens para distintos entornos (desarrollo, staging, producción).
- **Acción Sugerida:** Antes de pasar a un entorno de producción o si el repositorio se comparte más ampliamente, se debe reimplementar un sistema más seguro y flexible para la gestión del token. Las opciones incluyen:
  - **Variables de Entorno:** Utilizar `String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: 'tu_valor_por_defecto_o_vacio')` como se hacía anteriormente, asegurando que el proceso de build (CI/CD) inyecte el token correctamente para cada entorno.
  - **Servicio de Configuración Remota:** Para mayor flexibilidad y seguridad, considerar obtener el token de un servicio de configuración remota al inicio de la aplicación.
- **Estado:** Pendiente.

# 🐛 BUGS Y MEJORAS - BondiUY Flutter

## Reparación Post-Refactor Inicial

**Contexto**: Después del refactor inicial, hemos identificado varios problemas críticos que impiden que la app funcione como se espera. La visión es una app "abuelita-friendly" - tan intuitiva que tu abuelita pueda usarla para llegar a casa.

---

## 🚨 BUGS CRÍTICOS

### Bug #1: TypeAheadField no muestra sugerencias en tiempo real

**Problema**: Las sugerencias llegan del backend (se ve en logs) pero el dropdown no aparece hasta que el usuario presiona espacio u otra tecla.

**Síntomas**:

- Usuario escribe "plaza i"
- Logs muestran: "Obtenidas 2 sugerencias para 'plaza i'"
- Dropdown no aparece
- Usuario presiona espacio → ahí recién aparece el dropdown

**Ubicación**: `lib/ui/widgets/app_compose_with_origin.dart`

**Análisis**: El `TypeAheadField` no se refresca automáticamente cuando llegan nuevas sugerencias del estado. El `suggestionsCallback` solo se ejecuta en input del usuario, no en cambios de estado.

**Solución Implementada**:

- Uso de `SuggestionsController` para triggerar refreshes manuales
- Detección de cambios en sugerencias y refresh automático
- Prevención de dropdown vacío después de selecciones

**Prioridad**: 🔴 CRÍTICA
**Estado**: ✅ COMPLETADO

---

### Bug #2: Mapas múltiples rompen la experiencia de navegación

**Problema**: Cada vista (`InitialPhaseView`, `RouteOptionsView`, `ActiveTripView`) tiene su propio `MapWidget`, causando:

- Percepción de "cambio de mapa" entre fases
- Pérdida de contexto visual
- Carga innecesaria de recursos

**Síntomas**:

- Usuario hace búsqueda en un mapa
- Presiona "Buscar Ruta" → ve que "cambia a otro mapa"
- Experiencia jarring, no fluida

**Ubicación**:

- `lib/ui/initial_phase_view.dart` (línea ~456)
- `lib/ui/route_options_view.dart` (línea ~344)
- `lib/ui/active_trip_view.dart`

**Solución Implementada**:

1. ✅ Mapa único en `AppHost` como base persistente
2. ✅ Overlays por fase (`InitialPhaseOverlay`, `RouteOptionsOverlay`, `ActiveTripOverlay`)
3. ✅ Transiciones fluidas sin recrear mapa
4. ⏳ Migración de lógica de capas del mapa (próximo)

**Prioridad**: 🔴 CRÍTICA
**Estado**: ✅ COMPLETADO

---

### Bug #3: Carousel de opciones de ruta no es intuitivo

**Problema**: El carousel de opciones muestra una línea azul básica sin colores distintivos, no hay preview interactivo de ruta, y no es "abuelita-friendly"

**Síntomas**:

- Solo muestra línea azul genérica
- No hay carousel horizontal intuitivo
- No muestra preview de cada opción al seleccionarla
- Colores incorrectos vs proyecto viejo
- Preview no se mostraba al cargar opciones por primera vez

**Ubicación**: `lib/ui/overlays/route_options_overlay.dart`

**Solución Implementada**:

1. ✅ UI moderna y minimalista implementada (cards estilo material design)
2. ✅ Carousel horizontal con indicadores de página
3. ✅ Preview de ruta con estilos originales exactos:
   - **WALK**: Líneas SÓLIDAS azul (`0xFF448AFF` - Colors.blueAccent), grosor 4px, NO dashed
   - **BUS**: Líneas sólidas naranja (`0xFFFF5722` - Colors.deepOrangeAccent), grosor 5px
   - **WAIT**: Círculos naranjas (`0xFFFFA500` - Colors.orange), radio 8px, borde blanco
   - **BORDES**: Líneas completamente opacas negras (`0xFF000000`), grosor 8px para contraste
   - Marcadores verde/rojo para origen/destino
4. ✅ Sistema de highlighting para viaje activo con estados transparentados/destacados
5. ✅ Layout responsivo para pantallas pequeñas y medianas
6. ✅ Arreglados problemas de overflow usando Flutter best practices
7. ✅ Zoom automático a ruta con padding adaptativo
8. ✅ Sistema de inicialización inteligente:
   - PageController inicializado con opción recomendada
   - Preview automático al cargar opciones por primera vez
   - Navegación libre sin reseteo automático
   - Manejo robusto de errores concurrentes
9. ✅ Preview interactivo que se actualiza al cambiar de opción
10. ✅ Archivo `map_style_constants.dart` con estilos reutilizables para futuras funciones
11. ✅ **CORREGIDO**: Estilos exactos del código viejo aplicados (WALK sólido, grosores correctos)
12. ✅ **CORREGIDO**: Problema de bordes/sombras solucionado:
    - Reemplazadas sombras transparentes problemáticas por líneas de borde sólidas
    - Eliminado efecto de degradado extraño en bordes
    - Mejor contraste y visibilidad de tramos en el mapa
    - Solución técnica: líneas idénticas más gruesas y opacas por debajo
13. ✅ **MEJORAS UX ADICIONALES (Enero 2025)**:
    - **Panel colapsable**: `DraggableScrollableSheet` permite colapsar para usuarios avanzados que quieren hacer zoom manual
    - **Iconos de parada reales**: Reemplazados círculos de colores por `stop_icon.png` original con flechas indicativas (↑ verde subir, ↓ roja bajar)
    - **Z-order corregido**: Paradas siempre aparecen encima de líneas de ruta en todos los niveles de zoom
    - **Limpieza de estado**: Preview se limpia automáticamente al cancelar y volver a fase de búsqueda
    - **Panel completamente expandido**: Inicia 100% expandido para mejor UX inicial

**Características Implementadas**:

- **Diseño moderno**: Cards con selección visual (highlighting azul)
- **Información completa**: Duración, hora llegada, ETA tiempo real, distancia caminata
- **Iconografía clara**: Modos de transporte con conectores visuales
- **Responsivo**: Adaptación automática a pantallas pequeñas (< 700px)
- **Preview automático**: Muestra ruta desde el primer momento
- **Navegación intuitiva**: Permite cambio libre entre opciones

**Prioridad**: 🔴 CRÍTICA
**Estado**: ✅ **COMPLETADO**

**Criterios de Aceptación Cumplidos**:

- ✅ Preview se muestra automáticamente al cargar opciones
- ✅ Usuario puede navegar libremente entre opciones
- ✅ Cada opción muestra su ruta en el mapa con colores distintivos
- ✅ UI es intuitiva y "abuelita-friendly"
- ✅ Layout responsivo funciona en diferentes tamaños de pantalla
- ✅ No hay errores de concurrent modification
- ✅ PageController sincronizado correctamente

---

## 🎯 MEJORAS UX "ABUELITA-FRIENDLY"

### Mejora #1: Flujo de viaje activo por pasos

**Descripción**: En la fase de viaje activo, guiar paso a paso:

1. **Caminar** → Zoom a punto de origen + ruta a primera parada
2. **Esperar** → Focus en parada + bus en tiempo real (si disponible)
3. **Viajar** → Seguir bus de parada origen a destino
4. **Llegar** → Zoom a destino final

**Características**:

- Auto-avance por pasos cuando corresponda
- Botones grandes y claros para navegación manual
- Instrucciones en lenguaje simple
- Indicador visual de progreso

**Prioridad**: 🟡 MEDIA
**Estado**: ❌ PENDIENTE

---

## 📋 PLAN DE IMPLEMENTACIÓN

### Fase 1: Reparar Bugs Críticos (Esta Semana)

1. **[Bug #1]** Arreglar TypeAheadField para sugerencias en tiempo real
2. **[Bug #2]** Implementar mapa único persistente
3. **[Bug #3]** Crear carousel de opciones de ruta

### Fase 2: Mejorar UX (Próxima Semana)

1. **[Mejora #1]** Implementar flujo de viaje por pasos
2. Revisar y aplicar styling del proyecto viejo
3. Testing con usuarios reales ("abuelitas")

---

## 🔧 NOTAS TÉCNICAS

### Mapa Único - Enfoque Propuesto:

```dart
// En AppHost - un solo MapWidget
Stack(
  children: [
    MapWidget(...), // Único mapa persistente
    if (faseActual == FaseApp.INICIAL_SIN_BUSQUEDA)
      InitialPhaseOverlay(),
    if (faseActual == FaseApp.MOSTRANDO_OPCIONES_RUTA)
      RouteOptionsOverlay(),
    if (faseActual == FaseApp.VIAJE_ACTIVO_EN_CURSO)
      ActiveTripOverlay(),
  ],
)
```

### TypeAheadField - Fix Propuesto:

- Usar `FutureBuilder` o `StreamBuilder` para reactividad
- Trigger manual del `suggestionsCallback` cuando cambie el estado
- Key dinámico para forzar rebuild cuando necesario

### Bordes de Líneas - Solución Implementada:

**Problema**: Las sombras transparentes en Mapbox causaban efectos de rendering extraños (bordes que comenzaban oscuros y se volvían claros).

**Solución**: Reemplazar sombras por líneas de borde sólidas:

```dart
// ANTES: Sombras transparentes problemáticas
'line-color': 0x66000000, // withOpacity(0.4)
'line-opacity': 0.7, // Transparencias problemáticas

// DESPUÉS: Líneas de borde sólidas
'line-color': 0xFF000000, // Negro completamente opaco
'line-opacity': 1.0, // Sin transparencias
'line-width': 8.0, // Más gruesa que línea principal (4-5px)
```

**Ventajas**:

- Elimina problemas de rendering de transparencias
- Bordes uniformes y consistentes
- Mejor contraste visual
- Más fácil de mantener

---

## ✅ CRITERIOS DE ACEPTACIÓN

**Para considerar "COMPLETADO":**

- [x] Usuario puede escribir y ver sugerencias inmediatamente
- [x] Navegación entre fases es fluida (mismo mapa)
- [x] Carousel de opciones es intuitivo y funcional
- [ ] App pasa el "test de la abuelita" (usable por personas no técnicas)

---

**Última actualización**: `2025-01-23 - Bug #3 completado + Mejoras UX adicionales (panel colapsable, iconos reales, z-order)`
**Responsable**: Claude (AI Assistant)
**Revisión siguiente**: Implementación de Mejora #1 (flujo step-by-step)

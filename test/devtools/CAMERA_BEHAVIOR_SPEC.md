# Especificaciones de Comportamiento de Cámara Durante Trip

## Principios Generales

1. **Auto-follow enabled por defecto**: La cámara sigue automáticamente el progreso del usuario
2. **Cooldown entre animaciones**: Mínimo 3 segundos entre zooms para evitar mareo
3. **Cambios significativos**: Solo animar si el cambio de viewport es > 20m centro o > 30m expansión de bounds
4. **Override en transiciones de paso**: Cuando cambia el paso actual, se ignora cooldown una vez
5. **Pausa por interacción manual**: Si el usuario mueve la cámara, auto-follow se pausa 6 segundos

## Comportamiento por Fase del Trip

### FASE 0: Inicio del Viaje (zoomToActiveTrip)

**Cuándo**: Al confirmar ruta e iniciar viaje

**Qué debe mostrar**:
- Toda la geometría del viaje completo (todos los tramos)
- Ubicación actual del usuario
- Padding: top=250, left=40, bottom=100, right=40 (espacio para UI de navegación)

**Assertions**:
```
✓ Se ejecuta exactamente 1 flyTo
✓ Incluye TODAS las coordenadas de TODOS los tramos
✓ Incluye posición inicial del usuario
✓ Usa padding de active trip (250/40/100/40)
✓ Marca _initialCameraDone = true
```

---

### FASE 1: Usuario Caminando a Parada (Paso 0: CAMINAR)

**Cuándo**: Primer paso del viaje, usuario va hacia la parada de bus

**Qué debe mostrar**:
- Geometría completa del tramo de caminata
- Coordenadas de la parada destino (donde esperar el bus)
- Posición del bus SI está <= 5 minutos de la parada
- Posición actual del usuario (dinámica)
- Padding: top=260, left=60, bottom=160, right=60

**Assertions**:
```
✓ Se ejecuta flyTo al entrar al paso (con override de cooldown)
✓ Incluye geometría del tramo CAMINAR
✓ Incluye coordenadas de parada destino
✓ Incluye posición usuario actual
✓ SI bus.eta <= 5 min: incluye posición bus
✓ SI bus.eta > 5 min: NO incluye posición bus
✓ Usa padding de current leg (260/60/160/60)
```

**Actualizaciones durante la fase**:
- NO debe hacer zoom adicional mientras usuario camina (sería spam)
- SOLO si bus entra en ventana de 5 min Y cambio es significativo

---

### FASE 2: Usuario Esperando Bus (Paso 1: ESPERAR_BUS)

**Cuándo**: Usuario llegó a la parada, esperando que llegue el bus

**Qué debe mostrar**:
- Coordenadas de la parada (punto fijo)
- Posición del bus en tiempo real (dinámica)
- Posición del usuario (debería estar en/cerca de parada)
- Padding: top=260, left=60, bottom=160, right=60

**Assertions**:
```
✓ Se ejecuta flyTo al entrar al paso (con override de cooldown)
✓ Incluye coordenadas de parada origen
✓ Incluye posición bus actual
✓ Incluye posición usuario actual
✓ Usa padding de current leg (260/60/160/60)
```

**Actualizaciones durante la fase**:
- `updateWaitingBusViewport()` se llama periódicamente
- DEBE respetar auto-follow (skip si usuario pausó cámara)
- DEBE respetar cooldown (no spam cada segundo)
- DEBE verificar cambio significativo (bus avanzó > 20m)

**Assertions dinámicas**:
```
✓ SI bus se acerca significativamente: ejecuta flyTo
✓ SI bus está lejos y no cambió mucho: NO ejecuta flyTo (evita spam)
✓ SI auto-follow disabled: NO ejecuta flyTo
✓ SI en cooldown: NO ejecuta flyTo (respeta 3s)
```

---

### FASE 3: Viajando en Bus (Paso 2: VIAJE_EN_BUS)

**Cuándo**: Usuario abordó el bus, viajando hacia parada destino

**Qué debe mostrar**:
- Posición del bus/usuario (están juntos)
- Coordenadas de parada destino (donde bajar)
- Padding: top=260, left=60, bottom=160, right=60

**Assertions**:
```
✓ Se ejecuta flyTo al entrar al paso (con override de cooldown)
✓ Incluye posición bus actual
✓ Incluye coordenadas parada destino
✓ Usa padding de current leg (260/60/160/60)
✓ NO incluye geometría completa del recorrido bus (sería zoom out excesivo)
```

**Actualizaciones durante la fase**:
- NO debe hacer zoom adicional (usuario ya está en contexto)
- Bus y usuario se mueven juntos, viewport ya los incluye

---

### FASE 4: Caminando a Destino Final (Paso 3: CAMINAR)

**Cuándo**: Usuario bajó del bus, caminando hacia destino final

**Qué debe mostrar**:
- Geometría completa del tramo de caminata
- Coordenadas del destino final
- Posición actual del usuario (dinámica)
- Padding: top=260, left=60, bottom=160, right=60

**Assertions**:
```
✓ Se ejecuta flyTo al entrar al paso (con override de cooldown)
✓ Incluye geometría del tramo CAMINAR final
✓ Incluye coordenadas destino final
✓ Incluye posición usuario actual
✓ NO incluye posición bus (ya no es relevante)
✓ Usa padding de current leg (260/60/160/60)
✓ Tiene al menos 2 coordenadas (geometría + destino)
```

**Actualizaciones durante la fase**:
- NO debe hacer zoom adicional mientras usuario camina

---

## Casos Edge

### Usuario pausa cámara manualmente

```
✓ Auto-follow se desactiva inmediatamente
✓ Timer de 6 segundos se programa
✓ NO se ejecutan flyTo mientras pausado
✓ Después de 6s: auto-follow se reactiva
✓ Al reactivar: ejecuta flyTo con override (refresh viewport)
```

### Cambios insignificantes

```
✓ SI centro se movió < 20m: NO animar
✓ SI bounds cambió < 30m: NO animar
✓ Log debe indicar "skip_minor_change"
```

### Cooldown entre animaciones

```
✓ Primera animación: NO aplica cooldown
✓ Animaciones subsecuentes: mínimo 3s entre ellas
✓ Override en transición de paso: ignora cooldown una vez
✓ Override después de resume: ignora cooldown una vez
```

### Geometría vacía o inválida

```
✓ SI tramo tiene 0 coordenadas Y 0 puntos: NO crashear, skip zoom
✓ SI solo 1 coordenada: usar zoom centrado a 16.0
✓ SI múltiples coordenadas: usar cameraForCoordinates
```

## Invariantes Globales

1. **Nunca crashear**: Geometría inválida no debe romper el app
2. **Logs completos**: Cada decisión (fly, skip) debe loguear razón
3. **Respeto a usuario**: Manual interaction siempre gana sobre auto-follow
4. **Performance**: No más de 1 animación cada 3s (evita lag)
5. **Contexto correcto**: Padding debe reflejar UI actual (preview vs active trip vs leg)

## Secuencia Esperada en Trip Completo

```
1. Inicio viaje          → zoomToActiveTrip()      [1 flyTo, vista completa]
2. Enter Paso 0 CAMINAR  → zoomToCurrentLeg(0)     [1 flyTo, override cooldown]
3. Enter Paso 1 ESPERAR  → zoomToCurrentLeg(1)     [1 flyTo, override cooldown]
4. Durante ESPERAR       → updateWaitingBusViewport() [0-N flyTo, respeta cooldown/changes]
5. Enter Paso 2 RIDE     → zoomToCurrentLeg(2)     [1 flyTo, override cooldown]
6. Enter Paso 3 CAMINAR  → zoomToCurrentLeg(3)     [1 flyTo, override cooldown]
7. Llegada a destino     → (no hay zoom, trip termina)

TOTAL esperado: Mínimo 5 flyTo (inicio + 4 pasos)
                Máximo ~10 flyTo (+ updates durante ESPERAR si bus se mueve)
```

## Bugs Conocidos a Validar

1. **Paso 4 no hace zoom**: zoomToCurrentLeg(3) no se ejecuta o se bloquea
2. **Spam de zooms**: updateWaitingBusViewport() no respeta cooldown
3. **Zoom incorrecto en RIDE**: Incluye geometría completa de línea bus (20+ km)
4. **Auto-follow no resume**: Timer falla o no ejecuta override correctamente
5. **Cooldown bloquea transiciones**: Override no se activa en cambio de paso

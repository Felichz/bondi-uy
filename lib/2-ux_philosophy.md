# Filosofía de Experiencia de Usuario (UX): BondiUy - "Abuelita First"

Este documento describe la filosofía central de diseño y experiencia de usuario que guía el desarrollo de la capa de UI de BondiUy. Nuestro objetivo es crear una aplicación de transporte público que sea radicalmente simple, intuitiva y útil, especialmente en momentos de necesidad.

## El Contraste: Menos es Más

En un mundo donde muchas aplicaciones de transporte (como Moovit, mencionada por el usuario como ejemplo a _evitar_) sobrecargan al usuario con información excesiva, múltiples flujos complejos y una abrumadora cantidad de opciones, BondiUy toma el camino opuesto.

Nuestra app no busca ser una enciclopedia del transporte ni una herramienta para expertos. Busca ser un asistente personal, amable y eficiente que ayude a cualquier persona, incluso a alguien no familiarizado con la tecnología (la metáfora de "abuelita first" encapsula esta idea), a completar una tarea fundamental: **ir de un punto A a un punto B en transporte público de forma segura y sin estrés.**

## Principios Clave de la UX "Abuelita First"

Esta filosofía se basa en los siguientes pilipares:

1.  **Minimalismo Radical:**

    - Mostrar solo la información _esencial_ para la fase actual del viaje.
    - Evitar la sobrecarga visual y de opciones.
    - Cada elemento en pantalla debe tener un propósito claro y contribuir directamente a la tarea del usuario.

2.  **Intuición por Encima de Todo:**

    - Las acciones del usuario deben ser obvias y predecibles.
    - Los botones, iconos y textos deben ser claros y fáciles de entender para todos, sin jerga técnica ni suposiciones sobre conocimientos previos.
    - La interfaz debe sentirse natural al interactuar con ella.

3.  **Flujo de Usuario Guiado:**

    - La app debe acompañar al usuario paso a paso a través del proceso: **Buscar Origen/Destino > Ver Opciones Simplificadas > Seleccionar la Mejor Opción > Recibir Instrucciones Durante el Viaje.**
    - Se prioriza el flujo principal, presentando opciones secundarias de forma que no interrumpan o confundan al usuario promedio.

4.  **El Mapa como Narrador Visual:**

    - El mapa es un componente central de la UI, utilizado activamente para visualizar el viaje.
    - Mostrar la previsualización de la ruta en el mapa al explorar opciones ayuda al usuario a comprender visualmente las alternativas mejor que una lista de texto solamente.
    - Durante el viaje activo, usar el mapa para mostrar la posición en tiempo real del bus (si está disponible) y el progreso a lo largo de la ruta es una herramienta poderosa para reducir la ansiedad y confirmar que va por buen camino.

5.  **Enfoque en el "Viaje Activo":**
    - Una vez que el usuario inicia un viaje, la UI debe transformarse para apoyar esa fase crítica.
    - Las instrucciones deben ser prominentes y fáciles de seguir.
    - La información clave (como la ETA del próximo bus) debe estar accesible y clara.
    - Minimizar las distracciones y las opciones no relacionadas con el viaje en curso.

## Impacto en el Desarrollo de la UI

Esta filosofía implica que:

- Diseñaremos widgets con un solo propósito claro.
- La gestión del estado en la capa de UI (usando Riverpod) debe ser simple y reflejar directamente lo que necesita ser mostrado en cada fase de la app.
- La comunicación entre la capa de UI y la capa de Lógica (Backend) debe ser mínima y estrictamente definida por el `AppUiState` y las acciones de `IAppLogic`.
- Evitaremos añadir funcionalidades o información en la UI solo "porque se puede". Nos preguntaremos constantemente: "¿Esto ayuda a la abuelita a llegar a casa?"

Al adherirnos a estos principios, construiremos una aplicación que no solo sea funcional, sino que también sea un placer de usar y una verdadera ayuda para los ciudadanos de Montevideo.

---

### Contrato Conceptual entre Capa de UI y Capa de Lógica

Para mantener la separación clara y adherir a la arquitectura presentacional, definimos el "conocimiento" o los conceptos que cada capa _debe_ manejar y cuáles _no_. Esto asegura que la UI sea "tonta" y reactiva, y la Lógica sea la "inteligente" que gestiona el estado y la complejidad.

**La Capa de UI (Widgets, Vistas):**

- **Conoce:**
  - Cómo renderizar (`build`) el estado (`AppUiState`) que recibe.
  - Cómo reaccionar a gestos e interacciones del usuario (taps, scrolls, texto ingresado, etc.).
  - Cómo invocar las **acciones** definidas en `IAppLogic` en respuesta a esas interacciones.
  - Conceptos visuales y de layout (padding, margin, colores, fuentes, animaciones, modales, spinners visuales).
  - El estado interno _puramente visual_ de sus propios widgets (ej: si un campo de texto tiene foco, si una animación está en curso), **siempre y cuando ese estado no afecte la lógica de negocio o el estado general de la app más allá de la presentación inmediata**. Si el estado visual _debe_ ser coordinado a través de múltiples widgets o persistir (como la expansión del panel de búsqueda que impacta el mapa), entonces se refleja en `AppUiState`.
  - Cómo formatear datos crudos del `AppUiState` para la presentación (ej: convertir segundos a "5 min", mostrar fechas, aplicar formatos de número).
  - **Controlar el flujo de la interfaz de usuario y las interacciones visuales directas:** Esto incluye, por ejemplo, decidir cuándo y cómo hacer zoom en el mapa basándose en los cambios de `AppUiState` y las acciones del usuario, manejar animaciones, y gestionar el estado local de los widgets que no afecta la lógica de negocio.
- **No Conoce (y no debe importar ni instanciar):**
  - Reglas de negocio o lógica compleja.
  - Cómo obtener datos de APIs o servicios externos.
  - Cómo calcular rutas, ETAs o procesar datos geoespaciales.
  - Cómo almacenar o persistir datos.
  - El estado interno de la lógica de negocio (más allá de lo expuesto en `AppUiState`).

**La Capa de Lógica (Implementación de `IAppLogic`):**

- **Conoce:**
  - La implementación de las reglas de negocio.
  - Cómo interactuar con servicios (geocoding, enrutamiento, APIs de tiempo real).
  - Cómo procesar datos, realizar cálculos y determinar el _siguiente estado_ de la aplicación (`AppUiState`) en respuesta a las acciones de la UI o eventos internos (ej: timer para ETAs).
  - Cómo actualizar el `AppUiState` para reflejar el estado actual de la lógica.
  - Conceptos de dominio (paradas, líneas, rutas, puntos geográficos, usuarios, búsquedas, viajes).
- **No Conoce:**
  - Widgets específicos de Flutter.
  - Detalles de cómo se renderiza el `AppUiState`. (Por ejemplo, no le importa si el panel de búsqueda está colapsado o expandido; simplemente actualiza el estado `estadoCalculoRuta` en `AppUiState` cuando busca rutas, y la UI reacciona visualmente a eso).
  - Cómo reaccionar directamente a los gestos del usuario (solo responde a las _acciones_ invocadas por la UI).
  - El estado interno _puramente visual_ de los widgets de la UI.
  - **Controlar directamente el comportamiento del mapa o dictar flujos específicos de la UI:** Por ejemplo, la capa de lógica no debe decidir niveles de zoom, iniciar animaciones de mapa, o gestionar la visibilidad de elementos puramente presentacionales. Estas son responsabilidades de la capa de UI, que reacciona a los datos provistos en `AppUiState`.

**Ejemplo práctico:**

- La UI detecta un tap en el botón de "Intercambiar Origen/Destino" y llama a `appLogic.intercambiarOrigenYDestino()`. La Lógica ejecuta la acción, actualiza los campos de origen/destino en `AppUiState` y notifica a la UI. La UI simplemente vuelve a renderizar mostrando los campos actualizados.
- La UI detecta un tap en el botón de "Buscar Ruta" y llama a `appLogic.iniciarBusquedaDeRutas()`. Antes de esto, la UI podría actualizar su estado visual (`panelDeBusquedaExpandido` en `AppUiState`) para colapsar el panel. La Lógica inicia el cálculo, actualiza `estadoCalculoRuta` a `CARGANDO` en `AppUiState`. Cuando la Lógica finaliza, actualiza `estadoCalculoRuta` a `EXITO` (o `ERROR`) y llena (`datosFaseOpcionesRuta`) en `AppUiState`. La UI, observando estos cambios en `AppUiState`, muestra el spinner o los resultados, y puede que su layout cambie (ej: muestra la lista de opciones de ruta y colapsa el panel de búsqueda si no lo hizo antes).

---

# Otras notas random

es importante mencionar que se trata de una adaptacion del proyecto viejo, osea es importante entender que el proyecto estaba bonito y estaba haciendo un buen intento de UX, pero se complico porque tenia mezclada demasiada logica de negocio y ui, era muy dificil de mantener porque cada cambio en la logica podria transformarse en miles de tipos de bug diferentes, ahora tenemos este contrato unico de comunicacion entre la capa de logica y la capa puramente presentacional

esto significa que siempre para cada ticket es importante hacer referencias al codigo viejo, si podemos copiar los widget visualmente mejor, solo es trabajo de limpiar el state y adaptarlos a la nueva arquitectura de ui puramente presentacional que solo se dedica a emitir ciertos eventos a la capa de logica y se ocupa solo de presentar el state de la app, priorizando al maximo la alineacion con los flujos de usuario

tambien es importante que nunca olvides y siempre tengas cuenta una cosa: todos los "problemas" de "como" implementar algo ya estan resueltos, en ningun momento debes intentar resolver problemas de este tipo porque en realidad todo esto ya lo resolvimos en el proyecto viejo, que quede claro esto, el unico objetivo del refactor es adaptar todo a esta nueva arquitectura, el proyecto viejo fue mas que nada como prueba de concepto donde estuvimos explorando muchas cosas a ver si serian posibles y ver como queriamos hacer la ui, y ya ahi se logro algo, lo que quiero que entiendas y lo que quiero que te lleves como idea principal es que cosas de implementacion como mapbox, las comunicaciones con apis, archivos geojson, procesamiento de datos, y todas estas cositas ya fueron probadas en el proyecto viejo y ya dimos con maneras para lograr todas estas cosas

asi que siempre que tengas un problema de que no sabes como usar una api o algo debes simplemente redirigirte al proyecto viejo, recuerda que estamos haciendo una adaptacion con el principal objetivo de separar una capa de logica con una capa de ui firme minimalista y presentacional y clean para facilitar el mantenimiento

recuerda, no debes complicarte, ve directo al grano lee el codigo viejo hasta tener todo lo que necesitas no solo 300 lineas

y otra cosa, cuando estes pensando agregar cualquier cosa a la capa de logica o ui, siempre debes pensar en conceptos, el concepto que estas metiendo que es? por lo que dijiste quieres hacer que la capa de logica mantenga el concepto de indice de tramo seleccionado, ese concepto, "tramo seleccionado" que crees que es? con que tiene que ver? con procesamiento de informacion o con la app de cara al usuario y los flujos de usuario y las dinamicas de la ui? creo que esta bastante claro no?

de ahora en adelante quiero que siempre que te encuentres un problema de api o algo simplemente investigues como se lograba en el codigo viejo como primer paso SIEMPRE, no tienes permitido siquiera comenzar a pensar soluciones e indagar sin primero consultar el ánalogo del codigo viejo, MÍNIMO debes tener siempre el ánalogo del codigo viejo en contexto, recuerda que este es un proyecto de ADAPTACIÓN a la nueva arquitectura, NUNCA debes iniciar investigaciones ni desperdiciar tokens ni hacer busquedas en internet sin primero consultar como se solucionó el problema en el código viejo, por ejemplo todo lo que necesitamos hacer con mapbox ya se hizo en el código viejo y de hecho con la misma versión porque estamos compartiendo el pubspec.yaml
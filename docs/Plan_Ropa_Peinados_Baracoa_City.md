# Baracoa City — Plan de implementación de ropa y peinados intercambiables

## Objetivo

Implementar un sistema de personalización visual para el personaje existente de **Baracoa City**, usando PixelLab mediante el MCP ya conectado a OpenCode en Windows.

**Prioridad absoluta:** conservar el personaje, las animaciones y el sistema de combate. La personalización debe ser una capa de presentación, no debe cambiar la lógica del juego.

## Presupuesto estricto de PixelLab: 40 generaciones al mes

El usuario indica que dispone de **40 generaciones mensuales**. Trátalas como un límite estricto.

- No generes imágenes hasta terminar la auditoría, proponer el plan y obtener autorización explícita.
- No gastes generaciones en pruebas exploratorias, candidatos innecesarios ni regeneraciones evitables.
- Antes de cada operación potencialmente costosa, explica qué se generará, por qué, el coste conocido y el saldo estimado.
- Consulta el saldo/coste con las herramientas disponibles cuando sea posible. No supongas que cada herramienta cuesta una generación ni inventes costes.
- Si el coste o el saldo disponible es desconocido, detente y pide autorización antes de generar.
- Registra cada operación en `docs/personalizacion/PIXELLAB_GENERATION_LOG.md`: fecha, herramienta, motivo, coste reportado, resultado y saldo estimado. Si no se conoce el coste, escribe “desconocido”.
- No superes el presupuesto mensual. La cifra de 40 procede del usuario; comprueba el saldo real de la cuenta antes de utilizar las herramientas.

## Fase 0 — Auditoría sin generar imágenes

Esta fase no debe consumir generaciones.

1. Inspecciona la estructura real del proyecto y la versión de Godot.
2. Localiza la escena del jugador, el controlador visual, los sprites y el flujo de animación.
3. Identifica cómo se controlan la animación, dirección, fotograma, velocidad, textura y punto de anclaje.
4. Localiza el código de combate: ataques, hitboxes/hurtboxes, daño, movimiento, reacciones a impactos y señales. Anota los archivos que no deben modificarse.
5. Comprueba el tamaño real de las celdas, márgenes, separaciones, paleta, filtrado, transparencia y convención de nombres.
6. Verifica cuántas direcciones y qué animaciones existen realmente; no asumas que hay ocho direcciones.
7. Inspecciona las herramientas MCP de PixelLab disponibles y consulta la documentación actual de esas herramientas.
8. Ejecuta o revisa las pruebas existentes sin modificar archivos y registra resultados.
9. Entrega un breve informe de compatibilidad antes de generar recursos.

No asumas que las rutas, dimensiones o nombres mencionados en conversaciones anteriores siguen siendo correctos: verifica los archivos reales.

## Fase 1 — Elegir la estrategia gráfica

Después de la auditoría, selecciona la estrategia más fiable:

- **Capas independientes:** si cada prenda y peinado puede alinearse con todos los fotogramas y direcciones.
- **Variantes completas de sprites:** si la pose, la oclusión o la dirección impiden usar capas limpias.
- **Sistema híbrido:** capas para los recursos compatibles y variantes específicas donde sean necesarias.

No uses una única imagen estática para cubrir todas las poses. No recortes automáticamente un personaje completo para convertirlo en una prenda si eso deja píxeles duplicados, huecos o bordes defectuosos.

## Fase 2 — Especificación de arte

Usa los sprites originales del personaje como referencia principal. Los recursos nuevos deben coincidir con:

- tamaño de píxel, proporciones y silueta;
- paleta, contornos, sombreado y nivel de detalle;
- orientación y perspectiva;
- posición de cabeza, cuello, hombros, torso, cintura y pies;
- punto de anclaje y cuadrícula;
- transparencia real;
- coherencia entre todas las direcciones y fotogramas.

### Primera prueba: solo una camiseta y un peinado

Genera únicamente:
- una camiseta intercambiable;
- un peinado intercambiable;
- los fotogramas y direcciones mínimos necesarios para validar la técnica.

No generes el catálogo completo antes de aprobar la prueba. Cuando sea viable, reutiliza píxeles, paletas, máscaras o herramientas de edición para evitar generar variantes duplicadas. No sacrifiques la calidad visual para ahorrar: explica el coste y pide autorización.

### Reglas para los recursos

- Guarda los archivos nuevos en una carpeta independiente, por ejemplo `assets/characters/customization/`, adaptada a la estructura real.
- Nunca sobrescribas, renombres, muevas ni elimines los sprites originales.
- Conserva las dimensiones, cuadrícula, formato y transparencia requeridos.
- Si la herramienta devuelve varios candidatos, inspecciona los resultados y elige uno; no solicites candidatos adicionales sin autorización.
- No declares compatibles animaciones que no se hayan generado o validado.
- Si PixelLab no puede producir una capa fiable, detente y explica la alternativa necesaria.

## Fase 3 — Arquitectura del sistema

Implementa un sistema pequeño y extensible, separado de la lógica de combate. Adapta nombres y rutas al estilo real del proyecto y evita duplicar sistemas existentes.

### Componentes sugeridos

- **Catálogo de personalización:** identificadores de prendas y peinados, recursos y compatibilidad.
- **Estado visual:** guarda las opciones equipadas, por ejemplo `shirt_id` y `hairstyle_id`.
- **Presentación:** dibuja las capas en el orden correcto y sincronizadas con la animación original.
- **Interfaz de selección:** solo si existe una interfaz adecuada o el usuario aprueba añadirla. Primero valida el sistema visual sin construir una interfaz compleja.

### Sincronización obligatoria

No uses relojes de animación independientes. Las capas deben compartir el estado visual autoritativo del personaje:

- animación actual;
- dirección actual;
- índice de fotograma;
- velocidad/tiempo del fotograma;
- visibilidad y transformaciones pertinentes.

Si el proyecto usa un controlador visual personalizado, intégrate con él. No añadas un `AnimatedSprite2D` con temporización independiente si puede desincronizar la ropa o el pelo.

### Orden de dibujo y oclusión

- El pelo debe poder aparecer delante o detrás de la cabeza según la dirección.
- La ropa debe cubrir el torso sin tapar indebidamente brazos, manos, armas o efectos.
- Las partes que deban estar detrás del cuerpo deben dibujarse detrás.
- La personalización no debe tapar efectos de combate ni elementos de interfaz.
- Divide prendas en subcapas delante/detrás solo cuando sea necesario y compatible con el arte.

## Fase 4 — Protección del combate

No modifiques, salvo autorización separada y justificación documentada:

- lógica de ataque;
- cálculo de daño;
- hitboxes/hurtboxes y sensores;
- temporización y ventanas de impacto;
- movimiento, aceleración y empuje;
- reacción a impactos, invulnerabilidad o aturdimiento;
- señales/eventos de combate;
- recursos de animación utilizados por la lógica del combate.

La personalización solo debe cambiar los gráficos mostrados. No alteres colisiones, áreas, nodos de combate ni tiempos para adaptar la ropa.

Antes de cambiar cualquier script compartido entre presentación y combate, explica el motivo, el cambio mínimo y el riesgo, y espera aprobación.

No afirmes que el combate está intacto solo porque el juego abre. Compara los cambios y ejecuta las pruebas disponibles.

## Fase 5 — Validación de la prueba

Después de integrar la camiseta y el peinado:

1. Comprueba que Godot no reporte errores de recursos, importación o GDScript.
2. Revisa todas las direcciones disponibles.
3. Revisa reposo, caminar, atacar, recibir daño y las demás animaciones reales del proyecto.
4. Comprueba varios fotogramas de cada animación, no solo el primero.
5. Busca desfases, parpadeo, bordes opacos, píxeles flotantes y cambios inesperados de escala.
6. Comprueba la oclusión cuando el personaje mira hacia delante y hacia atrás.
7. Ejecuta las pruebas de combate existentes antes y después y compara resultados.
8. Verifica que cambiar de ropa o peinado no desincronice la animación.
9. Registra qué se probó y qué no pudo verificarse.

Si una prueba falla, corrige solo el sistema visual. No modifiques el combate para resolver un problema gráfico.

## Fase 6 — Ampliar el catálogo

Solo después de aprobar la prueba y recibir autorización:
- añade más prendas y peinados;
- añade colores reutilizando paletas o máscaras cuando sea viable;
- añade accesorios únicamente si no complican la alineación y oclusión;
- actualiza catálogo y documentación.

Antes de cada lote, informa del coste conocido y el presupuesto restante estimado. Prioriza recursos que cubran muchas animaciones y direcciones; evita duplicados.

## Entregables

1. Recursos nuevos en una carpeta independiente.
2. Código mínimo de personalización y lista de archivos modificados.
3. `docs/personalizacion/PIXELLAB_GENERATION_LOG.md`.
4. `docs/personalizacion/README.md`, con instrucciones para añadir prendas y peinados.
5. Informe de pruebas: resultados, pruebas no ejecutadas y limitaciones.
6. Capturas o demostración visual de la prueba, si es posible.
7. Confirmación de si los archivos de combate quedaron sin cambios, respaldada por comparación del diff.

## Protocolo obligatorio de OpenCode

Trabaja por fases y presenta un plan antes de cambiar archivos. No hagas cambios masivos.

Detente y pide autorización antes de:
- consumir la primera generación de PixelLab;
- usar una herramienta cuyo coste sea desconocido;
- generar más recursos de los autorizados;
- modificar archivos de combate o archivos compartidos con su lógica;
- sobrescribir o eliminar archivos;
- ampliar la prueba mínima a un catálogo completo.

Si no se ha aprobado el gasto de generaciones, puedes completar la auditoría, proponer la arquitectura y documentar los recursos necesarios, pero no iniciar la generación.

## Criterio de éxito

El jugador puede cambiar camiseta y peinado; las capas están alineadas en todas las direcciones y animaciones cubiertas; el combate se comporta igual; las pruebas existentes siguen pasando; y el presupuesto mensual de PixelLab se respeta estrictamente.

# Roadmap

Orden de trabajo derivado de `VIDEOJUEGO_MUNDO_ABIERTO_ESPECIFICACION.md`.
Cada fase debe dejar el proyecto ejecutable antes de pasar a la siguiente.

## Estados

```text
PLANNING -> FOUNDATION -> MVP_OFFLINE -> MULTIPLAYER_PROTOTYPE
         -> PERSISTENCE -> WORLD_EXPANSION -> LIFE_SYSTEMS -> MUNICIPALITY
```

Estado actual: **MVP_OFFLINE**, en curso.

## Fase 0 — Preparación ✅

- [x] Estructura de carpetas por capas.
- [x] `project.godot` con resolución, acciones de entrada y capas de física.
- [x] `GameConfig` y `GameLogger`.
- [x] Documentación de arquitectura, gameplay, networking y roadmap.
- [x] Bus de eventos de dominio.

## Fase 1 — Prototipo offline 🚧

Base terminada:

- [x] Mapa de prueba con terreno, caminos, árboles, piedras, casas y colisiones.
- [x] Límites de zona y cámara que los respeta.
- [x] Jugador provisional con movimiento, orientación y colisiones.
- [x] Dominio de vida, daño, muerte y reaparición.
- [x] Máquina de estados con transiciones validadas.
- [x] Sprites del pack (Ninja Adventure, Pixel-boy, CC0): jugador y cuatro tipos
      de enemigo, con ciclo de paso en cuatro orientaciones y pose de golpe.
- [x] Combate cuerpo a cuerpo: rango, cooldown, daño, objetivo e invulnerabilidad.
- [x] Armas: piedra y cuchillo, con durabilidad y desgaste.
- [x] Combate sin arma: puños siempre disponibles, con reglas propias y sin
      des-equipar lo que se lleva en la mano.
- [x] Enemigos: seis en la zona, con IA de reposo, deambular, perseguir, atacar,
      huir y morir; solo uno persigue a la vez.
- [x] El enemigo devuelve el golpe: daño, cooldown, invulnerabilidad y stun.
- [x] HUD de barras e icono de arma, sin texto (la fuente del sistema sale
      borrosa a 384x216).
- [x] Muerte y reaparición jugables, con tinte de pantalla y botón de revivir.
- [x] Tests unitarios headless del dominio, del combate, de los enemigos, de los
      sprites y de la integridad de scripts (111 pruebas).
- [x] Tests de integración con física real: colisiones y sincronía
      dominio/vista (6 pruebas).
- [x] Tests de integración de combate con la hitbox real (11 pruebas).
- [x] Tests de integración de enemigos: IA, golpe de ida y vuelta, muerte y
      reaparición (18 pruebas).

Pendiente:

- [ ] Inventario con capacidad y equipar.
- [ ] Objetos genéricos con tipo y apilado.
- [ ] Barra de golpe en el HUD.
- [ ] Feedback visual cuando el enemigo golpea: hoy no sale arco ni destello.

## Fase 2 — Multijugador

- [ ] Servidor dedicado y cliente con la misma escena.
- [ ] Conexión y desconexión.
- [ ] Dos jugadores visibles con movimiento sincronizado.
- [ ] RPC de intención; validación en servidor.
- [ ] Snapshots y suavizado.
- [ ] Tests en `tests/multiplayer/`.

Diseño aprobado y detallado en `docs/networking/NETWORKING.md`.

## Fase 3 — Persistencia

- [ ] Interfaz de repositorio.
- [ ] Implementación local en JSON (primera) y SQLite (después).
- [ ] Cuentas y personajes.
- [ ] Guardado de posición, inventario y estadísticas.

## Fase 4 — Mundo ampliado

- [ ] Múltiples zonas con carga y descarga.
- [ ] Cambio de zona con validación en servidor.
- [ ] Edificios con interiores sencillos.
- [ ] Más NPC y objetos repartidos por el mapa.

## Fase 5 — Sistemas de vida

- [ ] Dinero y comercio.
- [ ] Hambre, sed y energía.
- [ ] Propiedades y trabajo.

## Fase 6 — Municipio

Conversión progresiva del municipio real:

```text
Mapa real -> división por zonas -> calles -> edificios -> puntos de interés
```

## Regla de avance

No marcar una fase como completada hasta verificarla ejecutando el juego y los
tests. Antes de implementar una funcionalidad nueva, responder las diez
preguntas de la sección 32 de la especificación.
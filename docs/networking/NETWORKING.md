# Networking

Estado: **no implementado**. Este documento fija el diseño antes de escribir
código, para que la Fase 2 no obligue a reescribir el juego.

## 1. Principio

Arquitectura **server-authoritative**:

> El cliente solicita acciones; el servidor valida y decide el estado real.

```text
CLIENTE                        SERVIDOR
"quiero moverme a (x, y)"  ->  ¿existe el jugador?
                                ¿está vivo?
                                ¿la acción es válida?
                                ¿hay colisión?
                            ->  simula y decide la posición final
CLIENTES                   <-  reciben el estado nuevo
```

## 2. Qué NO se confía al cliente

| dato | quién lo decide |
| --- | --- |
| daño | servidor |
| vida | servidor |
| inventario | servidor |
| dinero | servidor |
| posición final | servidor |
| resultado del combate | servidor |
| permisos | servidor |

El cliente puede mentir sobre sus *intenciones* (qué tecla pulsó, a dónde apunta).
Nunca sobre los *resultados*.

## 3. Validación mínima de una acción

Para que el servidor acepte un ataque debe responder sí a todo:

1. ¿el jugador existe?
2. ¿está vivo?
3. ¿tiene arma equipada?
4. ¿el cooldown terminó?
5. ¿está dentro del rango de ataque?
6. ¿el objetivo es válido y está vivo?

Si algo falla, la acción se rechaza y el cliente recibe el estado real, no el
que pidió.

## 4. Qué sincronizar

En la Fase 2, y solo lo que cambia:

| dato | frecuencia |
| --- | --- |
| posición | cada snapshot (10-20 Hz), interpolada en cliente |
| dirección | junto con la posición |
| estado | al cambiar |
| vida | al cambiar |

No enviar inventarios completos ni estadísticas en cada paquete: son datos
raros que viajan por evento, no por snapshot.

## 5. Roles de escena

```text
Servidor   -> escena dedicated con la zona y las colisiones
Cliente    -> escena con vista y predicción local
```

Ambos ejecutan el mismo `scenes/world/main.tscn`. La diferencia se decide con
argumentos de línea de comandos, no con dos escenas distintas: menos superficie
que mantener, y las mismas reglas se ejecutan en ambos lados.

```bash
godot --server                      # servidor dedicado
godot -- --connect 127.0.0.1:27015  # cliente
```

## 6. Preparación ya hecha en el código

La Fase 1 dejó las fronteras listas para que la Fase 2 no toque lo existente:

- **`GameSession`** ya es el dueño del `Player`. El servidor crea uno por
  conexión y el cliente recibe una copia.
- **`MovementController.move()`** es el único punto donde se decide la posición.
  Hoy aplica el movimiento local; mañana aplicará la posición del servidor sin
  que `PlayerView` se entere.
- **`MainWorldView.move_player_to()`** existe como punto de extensión para el
  cambio de zona validado.
- **`CollisionLayers.HITBOX`** ya está reservada para las áreas de ataque.
- **La lógica de red vivirá en `scripts/infrastructure/networking/`**, que aún
  está vacía a propósito. Nada de red se importa en dominio ni en presentación.

## 7. Lo que queda para la Fase 2

- [ ] `NetServer` / `NetClient` sobre `ENetMultiplayerPeer`.
- [ ] Réplica de jugadores: instanciar y destruir vistas al conectar y desconectar.
- [ ] RPC de intención de movimiento y de ataque.
- [ ] Snapshot de estado y suavizado en cliente.
- [ ] Pruebas de `tests/multiplayer/`: conexión, desconexión, dos jugadores,
      sincronización y rechazo de acciones inválidas.

## 8. prediction y reconciliación

Quedan explícitamente **fuera** del MVP, pero el diseño las admite: el cliente
ya aplica el movimiento por su cuenta y la posición del servidor llega como
`move_player_to()`, así que añadir predicción y reconciliación es un
paso, no una reescritura. Cuando toque, documentar aquí la decisión tomada.
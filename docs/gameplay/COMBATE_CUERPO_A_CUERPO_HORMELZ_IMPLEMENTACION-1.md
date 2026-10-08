# IMPLEMENTACIÓN COMPLETA --- COMBATE CUERPO A CUERPO + ANIMACIONES

## 0. Objetivo

Implementar en el proyecto Godot existente un sistema de combate cuerpo
a cuerpo **completo, jugable y visualmente convincente**, usando como
personaje principal el pack:

**Free 8-Directional Melee Character --- Hormelz**

Página oficial: https://hormelz.itch.io/8-directional-melee-character

El asset es gratuito, CC0, tiene 38 animaciones y 8 direcciones. La
página del autor indica que las direcciones cardinales pueden utilizarse
como un personaje top-down de 4 direcciones.

El resultado obligatorio de esta tarea es que, al ejecutar el juego, el
jugador pueda:

-   moverse;
-   orientarse;
-   atacar;
-   encadenar ataques;
-   golpear un objetivo;
-   provocar daño;
-   provocar reacción;
-   producir knockback/stagger;
-   consumir stamina;
-   esquivar/rodar;
-   morir;
-   matar un enemigo de prueba;
-   ver animaciones sincronizadas con la lógica;
-   recibir feedback visual de los impactos.

No crear un simple botón que reproduzca una animación. Implementar el
sistema real.

------------------------------------------------------------------------

# 1. REGLA ABSOLUTA: INSPECCIONAR ANTES DE MODIFICAR

Antes de cambiar código:

1.  Inspeccionar todo el repositorio.
2.  Verificar versión real de Godot.
3.  Revisar `project.godot`.
4.  Ejecutar el proyecto si es posible.
5.  Identificar `ActorSprite`.
6.  Identificar `PlayerView`.
7.  Identificar `ActorVisualCatalog`.
8.  Identificar `melee_combat.gd` o equivalente.
9.  Identificar salud/daño.
10. Identificar stamina.
11. Identificar hitboxes/hurtboxes.
12. Identificar armas.
13. Identificar cámara.
14. Identificar efectos de ataque.
15. Identificar tests.
16. Localizar todas las referencias a `ninja_blue.png`.
17. Localizar todas las referencias a `slash.png`.
18. Revisar documentación existente.

No asumir que una funcionalidad no existe sin comprobarlo.

No reescribir todo el proyecto.

No borrar sistemas funcionales innecesariamente.

------------------------------------------------------------------------

# 2. ASSET OBLIGATORIO

Utilizar el pack de Hormelz.

La página oficial declara:

-   38 animaciones;
-   8 direcciones;
-   pixel art;
-   top-down;
-   CC0;
-   archivos con sufijo `_dir#`;
-   canvas indicado de 126×132 en la página;
-   descarga `MeleeCharacter.zip`.

Animaciones declaradas por el autor, entre otras:

-   Combo
-   Battlecry
-   Die 1
-   Die 2
-   Elbow Punch
-   Ready Idle
-   Fireball
-   Flying Kick
-   Forward Roll
-   Standing Roll
-   Front Kick 1
-   Front Kick 2
-   High Kick
-   Hit Body
-   Hit Head
-   Hit Light
-   Standing Idle
-   Jump
-   Strafe Walk
-   Strafe Run
-   Right Hook
-   Left Hook
-   Right Jab
-   Left Jab
-   Pull
-   Push
-   Run
-   Walk Backward
-   Running Jump
-   Slide
-   Side Kick
-   Stomp Kick
-   Straight Right
-   Walk Forward

**IMPORTANTE:** no asumir nombres internos, número de frames, FPS,
offsets ni distribución de spritesheets. Inspeccionar los archivos
descargados y construir el mapping real.

------------------------------------------------------------------------

# 3. DIRECCIONES

El asset documenta:

``` text
dir1 = Down Left
dir2 = Left
dir3 = Up Left
dir4 = Up
dir5 = Up Right
dir6 = Right
dir7 = Down Right
dir8 = Down
```

El proyecto puede continuar usando 4 direcciones inicialmente:

``` text
UP    = dir4
DOWN  = dir8
LEFT  = dir2
RIGHT = dir6
```

La arquitectura debe soportar 8 direcciones, pero no convertir
obligatoriamente todo el movimiento existente a 8 direcciones si eso
rompe el proyecto.

------------------------------------------------------------------------

# 4. MIGRACIÓN DEL NINJA

El personaje humano de Hormelz pasa a ser el visual por defecto.

Mantener temporalmente el ninja como fallback/legacy.

No eliminarlo hasta comprobar que ninguna prueba o sistema lo necesita.

La lógica de juego NO debe depender de una textura concreta.

Prohibido:

``` gdscript
if texture == ninja_blue:
    damage = 10
```

El combate debe funcionar independientemente del personaje visual.

------------------------------------------------------------------------

# 5. ARQUITECTURA

Mantener la separación:

``` text
Presentation
      ↓
Application
      ↓
Domain
      ↓
Infrastructure
```

El combate debe separar:

``` text
Combat Logic
     +
Visual Animation
     +
Effects
```

Arquitectura objetivo:

``` text
INPUT
  ↓
CombatController
  ↓
CombatSystem
  ↓
AttackDefinition
  ↓
CombatState
  ↓
Combat Events
  ├── Animation
  ├── Hitbox
  ├── Damage
  ├── Stagger
  ├── Knockback
  ├── Hit Reaction
  ├── Hit Stop
  ├── Camera Shake
  ├── VFX
  └── Audio
```

El sprite nunca es la fuente de verdad del daño.

------------------------------------------------------------------------

# 6. CHARACTER VISUAL DEFINITION

Crear o adaptar una abstracción equivalente a:

``` text
CharacterVisualDefinition
```

Debe poder describir:

``` text
visual_id
animation resources
frame size
direction mapping
animation mapping
speed
scale
offset
pivot
weapon anchor
hand position
```

El nombre exacto puede adaptarse a la arquitectura existente.

Objetivo:

``` text
Player
  ↓
Visual Definition
  ↓
Hormelz Human
```

En el futuro:

``` text
NPC
  ↓
Visual Definition
  ↓
otro humano
```

sin modificar CombatSystem.

------------------------------------------------------------------------

# 7. ESTADOS DE COMBATE

Implementar como mínimo:

``` text
FREE
WINDUP
ACTIVE
RECOVERY
HIT_REACTION
STAGGERED
DODGING
BLOCKING
DEAD
```

Opcionales:

``` text
COMBO_WINDOW
KNOCKED_DOWN
GETTING_UP
INTERRUPTED
```

Reglas:

-   DEAD no puede atacar.
-   DEAD no puede bloquear.
-   DEAD no puede iniciar dodge.
-   STAGGERED limita acciones.
-   RECOVERY limita acciones según AttackDefinition.
-   ACTIVE controla la ventana de impacto.

------------------------------------------------------------------------

# 8. ATTACK DEFINITION

Los ataques deben ser data-driven.

Usar `Resource`, clase de datos o equivalente.

Campos recomendados:

``` text
id
display_name
animation_id
startup_time
active_time
recovery_time
damage
stamina_cost
range
angle
hitbox_shape
hitbox_offset
knockback
stagger
hit_reaction
hit_stop
camera_shake
impact_effect
movement_multiplier
combo_next
combo_window
can_cancel
priority
```

No colocar todos los valores dentro de un único script gigante.

------------------------------------------------------------------------

# 9. ATAQUES MÍNIMOS

Implementar:

``` text
LEFT_JAB
RIGHT_JAB

LEFT_HOOK
RIGHT_HOOK

STRAIGHT_RIGHT
ELBOW_PUNCH

FRONT_KICK_1
FRONT_KICK_2
HIGH_KICK
SIDE_KICK
STOMP_KICK

COMBO
```

Cada ataque debe utilizar su animación real del pack cuando exista.

El mapping debe comprobarse después de inspeccionar los archivos.

------------------------------------------------------------------------

# 10. FASES DE CADA ATAQUE

Todo ataque debe seguir:

``` text
WINDUP
   ↓
ACTIVE
   ↓
RECOVERY
```

Conceptualmente:

``` text
WINDUP
  preparación

ACTIVE
  hitbox activa

IMPACT
  resolución si conecta

RECOVERY
  recuperación

FREE / COMBO
```

Los tiempos deben calibrarse con los frames reales del asset.

No inventar timings definitivos antes de inspeccionar las animaciones.

------------------------------------------------------------------------

# 11. ANIMATION EVENTS

La animación y el combate deben sincronizarse mediante eventos
explícitos.

Eventos mínimos:

``` text
ATTACK_STARTED
WINDUP_COMPLETE
HITBOX_ON
IMPACT_WINDOW
HITBOX_OFF
RECOVERY_STARTED
ATTACK_FINISHED
```

Preferir:

-   AnimationPlayer + Call Method Track;
-   Animation events;
-   timestamps;
-   o solución equivalente compatible con la arquitectura.

No usar simplemente:

``` gdscript
await animation.finished
damage()
```

para determinar el impacto.

El impacto debe ocurrir en el frame correcto.

------------------------------------------------------------------------

# 12. CALIBRACIÓN POR FRAME

Para cada ataque crear una tabla:

  -----------------------------------------------------------------------------------
  Ataque     Animación      Frames       FPS   Startup    Active   Recovery Hit frame
  ---------- ----------- --------- --------- --------- --------- ---------- ---------
  Jab L      verificar           ?         ?         ?         ?          ?         ?

  Jab R      verificar           ?         ?         ?         ?          ?         ?

  Hook L     verificar           ?         ?         ?         ?          ?         ?

  Hook R     verificar           ?         ?         ?         ?          ?         ?

  Straight   verificar           ?         ?         ?         ?          ?         ?

  Elbow      verificar           ?         ?         ?         ?          ?         ?

  Front Kick verificar           ?         ?         ?         ?          ?         ?

  High Kick  verificar           ?         ?         ?         ?          ?         ?

  Side Kick  verificar           ?         ?         ?         ?          ?         ?

  Stomp      verificar           ?         ?         ?         ?          ?         ?
  -----------------------------------------------------------------------------------

NO rellenar `?` inventando datos.

Determinar los valores mediante inspección y prueba.

------------------------------------------------------------------------

# 13. INPUT

Revisar primero el InputMap existente.

No romper controles actuales.

Si faltan acciones, implementar una configuración cómoda.

Propuesta:

``` text
WASD / Flechas = movimiento
Mouse izquierdo / J = ataque principal
K = ataque secundario
L = patada
Shift = dodge/roll
Space = block, si se implementa
```

Los controles finales pueden adaptarse a los existentes.

------------------------------------------------------------------------

# 14. MOVIMIENTO

El personaje debe poder moverse normalmente.

Durante combate:

``` text
WINDUP → movimiento limitado
ACTIVE → movimiento muy limitado
RECOVERY → movimiento parcialmente limitado
```

Añadir por ataque:

``` text
movement_multiplier
```

Ejemplo inicial:

``` text
Jab       0.65
Hook      0.55
Kick      0.45
Heavy     0.25
```

Son valores de calibración, no definitivos.

------------------------------------------------------------------------

# 15. DIRECCIÓN DEL ATAQUE

La dirección visual y la dirección lógica deben coincidir.

Ejemplo:

``` text
PLAYER → RIGHT

Attack
   ↓
Hitbox
   →
Target
```

Si mira LEFT:

``` text
Target
   ←
Hitbox
   ←
PLAYER
```

No permitir que la animación ataque hacia un lado mientras la hitbox
golpea hacia otro.

------------------------------------------------------------------------

# 16. HITBOX / HURTBOX

Separar:

``` text
Hurtbox
```

y:

``` text
AttackHitbox
```

El AttackHitbox:

-   está apagado normalmente;
-   se activa durante ACTIVE;
-   se desactiva al terminar;
-   sigue la orientación;
-   usa el alcance del ataque.

No utilizar el tamaño del sprite como hitbox.

------------------------------------------------------------------------

# 17. HIT DETECTION

Un objetivo válido debe cumplir:

``` text
not self
not dead
inside range
inside attack angle
inside attack shape
valid faction/team
```

No golpear objetivos detrás solo porque están cerca.

------------------------------------------------------------------------

# 18. MULTI-HIT CONTROL

Un ataque no puede dañar al mismo objetivo cada frame.

Mantener:

``` text
hit_targets_this_attack
```

Flujo:

``` text
Attack starts
 ↓
clear set
 ↓
target hit
 ↓
add target
 ↓
target cannot be hit again
 ↓
attack ends
 ↓
clear
```

Permitir multi-hit únicamente cuando un ataque lo defina explícitamente.

------------------------------------------------------------------------

# 19. RESULTADOS DE COMBATE

Definir:

``` text
MISS
HIT
BLOCKED
DODGED
INTERRUPTED
```

Un HIT puede producir:

``` text
damage
stagger
knockback
reaction
VFX
hit-stop
camera shake
audio
```

No todos los ataques necesitan exactamente los mismos efectos.

------------------------------------------------------------------------

# 20. STAMINA

Si ya existe stamina, integrarla.

Si no existe, implementar una versión mínima.

Valores iniciales orientativos:

``` text
Jab: 4–5
Hook: 7–8
Straight: 8
Elbow: 10
Kick: 10–15
Heavy: 15+
```

Centralizar valores.

Si no hay stamina suficiente:

``` text
attack rejected
```

No reproducir una animación completa de ataque rechazado.

------------------------------------------------------------------------

# 21. RECOVERY

El jugador no debe poder spamear ataques sin consecuencias.

Flujo:

``` text
ATTACK
 ↓
RECOVERY
 ↓
FREE
```

Cada ataque puede tener una duración de recovery diferente.

Los ataques fuertes deben comprometer más al jugador.

------------------------------------------------------------------------

# 22. INPUT BUFFER

Implementar buffer corto:

``` text
80–150 ms
```

Si el jugador pulsa ataque durante el final del recovery:

``` text
guardar input
 ↓
si combo válido
 ↓
ejecutar siguiente
```

Separar:

``` text
input buffer
```

de:

``` text
combo window
```

------------------------------------------------------------------------

# 23. COMBOS

Implementar combo data-driven.

Ejemplo:

``` text
JAB
 ↓
JAB
 ↓
HOOK
```

El sistema debe saber:

``` text
current attack
combo window
next valid attacks
```

Si el jugador no continúa a tiempo:

``` text
combo reset
```

No hacer combos infinitos.

------------------------------------------------------------------------

# 24. CANCEL WINDOWS

Cada ataque puede declarar:

``` text
can_cancel
```

o capacidades específicas:

``` text
combo_cancel
dodge_cancel
hit_confirm_cancel
```

No permitir cancelación arbitraria.

------------------------------------------------------------------------

# 25. HIT REACTION

El asset proporciona:

``` text
Hit Light
Hit Body
Hit Head
```

Mapear según corresponda.

Propuesta:

``` text
LIGHT → Hit Light
BODY  → Hit Body
HEAD  → Hit Head
HEAVY → Hit Body/Head + stagger mayor
```

Verificar visualmente que el mapping sea correcto.

Para otros personajes utilizar:

``` text
HitReactionType
```

en lugar de depender de nombres concretos.

------------------------------------------------------------------------

# 26. STAGGER

Implementar:

``` text
STAGGERED
```

Durante stagger:

-   limitar movimiento;
-   impedir ataques incompatibles;
-   reproducir reacción;
-   aplicar duración;
-   volver a estado válido.

El tiempo depende de la fuerza del ataque.

------------------------------------------------------------------------

# 27. KNOCKBACK

Calcular:

``` text
impact_direction
×
knockback_force
```

Respetar colisiones.

No teletransportar objetivos a través de paredes.

Los ataques deben tener distintos niveles:

``` text
low
medium
high
```

------------------------------------------------------------------------

# 28. DAÑO

Separar:

``` text
AttackDefinition.damage
```

de:

``` text
Health
```

Inicialmente puede ser:

``` text
final_damage = base_damage
```

pero preparar para:

``` text
stats
weapon
armor
critical
defense
```

No implementar sistemas complejos que todavía no existan.

------------------------------------------------------------------------

# 29. ATAQUES INICIALES

Valores orientativos únicamente:

``` text
LEFT_JAB
damage = 6
stamina = 4
knockback = low
stagger = low

RIGHT_JAB
damage = 6
stamina = 4

LEFT_HOOK
damage = 9
stamina = 7
knockback = medium

RIGHT_HOOK
damage = 9
stamina = 7

STRAIGHT_RIGHT
damage = 10
stamina = 8
knockback = medium

ELBOW
damage = 12
stamina = 10
stagger = high
range = short

FRONT_KICK
damage = 11
stamina = 10
range = medium

HIGH_KICK
damage = 15
stamina = 14
stagger = high

SIDE_KICK
damage = 14
stamina = 13
knockback = high

STOMP_KICK
damage = 16
stamina = 15
stagger = high
```

Calibrar después de probar.

------------------------------------------------------------------------

# 30. DODGE / ROLL

Utilizar:

``` text
Forward Roll
Standing Roll
```

si son compatibles después de inspección.

El dodge debe tener:

``` text
startup
invulnerable window
recovery
```

Durante la ventana invulnerable:

``` text
incoming hit → ignored
```

No permitir dodge infinito.

Consumir stamina si el diseño existente lo soporta.

------------------------------------------------------------------------

# 31. BLOCK

No asumir que el pack tiene una animación de bloqueo adecuada.

Primero inspeccionar.

Si no existe:

-   dejar lógica preparada;
-   no fingir una animación inexistente;
-   no sacrificar calidad visual;
-   incorporar posteriormente un asset de block si hace falta.

La ausencia de una animación no debe romper el CombatSystem.

------------------------------------------------------------------------

# 32. MUERTE

Cuando:

``` text
health <= 0
```

hacer:

``` text
combat disabled
 ↓
DEAD
 ↓
Die 1 / Die 2
 ↓
disable normal interaction
```

Seleccionar una animación de muerte real del pack.

No reutilizar Walk como muerte salvo fallback temporal.

------------------------------------------------------------------------

# 33. DUMMY DE COMBATE

Crear un:

``` text
CombatDummy
```

o equivalente.

Debe tener:

``` text
Health
Hurtbox
Visual
Hit Reaction
Stagger
Knockback
Death
```

Debe poder reaparecer para facilitar pruebas.

Opcional:

``` text
respawn = 2 s
```

------------------------------------------------------------------------

# 34. HUD DE DEBUG

Crear modo debug opcional:

``` text
HP
Stamina
State
Current Attack
Animation
Direction
Hitbox
Combo
```

Ejemplo:

``` text
HP: 84/100
STA: 71/100
STATE: ACTIVE
ATTACK: LEFT_HOOK
DIR: RIGHT
HITBOX: ON
COMBO: 2
```

Debe poder desactivarse.

------------------------------------------------------------------------

# 35. DEBUG DE HITBOXES

Agregar:

``` text
SHOW_COMBAT_DEBUG
```

Cuando esté activo:

-   hurtbox visible;
-   hitbox visible;
-   dirección visible;
-   área de ataque visible;
-   objetivo alcanzado visible.

Esto es obligatorio para calibrar el sistema.

------------------------------------------------------------------------

# 36. HIT STOP

Al conectar un golpe:

``` text
impact
 ↓
small freeze
```

Valores iniciales:

``` text
light = 30–45 ms
medium = 45–60 ms
heavy = 60–80 ms
```

Calibrar.

No congelar permanentemente sistemas de red/servidor cuando exista
multiplayer.

------------------------------------------------------------------------

# 37. CAMERA SHAKE

Aplicar únicamente al impacto.

Ejemplo:

``` text
LIGHT  → pequeño
MEDIUM → moderado
HEAVY  → mayor
```

No exagerar.

Debe conservarse la jugabilidad.

------------------------------------------------------------------------

# 38. IMPACT VFX

Crear efectos ligeros:

``` text
impact flash
pixel particles
small burst
directional particles
```

Por ejemplo:

``` text
LIGHT
→ pocas partículas

HEAVY
→ más partículas
→ flash mayor
→ shake mayor
```

Mantener pixel-art.

No utilizar efectos pesados.

------------------------------------------------------------------------

# 39. AUDIO

Preparar eventos:

``` text
attack_start
attack_whoosh
hit_light
hit_medium
hit_heavy
hurt
death
dodge
```

Si no existen sonidos adecuados, usar placeholders o hooks.

No bloquear el sistema por falta de audio.

------------------------------------------------------------------------

# 40. REALISMO VISUAL

No buscar realismo físico científico.

Buscar:

``` text
anticipación
+
contacto
+
reacción
+
peso
+
recuperación
+
feedback
```

Un golpe debe percibirse como:

``` text
PREPARAR
 ↓
GOLPEAR
 ↓
CONTACTO
 ↓
REACCIÓN
 ↓
RECUPERAR
```

------------------------------------------------------------------------

# 41. EFECTO DE PESO

La sensación debe salir de:

``` text
Animation
+
Timing
+
Hitbox
+
Hit Reaction
+
Knockback
+
Hit Stop
+
Camera Shake
+
VFX
+
Audio
```

No intentar producir sensación de fuerza simplemente aumentando daño.

------------------------------------------------------------------------

# 42. EQUIPAMIENTO Y ARMAS FUTURAS

No rehacer el sistema cuando se agreguen:

``` text
knife
stick
stone
```

Preparar:

``` text
WeaponDefinition
```

y:

``` text
AttackDefinition
```

Ejemplo:

``` text
Fist
 ├── Jab
 ├── Hook
 └── Kick

Knife
 ├── Slash
 └── Stab
```

El combate no debe estar atado a los puños.

------------------------------------------------------------------------

# 43. WEAPON ANCHOR

Mantener o crear:

``` text
weapon_anchor
```

para futuras armas.

No implementar todavía un sistema enorme de equipamiento visual.

------------------------------------------------------------------------

# 44. PLAYER VS NPC

El sistema debe ser reutilizable.

No crear:

``` text
PlayerCombatSystem
```

que contenga toda la lógica.

Preferir:

``` text
CombatSystem
     ↑
CombatController
     ↑
Player
```

y posteriormente:

``` text
CombatSystem
     ↑
CombatController
     ↑
NPC
```

------------------------------------------------------------------------

# 45. NPC AI

La IA no debe resolver físicamente el golpe.

La IA decide:

``` text
quiero usar LEFT_JAB
```

CombatSystem ejecuta:

``` text
timing
hitbox
damage
reaction
```

Arquitectura:

``` text
NPC Brain
 ↓
Combat Decision
 ↓
CombatController
 ↓
CombatSystem
```

------------------------------------------------------------------------

# 46. MULTIPLAYER FUTURO

Diseñar para autoridad del servidor.

Futuro flujo:

``` text
CLIENT
 ↓
request attack
 ↓
SERVER validates
 ↓
CombatSystem
 ↓
damage / result
 ↓
broadcast
```

El cliente no debe ser autoridad definitiva sobre:

-   daño;
-   salud;
-   muerte;
-   impactos;
-   estado de combate.

No implementar networking complejo si todavía no existe, pero no diseñar
de forma incompatible.

------------------------------------------------------------------------

# 47. MOVIMIENTO Y HITBOX

No cambiar automáticamente el `CollisionShape2D` actual.

Primero probar el personaje.

Separar:

``` text
visual body
physical collision
attack hitbox
hurtbox
```

Cada uno tiene una responsabilidad diferente.

------------------------------------------------------------------------

# 48. PIXEL ART

Mantener:

``` text
nearest filtering
```

y configuración pixel-art existente.

No introducir blur.

No suavizar sprites.

No romper pixel snapping.

------------------------------------------------------------------------

# 49. PIVOT / PIES / SOMBRA

El personaje debe quedar correctamente apoyado.

Comprobar:

``` text
feet
world position
collision
shadow
```

La sombra debe usar un anchor estable y no depender del bounding box
cambiante de la animación.

------------------------------------------------------------------------

# 50. ESCALA

Inspeccionar:

``` text
tile size
camera scale
player collision
existing sprite scale
```

Después calibrar el asset Hormelz.

No interpretar automáticamente el canvas 126×132 como el tamaño final en
pantalla.

------------------------------------------------------------------------

# 51. IMPORTACIÓN DE ASSETS

Configurar correctamente:

-   filter;
-   mipmaps;
-   compression;
-   repeat;
-   atlas;
-   frame size;
-   escala.

No modificar destructivamente los archivos originales.

Mantener:

``` text
assets/characters/humans/hormelz_melee/
```

o estructura equivalente.

------------------------------------------------------------------------

# 52. TESTS UNITARIOS

Crear o adaptar tests para:

### AttackDefinition

-   datos válidos;
-   daño;
-   stamina;
-   tiempos.

### CombatState

``` text
FREE → WINDUP
WINDUP → ACTIVE
ACTIVE → RECOVERY
RECOVERY → FREE
```

### Hit Detection

-   objetivo dentro;
-   objetivo fuera;
-   objetivo detrás;
-   self-hit;
-   dead target;
-   duplicate hit.

### Damage

-   health disminuye;
-   health no baja de cero;
-   death.

### Stamina

-   consume;
-   bloquea ataque si insuficiente.

### Combo

-   continúa dentro de ventana;
-   resetea fuera.

### Dodge

-   activa invulnerabilidad;
-   termina correctamente.

------------------------------------------------------------------------

# 53. TESTS DE INTEGRACIÓN

Debe existir al menos una prueba equivalente a:

``` text
Player
 ↓
Attack
 ↓
Hitbox
 ↓
Dummy
 ↓
Damage
 ↓
Hit Reaction
 ↓
Knockback
 ↓
Recovery
```

------------------------------------------------------------------------

# 54. TESTS DE ANIMACIÓN

Verificar:

-   todas las animaciones mapeadas existen;
-   direcciones correctas;
-   no hay referencias rotas;
-   death no vuelve a idle;
-   hit reaction termina;
-   ataques terminan;
-   hitbox se activa/desactiva;
-   no quedan animaciones congeladas.

------------------------------------------------------------------------

# 55. PRUEBA MANUAL OBLIGATORIA

Ejecutar el juego.

Comprobar:

## Movimiento

-   arriba;
-   abajo;
-   izquierda;
-   derecha.

## Ataques

-   jab;
-   hook;
-   straight;
-   elbow;
-   kick.

## Impacto

-   objetivo dentro;
-   objetivo fuera;
-   objetivo detrás;
-   objetivo lateral.

## Combos

-   ataque 1;
-   ataque 2;
-   ataque 3;
-   reset.

## Defensa

-   dodge;
-   block si está disponible.

## Daño

-   jugador recibe daño;
-   enemigo recibe daño.

## Muerte

-   enemigo muere;
-   jugador puede morir.

------------------------------------------------------------------------

# 56. ERRORES PROHIBIDOS

No dejar:

-   hitbox activa permanentemente;
-   daño aplicado cada frame;
-   objetivo golpeado infinitamente por un ataque;
-   ataques con rango absurdo;
-   ataques hacia dirección incorrecta;
-   personaje muerto atacando;
-   stamina negativa;
-   combo infinito;
-   animaciones inexistentes;
-   personaje flotando;
-   personaje enterrado;
-   hitbox desconectada visualmente del golpe;
-   ninja como visual por defecto;
-   lógica duplicada para cada ataque;
-   valores importantes desperdigados.

------------------------------------------------------------------------

# 57. PERFORMANCE

El combate debe ser ligero.

Evitar:

-   cientos de nodos creados por golpe;
-   partículas excesivas;
-   polling global cada frame;
-   búsquedas costosas de objetivos;
-   timers sin limpiar;
-   efectos permanentes.

Preferir:

-   eventos;
-   señales;
-   recursos;
-   objetos reutilizables;
-   shapes simples.

------------------------------------------------------------------------

# 58. DOCUMENTACIÓN

Crear o actualizar:

``` text
docs/gameplay/COMBAT_SYSTEM.md
docs/gameplay/COMBAT_ANIMATIONS.md
docs/CHARACTER_VISUAL_SYSTEM.md
```

Documentar:

-   estados;
-   ataques;
-   animaciones;
-   mapping;
-   timings;
-   hitboxes;
-   eventos;
-   controles;
-   debug;
-   cómo añadir ataque;
-   cómo añadir personaje;
-   cómo añadir animación;
-   limitaciones del asset.

------------------------------------------------------------------------

# 59. ORDEN DE IMPLEMENTACIÓN

## Fase 1 --- Diagnóstico

-   inspeccionar;
-   ejecutar;
-   identificar arquitectura;
-   localizar sistemas.

## Fase 2 --- Asset

-   importar Hormelz;
-   inspeccionar archivos;
-   determinar frame size;
-   determinar direcciones;
-   determinar animaciones;
-   determinar frames/FPS.

## Fase 3 --- Visual

-   reemplazar ninja;
-   integrar `ActorSprite`;
-   integrar `PlayerView`;
-   integrar `ActorVisualCatalog`;
-   calibrar escala;
-   calibrar pivot;
-   calibrar shadow;
-   calibrar anchor.

## Fase 4 --- Combat Foundation

-   CombatState;
-   AttackDefinition;
-   CombatController;
-   hitbox;
-   hurtbox;
-   damage.

## Fase 5 --- Primer ataque

Implementar completamente:

``` text
Left Jab
```

Debe funcionar de principio a fin antes de copiar el patrón.

## Fase 6 --- Ataques

Añadir:

``` text
Right Jab
Left Hook
Right Hook
Straight Right
Elbow
Front Kick
High Kick
Side Kick
Stomp
Combo
```

## Fase 7 --- Defensa

-   dodge;
-   roll;
-   block si el asset lo permite visualmente.

## Fase 8 --- Feedback

-   hit-stop;
-   camera shake;
-   VFX;
-   audio hooks;
-   debug.

## Fase 9 --- Dummy

Crear y probar CombatDummy.

## Fase 10 --- Tests

Unit + integration + manual.

## Fase 11 --- Documentación

Actualizar documentación.

## Fase 12 --- Revisión

Ejecutar desde cero.

------------------------------------------------------------------------

# 60. REGLA DE PROGRESO

Después de cada fase:

``` text
IMPLEMENTAR
 ↓
EJECUTAR
 ↓
TESTEAR
 ↓
CORREGIR
 ↓
CONTINUAR
```

No realizar una implementación masiva sin comprobaciones intermedias.

------------------------------------------------------------------------

# 61. NO SOBRESCRIBIR SIN CONTROL

Antes de cambios importantes:

-   revisar Git;
-   revisar estado;
-   mantener cambios pequeños;
-   evitar borrar archivos;
-   conservar fallback.

Si una refactorización grande resulta necesaria:

1.  explicar el motivo;
2.  listar archivos afectados;
3.  mantener comportamiento existente;
4.  ejecutar tests;
5.  verificar ejecución.

------------------------------------------------------------------------

# 62. CRITERIO DE CALIDAD VISUAL

No aceptar:

``` text
animación empieza
pero hitbox ya golpeó
```

ni:

``` text
hitbox conecta
pero el puño todavía no llegó
```

ni:

``` text
enemigo recibe daño
pero visualmente no reacciona
```

ni:

``` text
camera shake exagerado
```

Cada ataque debe sentirse como una sola acción:

``` text
ANTICIPACIÓN
 ↓
GOLPE
 ↓
CONTACTO
 ↓
REACCIÓN
 ↓
RECUPERACIÓN
```

------------------------------------------------------------------------

# 63. DEMOSTRACIÓN FINAL

La demo final debe poder hacer:

``` text
GAME START
 ↓
PLAYER HUMAN
 ↓
MOVE
 ↓
FACE TARGET
 ↓
JAB
 ↓
HIT
 ↓
IMPACT FX
 ↓
HIT STOP
 ↓
DUMMY REACTS
 ↓
KNOCKBACK
 ↓
RECOVERY
 ↓
SECOND ATTACK
 ↓
COMBO
 ↓
KICK
 ↓
DUMMY DIES
 ↓
PLAYER CONTINUES
```

------------------------------------------------------------------------

# 64. DEFINITION OF DONE

## Personaje

-   [ ] Hormelz es el personaje por defecto.
-   [ ] Ninja queda como fallback.
-   [ ] Idle funciona.
-   [ ] Walk funciona.
-   [ ] Direcciones correctas.
-   [ ] Pivot correcto.
-   [ ] Escala correcta.
-   [ ] No hay sprites borrosos.

## Combate

-   [ ] CombatController.
-   [ ] CombatState.
-   [ ] AttackDefinition.
-   [ ] Jab.
-   [ ] Hook.
-   [ ] Straight.
-   [ ] Elbow.
-   [ ] Kicks.
-   [ ] Combo.
-   [ ] Stamina.
-   [ ] Recovery.
-   [ ] Input buffer.
-   [ ] Hitbox.
-   [ ] Hurtbox.
-   [ ] Damage.
-   [ ] Stagger.
-   [ ] Knockback.
-   [ ] Hit reaction.
-   [ ] Death.

## Feedback

-   [ ] Hit-stop.
-   [ ] Impact VFX.
-   [ ] Camera shake.
-   [ ] Audio hooks.
-   [ ] Debug hitboxes.

## Calidad

-   [ ] Tests pasan.
-   [ ] Proyecto ejecuta.
-   [ ] No hay errores relevantes.
-   [ ] Movimiento no se rompió.
-   [ ] Cámara no se rompió.
-   [ ] Sistemas existentes no se rompieron.

## Arquitectura

-   [ ] CombatSystem no depende de una textura.
-   [ ] AttackDefinitions son data-driven.
-   [ ] Visual y gameplay están separados.
-   [ ] Preparado para NPC.
-   [ ] Preparado para multiplayer.
-   [ ] Preparado para armas.

------------------------------------------------------------------------

# 65. INFORME FINAL OBLIGATORIO

Al terminar, entregar:

``` text
## RESUMEN

## DIAGNÓSTICO ORIGINAL

## ARCHIVOS MODIFICADOS

## ARCHIVOS CREADOS

## ARCHIVOS ELIMINADOS

## ASSET HORMELZ

Animaciones encontradas:
...

Direcciones:
...

Frame size:
...

Frames:
...

## MAPPING DE ANIMACIONES

...

## SISTEMA DE COMBATE

Estados:
...

Ataques:
...

## TIMINGS

...

## HITBOXES

...

## EFECTOS

...

## TESTS

...

## PROBLEMAS

...

## LIMITACIONES

...

## TRABAJO FUTURO

...
```

------------------------------------------------------------------------

# 66. INSTRUCCIÓN FINAL PARA OPENCODE

No quiero un prototipo falso.

Quiero una implementación real integrada al proyecto existente.

No quiero solamente:

``` text
button → animation
```

Quiero:

``` text
INPUT
 ↓
COMBAT STATE
 ↓
ATTACK DEFINITION
 ↓
ANIMATION
 ↓
TIMED HITBOX
 ↓
TARGET VALIDATION
 ↓
DAMAGE
 ↓
HIT REACTION
 ↓
STAGGER
 ↓
KNOCKBACK
 ↓
HIT STOP
 ↓
IMPACT FX
 ↓
CAMERA FEEDBACK
 ↓
RECOVERY
 ↓
COMBO WINDOW
 ↓
READY
```

Usa el pack de Hormelz como fuente visual principal.

Inspecciona los archivos reales antes de construir mappings.

No inventes nombres de archivos, frames ni timings.

No destruyas la arquitectura existente.

No cambies gameplay no relacionado.

No reescribas todo el proyecto.

Haz que hoy mismo sea posible:

> **mover al personaje humano, pelear con él, golpear un enemigo, ver la
> animación correcta, producir impactos y reacciones, hacer combos,
> esquivar/rodar y matar un objetivo de prueba.**

La calidad debe priorizarse sobre la cantidad de ataques.

Un solo golpe perfectamente sincronizado vale más que diez ataques mal
sincronizados.

El objetivo visual final es:

``` text
ANIMATION
+
TIMING
+
HITBOX
+
REACTION
+
KNOCKBACK
+
HIT STOP
+
VFX
+
AUDIO
+
CONTROL
```

Este sistema será la base del combate cuerpo a cuerpo del mundo abierto.

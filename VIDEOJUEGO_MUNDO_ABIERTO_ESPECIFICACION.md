# Proyecto: Mundo Abierto Pixelado Online — Especificación Maestra

## 1. Visión general

Crear un videojuego online de mundo abierto, pixel-art, inicialmente 2D con perspectiva **top-down** (vista desde arriba), inspirado conceptualmente en la combinación de:

- exploración y mundo abierto;
- interacción social y vida cotidiana;
- combate cuerpo a cuerpo;
- estadísticas de personaje;
- inventario y objetos;
- elementos de simulación de vida;
- multijugador online.

La visión a largo plazo es convertir progresivamente el **municipio del desarrollador** en el mundo del videojuego, comenzando por un mapa pequeño y ampliándolo posteriormente a barrios, zonas rurales y finalmente al municipio completo.

El proyecto debe ser diseñado desde el primer día para ser:

- modular;
- mantenible;
- escalable;
- testeable;
- documentado;
- preparado para multijugador;
- preparado para persistencia de datos;
- fácil de ampliar sin reescribir sistemas existentes.

## 2. Regla fundamental del proyecto

NO intentar construir inicialmente la ciudad completa.

El desarrollo debe seguir una estrategia incremental:

```text
Prototipo técnico
      ↓
MVP jugable
      ↓
Multijugador básico
      ↓
Persistencia
      ↓
Sistemas de juego
      ↓
Mapa mayor
      ↓
Barrios
      ↓
Municipio completo
      ↓
Sistemas avanzados
```

Cada etapa debe dejar el proyecto funcionando.

---

# 3. Stack tecnológico inicial

## Motor

**Godot 4.x**

## Lenguaje

**GDScript**

Motivos:

- ligero;
- integrado con Godot;
- sencillo de mantener;
- sintaxis relativamente cercana a Python;
- adecuado para prototipado rápido;
- apropiado para un juego 2D;
- permite que un desarrollador con recursos de hardware limitados pueda trabajar con el proyecto.

## Gráficos

Pixel Art 2D.

No utilizar 3D salvo que una decisión futura del proyecto lo justifique explícitamente.

## Multiplayer

Utilizar inicialmente las capacidades de networking de Godot.

El diseño debe separar:

- cliente;
- servidor;
- lógica autoritativa;
- transporte de red.

No mezclar lógica de servidor con lógica visual.

## Persistencia futura

Diseñar una capa de persistencia desacoplada.

La primera versión puede utilizar almacenamiento local durante el prototipo, pero la arquitectura debe permitir posteriormente incorporar una base de datos como PostgreSQL sin reescribir el dominio del juego.

---

# 4. Arquitectura general

La arquitectura debe seguir separación por capas y responsabilidades.

Propuesta:

```text
Presentation
      ↓
Application
      ↓
Domain
      ↓
Infrastructure
```

## 4.1 Presentation

Responsable exclusivamente de:

- escenas;
- sprites;
- animaciones;
- UI;
- efectos visuales;
- entrada del usuario;
- cámara;
- presentación de estados.

No debe contener reglas fundamentales del juego.

## 4.2 Application

Responsable de coordinar casos de uso.

Ejemplos:

- crear personaje;
- iniciar sesión;
- atacar;
- recoger objeto;
- equipar objeto;
- consumir objeto;
- cambiar de zona;
- conectarse al servidor.

## 4.3 Domain

Contiene las reglas principales del videojuego.

Ejemplos:

- Player;
- CharacterStats;
- Health;
- Stamina;
- Weapon;
- Item;
- Inventory;
- Combat;
- Damage;
- NPC;
- WorldObject.

El dominio no debe depender de nodos visuales de Godot cuando no sea necesario.

## 4.4 Infrastructure

Responsable de:

- networking;
- persistencia;
- archivos;
- base de datos;
- servicios externos;
- configuración;
- logging.

---

# 5. Estructura propuesta del proyecto

La estructura debe mantenerse modular.

Ejemplo:

```text
project/
├── assets/
│   ├── sprites/
│   ├── characters/
│   ├── environment/
│   ├── weapons/
│   ├── items/
│   ├── ui/
│   └── audio/
│
├── scenes/
│   ├── player/
│   ├── npc/
│   ├── world/
│   ├── items/
│   ├── weapons/
│   └── ui/
│
├── scripts/
│   ├── domain/
│   │   ├── player/
│   │   ├── combat/
│   │   ├── inventory/
│   │   ├── items/
│   │   ├── npc/
│   │   └── world/
│   │
│   ├── application/
│   │   ├── player/
│   │   ├── combat/
│   │   ├── inventory/
│   │   └── world/
│   │
│   ├── presentation/
│   │   ├── player/
│   │   ├── ui/
│   │   ├── camera/
│   │   └── effects/
│   │
│   └── infrastructure/
│       ├── networking/
│       ├── persistence/
│       ├── configuration/
│       └── logging/
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── multiplayer/
│
├── docs/
│   ├── architecture/
│   ├── gameplay/
│   ├── networking/
│   └── maps/
│
└── project.godot
```

La estructura real puede adaptarse a las convenciones de Godot, pero las responsabilidades deben permanecer separadas.

---

# 6. Principios de desarrollo

El agente debe respetar estas reglas:

1. No crear código innecesariamente complejo.
2. No duplicar lógica.
3. No colocar toda la lógica en un único script.
4. No crear un `GameManager` gigantesco que controle todo.
5. Evitar dependencias circulares.
6. Utilizar interfaces/abstracciones cuando aporten una ventaja real.
7. Mantener módulos independientes.
8. Crear tests para reglas importantes.
9. Documentar decisiones arquitectónicas relevantes.
10. No introducir una tecnología externa sin justificarla.
11. Priorizar soluciones ligeras.
12. Optimizar solo cuando exista una necesidad real.
13. No sacrificar mantenibilidad por micro-optimizaciones.
14. Mantener el proyecto ejecutable después de cada cambio importante.

---

# 7. MVP — Primera versión jugable

El primer objetivo NO es crear una ciudad.

El primer objetivo es tener una pequeña experiencia jugable que demuestre la arquitectura.

## El MVP debe incluir

### Mundo

- pequeño mapa 2D;
- terreno;
- árboles;
- piedras;
- algunos obstáculos;
- caminos;
- al menos una construcción sencilla;
- colisiones.

### Jugador

El jugador debe:

- aparecer en el mapa;
- moverse;
- tener animaciones básicas;
- tener dirección/orientación;
- tener vida;
- recibir daño;
- morir;
- reaparecer.

### Combate

Implementar inicialmente:

- ataque cuerpo a cuerpo;
- distancia de ataque;
- cooldown;
- daño;
- detección de objetivo;
- invulnerabilidad temporal si corresponde;
- muerte.

### Arma inicial

Crear como mínimo:

- piedra;
- cuchillo.

No implementar armas de fuego en el MVP.

El sistema debe ser genérico para poder agregar posteriormente otros objetos.

### Inventario

Implementar una versión sencilla:

```text
Inventory
 ├── Item
 ├── Quantity
 └── Capacity
```

Debe permitir:

- recoger;
- almacenar;
- eliminar;
- utilizar;
- equipar objetos cuando corresponda.

### NPC

Crear al menos un NPC básico.

Debe poder:

- existir en el mapa;
- tener vida;
- recibir daño;
- morir;
- tener comportamiento sencillo.

### Multiplayer

El MVP debe demostrar al menos:

- servidor;
- dos clientes;
- dos jugadores visibles;
- movimiento sincronizado;
- conexión/desconexión;
- estado básico sincronizado.

No intentar resolver todavía todas las necesidades de un MMO.

---

# 8. Jugador

El jugador debe ser un sistema independiente.

Modelo conceptual:

```text
Player
├── id
├── name
├── position
├── rotation/direction
├── health
├── max_health
├── stamina
├── max_stamina
├── inventory
├── equipped_item
└── state
```

Estados posibles inicialmente:

```text
IDLE
MOVING
ATTACKING
HURT
DEAD
```

No permitir que cada sistema modifique arbitrariamente el estado del jugador.

Las transiciones deben estar controladas.

---

# 9. Estadísticas

Inicialmente:

- vida;
- vida máxima;
- stamina;
- stamina máxima;
- daño;
- defensa;
- velocidad de movimiento.

Diseñar el sistema para permitir posteriormente:

- hambre;
- sed;
- energía;
- fuerza;
- resistencia;
- velocidad;
- experiencia;
- nivel;
- reputación;
- habilidades.

No implementar todos estos sistemas todavía.

---

# 10. Sistema de combate

El combate debe ser modular.

Concepto:

```text
Attack
   ↓
Target detection
   ↓
Validation
   ↓
Damage calculation
   ↓
Apply damage
   ↓
Game event
   ↓
Presentation
```

La fórmula inicial puede ser sencilla:

```text
final_damage = max(1, attack_damage - defense)
```

El sistema debe permitir posteriormente cambiar la fórmula sin reescribir armas ni personajes.

---

# 11. Sistema de armas

Crear una abstracción de arma.

Ejemplo conceptual:

```text
Weapon
├── id
├── name
├── damage
├── attack_range
├── attack_cooldown
├── stamina_cost
└── durability
```

Tipos iniciales:

- piedra;
- cuchillo.

Futuros tipos posibles:

- palo;
- bate;
- machete;
- herramientas;
- objetos improvisados.

El diseño debe permitir añadir nuevos tipos sin modificar el sistema principal de combate.

---

# 12. Sistema de objetos

Crear un sistema genérico de objetos.

```text
Item
├── id
├── name
├── type
├── stackable
├── max_stack
└── metadata
```

Tipos posibles:

```text
WEAPON
CONSUMABLE
MATERIAL
QUEST
CURRENCY
CLOTHING
TOOL
MISC
```

No es necesario implementar todos inicialmente.

---

# 13. Inventario

Funciones iniciales:

```text
add_item()
remove_item()
has_item()
get_quantity()
use_item()
equip_item()
unequip_item()
```

El inventario no debe conocer detalles gráficos.

La UI debe consultar el inventario y mostrarlo.

---

# 14. Mundo

El mundo debe dividirse en zonas.

Ejemplo:

```text
World
├── Zone_001
├── Zone_002
├── Zone_003
└── ...
```

Esto es importante para el futuro mapa municipal.

No crear un único mapa gigantesco desde el principio.

El sistema debe permitir:

- cargar zonas;
- descargar zonas;
- cambiar de zona;
- identificar objetos de una zona;
- guardar estados de una zona.

En una etapa posterior se podrá implementar streaming de mundo.

---

# 15. Futuro mapa del municipio

La visión final es reproducir progresivamente el municipio real.

El mapa debe poder incorporar:

- calles;
- viviendas;
- edificios;
- parques;
- árboles;
- ríos;
- terrenos;
- comercios;
- instituciones;
- zonas rurales;
- puntos de interés.

No asumir que el mapa final debe estar en una sola escena.

Debe utilizarse una división lógica:

```text
Municipio
├── Zona A
│   ├── Barrio
│   └── Barrio
├── Zona B
├── Zona C
└── Zona rural
```

---

# 16. Sistema de coordenadas y mapa

Desde el comienzo documentar:

- escala;
- tamaño de tile;
- resolución base;
- unidades del mundo;
- posición de origen;
- sistema de coordenadas.

No cambiar arbitrariamente la escala a mitad del proyecto.

Elegir una resolución pixel-art coherente y mantenerla.

---

# 17. Cámara

La cámara inicialmente debe:

- seguir al jugador;
- tener límites;
- evitar mostrar zonas fuera del mapa;
- permitir ajustar zoom.

El sistema debe permitir posteriormente:

- diferentes zooms;
- interiores;
- vehículos;
- cámaras especiales.

---

# 18. NPC

Crear una arquitectura preparada para distintos comportamientos.

Inicialmente:

```text
NPC
├── stats
├── state
├── position
└── behavior
```

Estados posibles:

```text
IDLE
WANDER
CHASE
ATTACK
FLEE
DEAD
```

No implementar IA avanzada inicialmente.

---

# 19. Networking

El juego debe utilizar una arquitectura **server-authoritative**.

Regla fundamental:

> El cliente solicita acciones; el servidor valida y decide el estado real del juego.

Ejemplo:

```text
CLIENTE
"quiero atacar"

        ↓

SERVIDOR

¿Jugador existe?
¿Está vivo?
¿Tiene arma?
¿Puede atacar?
¿Está suficientemente cerca?
¿El objetivo es válido?

        ↓

SERVIDOR
Calcula daño

        ↓

CLIENTES
Reciben nuevo estado
```

No confiar en el cliente para:

- daño;
- vida;
- inventario;
- dinero;
- posición definitiva;
- resultados del combate;
- permisos.

---

# 20. Sincronización

Inicialmente sincronizar:

- posición;
- dirección;
- estado;
- vida;
- acciones importantes.

Evitar enviar información innecesaria.

El diseño debe dejar espacio para:

- interpolación;
- predicción del cliente;
- reconciliación;
- snapshots;
- compresión;
- interest management.

No implementar todo eso en el MVP.

---

# 21. Persistencia

La información persistente futura puede incluir:

```text
Account
Character
Inventory
Items
Stats
Position
Properties
Money
Progress
```

La lógica del juego no debe depender directamente de PostgreSQL.

Usar una capa:

```text
Game Domain
     ↓
Repository Interface
     ↓
Persistence Implementation
```

Esto permitirá cambiar:

```text
JSON/local
      ↓
SQLite
      ↓
PostgreSQL
```

sin modificar el dominio.

---

# 22. Cuenta y personaje

En una etapa posterior:

```text
Account
├── account_id
├── username
├── authentication_data
└── characters
```

Y:

```text
Character
├── character_id
├── account_id
├── name
├── appearance
├── stats
├── inventory
└── world_state
```

No almacenar contraseñas en texto plano.

---

# 23. Seguridad

Desde el inicio:

- nunca confiar en datos enviados por el cliente;
- validar entradas;
- validar acciones en servidor;
- no almacenar secretos dentro del repositorio;
- utilizar variables de entorno;
- separar configuración de código;
- registrar errores;
- evitar exponer información sensible.

---

# 24. Rendimiento

El hardware de desarrollo es limitado.

Por tanto:

- priorizar 2D;
- evitar assets innecesariamente grandes;
- evitar cientos de procesos independientes;
- usar pooling cuando realmente sea necesario;
- evitar cargar el mapa completo si no hace falta;
- diseñar el mundo por zonas;
- evitar lógica ejecutándose cada frame cuando pueda utilizar eventos/timers;
- medir antes de optimizar.

El objetivo inicial no es maximizar gráficos.

El objetivo es conseguir un juego funcional y sostenible.

---

# 25. Assets

Durante el prototipo:

- utilizar placeholders;
- utilizar formas simples;
- utilizar sprites temporales;
- evitar perder tiempo creando arte definitivo.

Ejemplo:

```text
Player → sprite provisional
Tree → sprite provisional
Rock → sprite provisional
House → sprite provisional
```

Una vez validada la mecánica, sustituir los placeholders.

---

# 26. Sistema de eventos

Siempre que sea útil, utilizar eventos para desacoplar sistemas.

Ejemplos:

```text
player_damaged
player_died
item_picked
item_used
weapon_equipped
player_connected
player_disconnected
zone_entered
zone_exited
```

Esto permitirá que:

```text
Combate
```

no tenga que conocer directamente:

```text
UI
Sonido
Animaciones
Logs
Networking
```

---

# 27. Logging

Crear un sistema de logging con niveles:

```text
DEBUG
INFO
WARNING
ERROR
```

Durante desarrollo debe poder activarse DEBUG.

En producción debe poder reducirse el nivel.

---

# 28. Configuración

No colocar valores modificables por todo el código.

Crear configuración para:

- velocidad;
- daño;
- cooldown;
- vida;
- stamina;
- resolución;
- networking;
- servidor;
- puertos;
- límites.

Ejemplo:

```text
PLAYER_SPEED
PLAYER_MAX_HEALTH
DEFAULT_ATTACK_DAMAGE
ATTACK_COOLDOWN
SERVER_PORT
```

---

# 29. Testing

Crear tests desde las primeras versiones.

Prioridad:

## Unit tests

Probar:

- daño;
- vida;
- inventario;
- objetos;
- estadísticas;
- cooldown;
- validaciones.

## Integration tests

Probar:

- jugador + combate;
- jugador + inventario;
- servidor + jugador;
- persistencia + personaje.

## Multiplayer tests

Probar:

- conexión;
- desconexión;
- dos jugadores;
- sincronización;
- acciones inválidas.

---

# 30. Desarrollo por fases

## Fase 0 — Preparación

Objetivo:

- instalar Godot;
- crear repositorio;
- crear proyecto;
- configurar Git;
- crear estructura;
- documentar arquitectura.

Resultado:

Proyecto vacío pero correctamente organizado.

---

## Fase 1 — Prototipo offline

Implementar:

- mapa;
- jugador;
- movimiento;
- cámara;
- colisiones;
- vida;
- combate;
- piedra;
- cuchillo;
- NPC;
- inventario básico.

Resultado:

Juego pequeño jugable offline.

---

## Fase 2 — Multiplayer

Implementar:

- servidor;
- cliente;
- conexión;
- dos jugadores;
- sincronización;
- desconexión.

Resultado:

Dos personas pueden entrar al mismo pequeño mapa.

---

## Fase 3 — Persistencia

Implementar:

- cuentas;
- personaje;
- inventario;
- estadísticas;
- posición;
- guardado/carga.

Resultado:

El jugador puede salir y volver conservando su progreso.

---

## Fase 4 — Mundo ampliado

Implementar:

- múltiples zonas;
- edificios;
- caminos;
- NPC;
- objetos;
- interiores sencillos.

Resultado:

Primer pequeño barrio/zona.

---

## Fase 5 — Sistemas de vida

Añadir progresivamente:

- dinero;
- hambre;
- sed;
- energía;
- propiedades;
- interacción con objetos;
- trabajos;
- comercio.

No implementar todos simultáneamente.

---

## Fase 6 — Municipio

Comenzar la conversión del municipio real:

```text
Mapa real
   ↓
División por zonas
   ↓
Calles principales
   ↓
Edificios
   ↓
Puntos de interés
   ↓
Detalles
```

El proceso debe ser incremental.

---

# 31. Roadmap de largo plazo

Posibles sistemas futuros:

- vehículos;
- casas;
- propiedades;
- trabajos;
- economía;
- comercios;
- NPC con rutinas;
- clima;
- día/noche;
- eventos;
- misiones;
- reputación;
- facciones;
- policía/autoridades del mundo ficticio;
- mascotas;
- agricultura;
- crafting;
- habilidades;
- personalización;
- ropa;
- transporte;
- interiores;
- grupos/clanes;
- chat;
- mercado entre jugadores.

Estos sistemas NO forman parte del MVP.

---

# 32. Regla para futuras funcionalidades

Cada nueva funcionalidad debe responder:

1. ¿En qué módulo pertenece?
2. ¿Qué responsabilidad tiene?
3. ¿Qué dependencias necesita?
4. ¿Puede probarse independientemente?
5. ¿Afecta al servidor?
6. ¿Afecta al cliente?
7. ¿Necesita persistencia?
8. ¿Necesita sincronización?
9. ¿Afecta a sistemas existentes?
10. ¿Puede implementarse sin romper la arquitectura?

---

# 33. Flujo de trabajo obligatorio para el agente de IA

Antes de modificar código:

1. Inspeccionar el repositorio.
2. Identificar arquitectura existente.
3. Identificar dependencias.
4. Revisar documentación.
5. Revisar tests.
6. Explicar brevemente qué se va a modificar.
7. Implementar.
8. Ejecutar tests.
9. Ejecutar el proyecto si es posible.
10. Corregir errores.
11. Revisar cambios.
12. Actualizar documentación si la arquitectura cambió.

No asumir que una funcionalidad no existe sin revisar el código.

No sobrescribir código existente sin analizarlo.

---

# 34. Uso de OpenCode

OpenCode será utilizado como agente de programación.

El agente debe:

- inspeccionar archivos;
- comprender arquitectura;
- crear/modificar código;
- ejecutar comandos;
- ejecutar tests;
- diagnosticar errores;
- mantener documentación.

Pero NO debe realizar cambios masivos sin control.

Para funcionalidades grandes:

```text
Analizar
  ↓
Diseñar
  ↓
Implementar módulo
  ↓
Testear
  ↓
Integrar
  ↓
Probar
```

---

# 35. Reglas para OpenCode

Cuando exista una tarea ambigua:

- no inventar requisitos;
- revisar documentación;
- identificar qué parte no está definida;
- utilizar la solución más simple compatible con la arquitectura;
- documentar la decisión.

Cuando una implementación existente funcione:

- no reescribirla innecesariamente.

Cuando encuentre código deficiente:

- no hacer una refactorización gigante salvo que sea necesaria;
- aislar el problema;
- realizar cambios pequeños y verificables.

---

# 36. Definition of Done

Una funcionalidad se considera terminada cuando:

- funciona;
- está integrada;
- no rompe funcionalidades existentes;
- tiene tests cuando corresponde;
- no contiene errores conocidos;
- está documentada cuando es necesario;
- respeta la arquitectura;
- puede ejecutarse en el entorno objetivo.

---

# 37. Primera tarea concreta del agente

NO comenzar creando todo el videojuego.

Primero realizar únicamente:

### Paso 1

Inspeccionar el entorno de desarrollo.

Verificar:

- versión de Godot;
- versión de Git;
- sistema operativo;
- estructura del proyecto;
- recursos disponibles.

### Paso 2

Crear el proyecto Godot 2D.

### Paso 3

Crear la estructura de carpetas.

### Paso 4

Crear documentación:

```text
docs/architecture/ARCHITECTURE.md
docs/gameplay/GAMEPLAY.md
docs/networking/NETWORKING.md
docs/ROADMAP.md
```

### Paso 5

Crear un pequeño mapa de prueba.

### Paso 6

Crear un jugador provisional.

### Paso 7

Implementar movimiento.

### Paso 8

Implementar cámara.

### Paso 9

Implementar colisiones.

### Paso 10

Ejecutar y verificar.

No avanzar al combate hasta que esto funcione correctamente.

---

# 38. Primera demostración esperada

Al ejecutar el proyecto debe aparecer:

```text
┌──────────────────────────────────────┐
│                                      │
│       🌳                🌳           │
│                                      │
│                🧍                    │
│                                      │
│     🌳                         🪨    │
│                                      │
│              🏠                      │
│                                      │
└──────────────────────────────────────┘
```

El jugador debe poder:

- moverse;
- chocar contra obstáculos;
- ser seguido por la cámara;
- permanecer dentro del área jugable.

---

# 39. Filosofía general

Este proyecto debe tratarse como un videojuego que puede evolucionar durante años.

No diseñar únicamente para el prototipo.

Pero tampoco sobrearquitecturar el prototipo.

La regla es:

> **Diseñar las fronteras correctas desde el principio y mantener cada sistema lo más simple posible hasta que exista una necesidad real de hacerlo más complejo.**

El objetivo final no es únicamente crear un juego pixelado.

El objetivo es construir una plataforma de mundo virtual que pueda crecer desde una pequeña zona de prueba hasta una representación jugable y online de un municipio completo.

---

# 40. Estado inicial del proyecto

Estado:

```text
PLANNING
```

Siguiente estado:

```text
FOUNDATION
```

Después:

```text
MVP_OFFLINE
```

Después:

```text
MULTIPLAYER_PROTOTYPE
```

Después:

```text
PERSISTENCE
```

Después:

```text
WORLD_EXPANSION
```

No marcar una fase como completada hasta verificarla mediante pruebas.

---

# 41. Instrucción final para el agente

Lee este documento completo antes de comenzar.

No implementes todo de una vez.

Primero inspecciona el entorno y prepara la base del proyecto.

Después implementa el MVP por incrementos pequeños.

Después de cada incremento:

1. ejecuta pruebas;
2. ejecuta el juego;
3. verifica errores;
4. corrige;
5. documenta;
6. continúa únicamente cuando la etapa esté estable.

Prioridades:

```text
FUNCIONALIDAD
     ↓
CORRECCIÓN
     ↓
ARQUITECTURA
     ↓
MANTENIBILIDAD
     ↓
ESCALABILIDAD
     ↓
OPTIMIZACIÓN
     ↓
DETALLE VISUAL
```

La apariencia definitiva del juego puede cambiar.

La arquitectura y los límites entre sistemas deben mantenerse sólidos.

**Comienza por la Fase 0.**

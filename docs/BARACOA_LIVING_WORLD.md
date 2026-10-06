# BARACOA LIVING WORLD
## Sistema de simulación progresiva de un mundo urbano vivo

**Documento de diseño técnico para el proyecto del videojuego**

---

## 1. Propósito del documento

Este documento define una mejora arquitectónica importante para el videojuego: convertir el mundo de Baracoa en un **mundo vivo**, donde los NPC, vehículos, actividades, relaciones y eventos continúan teniendo un estado aunque el jugador no los esté observando directamente.

La idea central es:

> **Todo lo que existe en el mundo tiene un estado. El nivel de detalle con el que se simula depende de su relevancia respecto al jugador.**

El objetivo NO es copiar internamente la implementación de *Rain World*. La referencia conceptual es su idea de simulación progresiva: aquello que está cerca puede simularse con gran detalle, mientras que aquello que está lejos puede representarse mediante modelos mucho más baratos.

Para este proyecto se adaptará ese concepto a un **mundo urbano abierto**, con NPC, vehículos, trabajos, viviendas, horarios, necesidades, relaciones, combate, policía y futuras actividades económicas.

---

# 2. Objetivos

## 2.1 Objetivo principal

Crear una arquitectura que permita que el mundo continúe evolucionando sin exigir que todos los NPC y objetos se ejecuten permanentemente con física, animaciones, navegación y lógica completa.

## 2.2 Objetivos secundarios

El sistema debe:

- reducir consumo de CPU;
- reducir consumo de memoria;
- permitir muchos NPC sin simularlos todos al máximo nivel;
- mantener continuidad entre simulación cercana y lejana;
- evitar que un NPC "desaparezca" conceptualmente porque el jugador se alejó;
- permitir que un NPC tenga una vida propia;
- permitir que vehículos y otros sistemas adopten el mismo modelo;
- funcionar correctamente con futuras zonas de Baracoa;
- ser compatible con multiplayer;
- permitir una futura simulación server-authoritative;
- ser extensible sin reescribir el resto del juego.

---

# 3. Principio fundamental

El error que debe evitarse es intentar ejecutar esto permanentemente para cada NPC:

```text
IA completa
+ navegación
+ pathfinding
+ física
+ animación
+ colisiones
+ detección
+ relaciones
+ necesidades
+ combate
+ renderizado
```

Si existen cientos o miles de NPC, esto sería innecesariamente costoso.

En cambio, cada entidad tendrá diferentes **niveles de simulación**.

```text
                     JUGADOR
                        │
                        ▼
                ┌───────────────┐
                │ FULL          │
                │ simulación    │
                └───────────────┘
                        │
                  distancia /
                  relevancia
                        │
                        ▼
                ┌───────────────┐
                │ LIGHT         │
                │ simulación    │
                └───────────────┘
                        │
                  distancia /
                  relevancia
                        │
                        ▼
                ┌───────────────┐
                │ ABSTRACT      │
                │ simulación    │
                └───────────────┘
```

La entidad sigue existiendo en los tres casos.

Lo que cambia es **cómo se calcula su evolución**.

---

# 4. Niveles de simulación

El sistema tendrá inicialmente tres niveles.

## 4.1 FULL

Representa la simulación completa.

Se utiliza para entidades suficientemente cercanas o suficientemente importantes para el jugador.

### Características

Puede incluir:

- nodo de Godot activo;
- renderizado;
- animación;
- física;
- colisiones;
- navegación;
- pathfinding;
- IA completa;
- detección de jugadores;
- combate;
- interacción con objetos;
- interacción con otros NPC;
- vehículos;
- efectos;
- necesidades actualizadas frecuentemente;
- decisiones de comportamiento;
- eventos inmediatos.

Ejemplo:

```text
NPC está caminando a 20 metros del jugador.

→ aparece en pantalla;
→ tiene animación;
→ calcula navegación;
→ puede hablar con el jugador;
→ puede detectar una pelea;
→ puede huir;
→ puede recoger un objeto;
→ puede entrar en combate.
```

---

# 5. LIGHT

Representa una simulación intermedia.

La entidad sigue evolucionando, pero no necesita ejecutar toda la simulación física.

No necesariamente debe existir como objeto renderizado en pantalla.

### Puede mantener

- posición aproximada;
- zona actual;
- destino;
- actividad;
- estado de necesidades;
- salud;
- energía;
- hambre;
- dinero;
- relaciones relevantes;
- objetivo;
- estado de navegación simplificado;
- eventos importantes;
- encuentros simplificados.

### No debe ejecutar normalmente

- animación detallada;
- física completa;
- colisiones físicas;
- renderizado;
- pathfinding pesado cada frame;
- lógica de combate detallada.

Ejemplo:

```text
NPC está a 2 calles del jugador.

No necesitamos:

    calcular cada paso
    animar cada pierna
    ejecutar física

Podemos mantener:

    NPC = trabajando
    destino = tienda
    progreso = 62%
    energía = 71%
    hambre = 42%
```

Cuando sea necesario, puede volver a FULL.

---

# 6. ABSTRACT

Es la simulación más económica.

Está pensada para entidades muy alejadas del jugador.

La entidad no necesita existir como objeto físico activo.

En lugar de simular cada frame, se puede simular mediante:

- tiempo;
- eventos;
- horarios;
- probabilidades;
- estados;
- transiciones;
- resultados resumidos.

Ejemplo:

```text
NPC:
Casa → Trabajo → Restaurante → Casa
```

En lugar de ejecutar:

```text
60 FPS
×
caminar
×
física
×
animación
```

podemos representar:

```text
08:00 → sale de casa
08:20 → llega al trabajo
12:00 → almuerza
13:00 → vuelve al trabajo
17:00 → termina
17:25 → llega a casa
```

---

# 7. El mundo sigue existiendo

Una regla crítica:

> Cambiar el nivel de simulación NO significa destruir el estado de la entidad.

Incorrecto:

```text
Jugador se aleja
↓
NPC eliminado
```

Correcto:

```text
Jugador se aleja
↓
NPC cambia de FULL a LIGHT
↓
más lejos
↓
NPC cambia de LIGHT a ABSTRACT
↓
continúa evolucionando
```

Y al regresar:

```text
ABSTRACT
   ↓
LIGHT
   ↓
FULL
```

---

# 8. Promoción y degradación

El sistema debe poder cambiar automáticamente el nivel de simulación.

## 8.1 FULL → LIGHT

Puede ocurrir cuando:

- la entidad se aleja del jugador;
- deja de ser relevante;
- ya no participa en una interacción;
- abandona la zona de simulación detallada.

## 8.2 LIGHT → ABSTRACT

Puede ocurrir cuando:

- está suficientemente lejos;
- no participa en eventos importantes;
- no está siendo observada;
- su estado puede representarse mediante eventos.

## 8.3 ABSTRACT → LIGHT

Cuando:

- el jugador se acerca;
- una entidad relevante entra en una zona cercana;
- se necesita mayor precisión;
- ocurre un evento que requiere interacción.

## 8.4 LIGHT → FULL

Cuando:

- entra en rango de simulación completa;
- aparece cerca del jugador;
- entra en combate;
- inicia una interacción;
- se vuelve relevante.

## 8.5 ABSTRACT → FULL

Puede ocurrir directamente cuando una entidad aparece dentro del área de alta relevancia.

Sin embargo, el sistema debe materializarla con un estado coherente.

---

# 9. Nunca reiniciar arbitrariamente una entidad

Un problema que debe evitarse:

```text
NPC estaba trabajando.
Jugador se alejó.
NPC pasó a ABSTRACT.
Jugador volvió.
NPC aparece mágicamente en su casa.
```

Eso sería incorrecto.

El NPC debe reconstruirse a partir de su estado simulado.

Ejemplo:

```text
10:00
NPC = trabajando

Jugador se aleja.

10:00 → 11:00
ABSTRACT:
NPC permanece trabajando.

Jugador regresa a las 11:00.

NPC vuelve a FULL:
estado = trabajando
posición = cerca del trabajo
```

---

# 10. Estado persistente de un NPC

Cada NPC debe tener un estado lógico independiente de su representación visual.

Ejemplo conceptual:

```text
NPCState

id
name
home
current_zone
current_location
destination
activity
health
energy
hunger
thirst
money
job
schedule
relationships
inventory
faction
wanted_level
simulation_level
last_simulation_time
```

El nodo visual de Godot NO debe ser la fuente de verdad absoluta.

La fuente de verdad debe ser el estado lógico.

---

# 11. Separación entre estado y representación

Arquitectura conceptual:

```text
NPCState
    │
    ▼
SimulationManager
    │
    ├── FullSimulation
    ├── LightSimulation
    └── AbstractSimulation
             │
             ▼
       NPC Representation
```

Esto permite que:

```text
NPCState
```

exista aunque no exista un:

```text
CharacterBody2D
```

activo.

---

# 12. Entidades del mundo

El sistema no debe limitarse exclusivamente a NPC.

Debe diseñarse como un sistema general de entidades.

Posibles entidades:

```text
NPC
Jugador
Vehículo
Animal
Objeto dinámico
Comerciante
Policía
Enemigo
Grupo
Evento
```

Cada tipo puede implementar su propia lógica de simulación.

---

# 13. Arquitectura propuesta

Crear un sistema central:

```text
WorldSimulationManager
```

Responsabilidades:

- registrar entidades;
- conocer el estado de cada entidad;
- determinar el nivel de simulación;
- promover entidades;
- degradar entidades;
- ejecutar simulación FULL;
- ejecutar simulación LIGHT;
- ejecutar simulación ABSTRACT;
- procesar eventos;
- coordinar zonas;
- controlar presupuestos de CPU;
- preparar futura sincronización multiplayer.

---

# 14. Componentes principales

La arquitectura conceptual debe incluir:

```text
WorldSimulationManager
│
├── SimulationScheduler
│
├── SimulationLevelManager
│
├── FullSimulationSystem
│
├── LightSimulationSystem
│
├── AbstractSimulationSystem
│
├── WorldEntityRegistry
│
├── WorldEventQueue
│
├── ZoneManager
│
├── SimulationClock
│
└── StatePersistence
```

No es obligatorio crear exactamente estas clases desde el primer commit.

La IA debe evitar sobrearquitecturar el MVP.

---

# 15. WorldEntity

Toda entidad simulable debe tener una identidad lógica.

Ejemplo:

```text
WorldEntity
├── id
├── type
├── zone_id
├── position
├── simulation_level
├── state
└── last_update
```

La representación de Godot es secundaria.

---

# 16. SimulationLevelManager

Debe decidir:

```text
¿Qué nivel de simulación necesita esta entidad?
```

No debe basarse exclusivamente en distancia.

Debe considerar también:

- distancia al jugador;
- zona actual;
- visibilidad;
- relevancia;
- combate;
- interacción;
- eventos;
- importancia de la entidad;
- cantidad total de entidades activas;
- presupuesto de CPU.

---

# 17. Distancia no es la única regla

Ejemplo:

NPC A:

```text
50 metros
```

NPC B:

```text
100 metros
```

Pero NPC A puede estar realizando una actividad irrelevante y NPC B puede estar relacionado con una misión.

Entonces:

```text
B podría recibir mayor prioridad que A.
```

La arquitectura debe permitir un sistema de **relevancia**.

---

# 18. Sistema de relevancia

Cada entidad puede tener un valor conceptual:

```text
relevance_score
```

Factores:

```text
distancia
+
visibilidad
+
misión
+
combate
+
interacción
+
importancia narrativa
+
relación con jugador
+
evento activo
```

Ejemplo:

```text
NPC normal:
relevancia = 20

NPC amigo:
relevancia = 50

NPC de misión:
relevancia = 100

NPC en combate con jugador:
relevancia = 1000
```

Los valores concretos deben quedar configurables.

---

# 19. Presupuesto de simulación

No debe asumirse que el ordenador puede simular infinitamente.

El sistema debe trabajar con un presupuesto.

Ejemplo conceptual:

```text
Presupuesto del frame:

FULL:
máximo recomendado = N entidades

LIGHT:
máximo recomendado = M entidades

ABSTRACT:
puede manejar muchas más entidades
```

Los valores NO deben quedar hardcodeados sin necesidad.

Deben estar en configuración.

Ejemplo:

```text
simulation_config
```

---

# 20. Objetivo de rendimiento

El sistema debe priorizar:

```text
jugabilidad
>
estabilidad
>
precisión secundaria
```

Si hay demasiadas entidades:

```text
NO:
simular todo con máxima precisión

SÍ:
degradar automáticamente entidades de menor prioridad
```

---

# 21. Scheduler

No todas las entidades necesitan actualizarse en cada frame.

El sistema debe permitir frecuencias distintas.

Ejemplo:

```text
FULL:
cada frame / frecuencia alta

LIGHT:
varias veces por segundo

ABSTRACT:
cada cierto intervalo o mediante eventos
```

El intervalo exacto debe ser configurable.

---

# 22. Simulación basada en eventos

La simulación ABSTRACT debe utilizar eventos siempre que sea posible.

Ejemplos:

```text
NPC_LEAVES_HOME
NPC_STARTS_WORK
NPC_FINISHES_WORK
NPC_EATS
NPC_MEETS_NPC
NPC_BUYS_ITEM
NPC_GETS_INTO_FIGHT
NPC_RETURNS_HOME
```

Un evento debe poder contener:

```text
event_id
entity_id
timestamp
type
source
target
payload
```

---

# 23. Event Queue

Crear conceptualmente:

```text
WorldEventQueue
```

Debe permitir:

- programar eventos;
- ejecutar eventos vencidos;
- cancelar eventos;
- reprogramar eventos;
- ordenar eventos temporalmente;
- registrar eventos importantes.

Ejemplo:

```text
08:00
NPC 52 sale de casa

08:20
NPC 52 llega al trabajo

12:00
NPC 52 almuerza
```

---

# 24. Simulation Clock

El mundo debe tener un reloj lógico.

Debe ser posible conocer:

```text
día
hora
minuto
```

Esto será importante para:

- horarios;
- comercios;
- trabajos;
- NPC;
- vehículos;
- policía;
- eventos;
- misiones;
- clima;
- economía futura.

El reloj debe ser independiente del FPS.

---

# 25. Ejemplo completo

NPC:

```text
ID: 102
Casa: Zona 01 / Calle X
Trabajo: comercio
Horario: 08:00 - 17:00
```

A las 07:55:

```text
FULL
```

El jugador se aleja.

```text
FULL → LIGHT
```

Después:

```text
LIGHT → ABSTRACT
```

El sistema registra:

```text
08:00
sale de casa

08:20
llega al trabajo

12:00
almuerzo

13:00
regresa al trabajo

17:00
sale del trabajo
```

El jugador vuelve a las 16:55.

El sistema:

```text
ABSTRACT
↓
LIGHT
↓
FULL
```

El NPC aparece en una posición coherente:

```text
trabajo
```

y continúa su actividad.

---

# 26. Navegación abstracta

No es necesario calcular un pathfinding detallado para un NPC lejano.

Puede utilizarse:

```text
Zona A
↓
Calle principal
↓
Zona B
↓
Destino
```

En lugar de:

```text
pixel
pixel
pixel
pixel
...
```

Esto permite trabajar con el futuro mapa real de Baracoa.

---

# 27. Grafo de zonas

El mundo debe poder representarse mediante zonas conectadas.

Ejemplo:

```text
Zona 01
├── Barrio A
├── Barrio B
├── Centro
└── Costa
```

Y conexiones:

```text
Zona A ↔ Zona B
Zona B ↔ Centro
Centro ↔ Costa
```

El sistema abstracto puede mover entidades entre zonas sin cargar físicamente todo el mapa.

---

# 28. Integración con el mapa de Baracoa

La Zona 01 obtenida desde OpenStreetMap debe poder convertirse en una fuente para:

- calles;
- edificios;
- zonas;
- puntos de interés;
- agua;
- conexiones;
- navegación.

El sistema de simulación NO debe depender de coordenadas hardcodeadas específicas.

Debe trabajar con:

```text
zone_id
road_id
building_id
poi_id
```

cuando sea apropiado.

---

# 29. Vehículos

El mismo sistema debe poder utilizarse posteriormente para vehículos.

Ejemplo:

### FULL

```text
física
colisiones
dirección
velocidad
tráfico
```

### LIGHT

```text
origen
destino
velocidad aproximada
calle actual
progreso
```

### ABSTRACT

```text
08:00 → sale del origen
08:12 → llega al destino
```

Esto permitirá tener tráfico sin simular físicamente todos los vehículos.

---

# 30. Policía

También debe prepararse para una futura IA policial.

Cerca:

```text
FULL
```

Puede incluir:

- persecución;
- navegación;
- detección;
- combate;
- vehículos.

Lejos:

```text
LIGHT / ABSTRACT
```

Puede representar:

```text
patrulla buscando
zona de búsqueda
objetivo
probabilidad de encuentro
```

---

# 31. Combate

Una entidad en combate con el jugador debe recibir alta prioridad.

Regla:

```text
COMBATE ACTIVO
→ FULL
```

aunque normalmente estuviera fuera del rango normal.

Esto evita situaciones absurdas donde un enemigo está luchando con el jugador mientras su IA se degrada.

---

# 32. Interacciones

Las interacciones importantes deben promover temporalmente una entidad.

Ejemplos:

```text
hablar
comerciar
robar
pelear
misión
seguir
ayudar
perseguir
```

Mientras dure la interacción:

```text
entidad → FULL
```

Al finalizar:

```text
FULL → nivel correspondiente
```

---

# 33. Relaciones

Los NPC pueden tener relaciones.

Ejemplo:

```text
NPC A
  └── amistad +70 con NPC B

NPC B
  └── amistad +70 con NPC A
```

Las relaciones deben existir como estado lógico.

No requieren que ambos NPC estén físicamente activos.

Esto permitirá posteriormente:

- amistades;
- enemigos;
- familias;
- compañeros de trabajo;
- grupos;
- reputación.

---

# 34. Necesidades

El sistema puede manejar:

```text
hambre
sed
energía
salud
dinero
```

No todas deben actualizarse cada frame.

Ejemplo:

```text
FULL:
actualización frecuente

LIGHT:
actualización simplificada

ABSTRACT:
actualización matemática por intervalo
```

---

# 35. Economía futura

La simulación abstracta permitirá posteriormente:

```text
NPC trabaja
↓
recibe salario
↓
gasta dinero
↓
compra comida
↓
comercio recibe dinero
```

Esto puede convertirse en una economía urbana.

Pero NO debe implementarse toda la economía ahora.

La arquitectura debe permitirla.

---

# 36. Persistencia

El estado importante de las entidades debe poder guardarse.

Ejemplo:

```text
npc_id
zone_id
location
activity
health
money
inventory
relationships
schedule
last_simulation_time
```

Esto permitirá que el mundo sobreviva entre sesiones.

---

# 37. Simulación offline / tiempo transcurrido

Si el juego necesita continuar después de cerrar la partida, el sistema puede calcular:

```text
tiempo_actual - last_simulation_time
```

y procesar la diferencia mediante simulación abstracta.

Ejemplo:

```text
Guardado:
18:00

Jugador vuelve:
08:00 del día siguiente

Δt = 14 horas
```

No es necesario simular 14 horas a 60 FPS.

Se pueden procesar los eventos relevantes.

---

# 38. Multiplayer

El diseño debe ser compatible con multiplayer desde el principio.

La arquitectura objetivo es:

```text
CLIENTES
   │
   ▼
SERVIDOR
   │
   ├── WorldSimulationManager
   ├── NPC states
   ├── eventos
   ├── economía
   └── mundo
```

El servidor debe ser la autoridad sobre:

- posición válida;
- salud;
- combate;
- inventario;
- dinero;
- NPC;
- eventos importantes;
- estado del mundo.

---

# 39. Simulación y clientes

Un cliente NO debería ser responsable de decidir:

```text
NPC realmente murió
NPC ganó dinero
NPC recibió daño
NPC cambió de trabajo
```

El servidor debe decidir.

El cliente principalmente:

```text
recibe estado
↓
materializa entidades
↓
muestra representación
```

---

# 40. Materialización

Concepto importante:

```text
Estado abstracto
      ↓
Materialización
      ↓
Entidad Godot
```

Ejemplo:

```text
NPCState:
posición = trabajo
actividad = trabajando
salud = 90
```

El sistema crea:

```text
CharacterBody2D
Sprite
CollisionShape
AI controller
```

solo cuando es necesario.

---

# 41. Desmaterialización

Cuando ya no sea necesario:

```text
Entidad Godot
      ↓
extraer estado
      ↓
guardar NPCState
      ↓
liberar representación
```

No se debe perder información importante.

---

# 42. Consistencia

El sistema debe evitar:

```text
estado lógico:
NPC = trabajo

representación:
NPC = casa
```

Debe existir una única fuente de verdad.

---

# 43. Randomness

La aleatoriedad debe utilizarse cuidadosamente.

No debe producir resultados absurdos al volver a una zona.

Cuando sea importante, utilizar:

- semillas;
- RNG controlado;
- estados persistentes.

Especialmente en multiplayer, los resultados importantes deben ser controlables por el servidor.

---

# 44. No convertir el sistema en una simulación científica

El objetivo NO es simular absolutamente todo.

No hace falta simular:

```text
cada paso
cada respiración
cada hoja
cada objeto
```

La simulación debe ser:

```text
suficientemente convincente
+
barata
+
estable
```

La ilusión de un mundo vivo es más importante que la precisión física absoluta.

---

# 45. Prioridad de simulación

Orden recomendado:

```text
1. Combate activo
2. Interacción directa
3. Misiones
4. Entidades importantes
5. Entidades cercanas
6. Entidades de la misma zona
7. Entidades lejanas
8. Entidades completamente abstractas
```

Esto puede evolucionar posteriormente hacia un sistema de scoring.

---

# 46. Ejemplo de población

Para una población hipotética:

```text
1000 NPC
```

No significa:

```text
1000 NPC con física completa
```

Podría ser conceptualmente:

```text
30 FULL
100 LIGHT
870 ABSTRACT
```

Los valores son ejemplos, NO límites definitivos.

La cantidad debe adaptarse al hardware y al servidor.

---

# 47. Adaptación a hardware débil

El sistema debe estar diseñado pensando en hardware modesto.

Prioridades:

- pocas operaciones por frame;
- evitar pathfinding innecesario;
- evitar crear/destruir nodos continuamente;
- reutilizar objetos cuando sea posible;
- actualizar entidades por lotes;
- usar eventos;
- usar timers;
- usar simulación abstracta;
- evitar loops globales costosos.

El sistema no debe recorrer miles de entidades completas cada frame sin necesidad.

---

# 48. Actualización por lotes

En lugar de:

```text
for every NPC:
    simulate_everything()
```

preferir:

```text
procesar lote FULL
procesar lote LIGHT
procesar eventos ABSTRACT
```

y distribuir trabajo cuando sea apropiado.

---

# 49. Object Pooling

Cuando se materialicen y desmaterialicen entidades frecuentemente, considerar pooling.

Ejemplo:

```text
NPC visual #1
NPC visual #2
NPC visual #3
```

pueden reutilizarse para representar distintos NPC.

No implementar pooling innecesariamente antes de medir.

Debe introducirse solo si los perfiles de rendimiento demuestran que es necesario.

---

# 50. No optimizar a ciegas

Regla:

> Medir antes de optimizar.

El sistema debe incluir herramientas simples de profiling o métricas.

Medir:

```text
NPC FULL
NPC LIGHT
NPC ABSTRACT
eventos/segundo
tiempo de simulación
FPS
uso de CPU
cantidad de entidades materializadas
```

---

# 51. Debug Overlay

Durante desarrollo sería conveniente tener una herramienta visual que muestre:

```text
FULL: 25
LIGHT: 83
ABSTRACT: 892
```

Y opcionalmente colores de depuración:

```text
FULL     → rojo
LIGHT    → amarillo
ABSTRACT → azul
```

Estos colores son exclusivamente de debug y no forman parte del estilo final del juego.

También podría mostrar:

```text
Entity ID
Zone
Activity
Simulation Level
Distance
Relevance
```

---

# 52. Logs

Debe ser posible registrar eventos importantes:

```text
NPC 102:
FULL → LIGHT

NPC 102:
LIGHT → ABSTRACT

NPC 102:
ABSTRACT → LIGHT

NPC 102:
LIGHT → FULL
```

Esto será muy útil para depurar problemas de consistencia.

---

# 53. Estados de simulación

Se recomienda utilizar un enum o sistema equivalente:

```text
FULL
LIGHT
ABSTRACT
```

No utilizar strings arbitrarios por todo el proyecto.

---

# 54. Interfaces / contratos

La arquitectura debe permitir algo parecido a:

```text
ISimulationHandler
```

con operaciones conceptuales:

```text
enter(entity)
simulate(entity, delta)
exit(entity)
```

Cada nivel puede tener su propio handler:

```text
FullSimulationHandler
LightSimulationHandler
AbstractSimulationHandler
```

No es obligatorio utilizar exactamente esos nombres.

Lo importante es separar responsabilidades.

---

# 55. Regla de diseño importante

El sistema de simulación NO debe conocer detalles innecesarios de cada NPC.

Evitar:

```text
SimulationManager:
    if npc.type == ...
    if npc.job == ...
    if npc.weapon == ...
    if npc...
```

Demasiadas condiciones crearían un sistema imposible de mantener.

Preferir:

```text
Entidad
→ proporciona estado
→ proporciona comportamiento de simulación
```

---

# 56. Arquitectura orientada a componentes

Siempre que sea razonable, separar:

```text
Health
Needs
Inventory
Schedule
Relationships
Movement
Combat
Economy
Simulation
```

Así un NPC no necesita tener todas las capacidades.

---

# 57. Schedule System

El sistema de horarios debe ser independiente de FULL/LIGHT/ABSTRACT.

Ejemplo:

```text
Schedule
07:30 WakeUp
08:00 LeaveHome
08:20 Work
12:00 Lunch
13:00 Work
17:00 LeaveWork
17:30 Home
```

En FULL:

```text
el NPC físicamente ejecuta el horario.
```

En ABSTRACT:

```text
el sistema transforma el horario en eventos.
```

---

# 58. Urban ecosystem

El término conceptual para esta arquitectura será:

> **Baracoa Living World**

No significa necesariamente que el juego deba utilizar esta frase públicamente.

Es el nombre conceptual del sistema.

El objetivo es que Baracoa parezca una ciudad que funciona aunque el jugador no esté mirando.

---

# 59. Ejemplo de mundo vivo

Jugador está en el centro.

Mientras juega:

```text
NPC A trabaja
NPC B compra comida
NPC C camina
NPC D discute
NPC E conduce
NPC F patrulla
NPC G descansa
```

El jugador se va a otra zona.

Los NPC no desaparecen conceptualmente.

Pasan a:

```text
LIGHT
```

o:

```text
ABSTRACT
```

y siguen evolucionando.

Cuando el jugador vuelve:

```text
el mundo refleja lo que ocurrió.
```

---

# 60. Eventos emergentes

Una ventaja importante será permitir eventos no guionizados.

Ejemplo:

```text
NPC A
↓
pierde dinero

NPC A
↓
no puede comprar comida

NPC A
↓
busca trabajo extra

NPC B
↓
le ofrece trabajo

NPC A
↓
acepta

resultado:
cambia su horario
cambia su dinero
cambia su relación con NPC B
```

No es necesario programar cada historia manualmente.

---

# 61. Eventos con consecuencias

Los eventos deben poder modificar estado.

Ejemplo:

```text
FIGHT_STARTED
↓
health -= damage

FIGHT_FINISHED
↓
relationship -= 10

PURCHASE
↓
money -= price
inventory += item
```

La simulación abstracta puede utilizar versiones simplificadas de estos eventos.

---

# 62. Diferencia entre simulación y gameplay

No confundir:

```text
simulación del mundo
```

con:

```text
gameplay específico
```

La simulación proporciona el estado del mundo.

El gameplay utiliza ese estado.

---

# 63. Regla de oro de implementación

No implementar todo inmediatamente.

Orden recomendado:

### Fase 1

Crear:

```text
WorldEntity
NPCState
SimulationLevel
WorldSimulationManager
```

### Fase 2

Implementar:

```text
FULL
```

### Fase 3

Implementar:

```text
FULL ↔ LIGHT
```

### Fase 4

Implementar:

```text
LIGHT ↔ ABSTRACT
```

### Fase 5

Agregar:

```text
SimulationClock
EventQueue
```

### Fase 6

Integrar:

```text
Zones
```

### Fase 7

Integrar:

```text
NPC schedules
```

### Fase 8

Integrar:

```text
vehicles
police
economy
```

### Fase 9

Optimizar con profiling.

### Fase 10

Integrar profundamente con multiplayer.

---

# 64. MVP mínimo

El MVP de este sistema NO necesita:

- economía completa;
- vehículos;
- policía;
- relaciones complejas;
- clima;
- miles de NPC;
- persistencia avanzada;
- multiplayer completo.

Debe demostrar únicamente:

```text
NPC
↓
FULL
↓
alejar jugador
↓
LIGHT
↓
más lejos
↓
ABSTRACT
↓
pasa tiempo
↓
jugador regresa
↓
LIGHT
↓
FULL
```

Y el NPC debe conservar un estado coherente.

---

# 65. Prueba mínima obligatoria

Crear una prueba con varios NPC.

Ejemplo:

```text
NPC 1
NPC 2
NPC 3
NPC 4
NPC 5
```

Cada uno tiene:

```text
posición
actividad
energía
salud
```

Mover al jugador lejos.

Verificar:

```text
FULL → LIGHT → ABSTRACT
```

Mover al jugador de regreso.

Verificar:

```text
ABSTRACT → LIGHT → FULL
```

Comprobar que:

```text
actividad
salud
energía
posición lógica
```

siguen siendo coherentes.

---

# 66. Prueba de tiempo

Ejemplo:

```text
NPC:
08:00 trabajo
12:00 comida
17:00 casa
```

Alejar jugador.

Avanzar reloj.

Volver.

Comprobar que el NPC esté realizando la actividad correspondiente a la hora.

---

# 67. Prueba de combate

NPC cercano:

```text
FULL
```

Se inicia combate.

Debe permanecer:

```text
FULL
```

aunque el sistema de distancia normalmente quisiera degradarlo.

Al finalizar:

```text
volver al nivel apropiado.
```

---

# 68. Prueba de relevancia

NPC lejano pero asociado a una misión:

```text
relevancia alta
```

Debe poder recibir un nivel superior al que tendría solamente por distancia.

---

# 69. Prueba de rendimiento

Crear progresivamente:

```text
10 NPC
50 NPC
100 NPC
500 NPC
1000 NPC
```

No asumir que todos deben ejecutarse FULL.

Medir cómo cambia:

```text
CPU
FPS
memoria
tiempo de simulación
```

---

# 70. Integración con la arquitectura existente

Antes de crear archivos nuevos, la IA debe:

1. inspeccionar la arquitectura actual;
2. localizar sistemas de NPC;
3. localizar sistema de mundo;
4. localizar movimiento;
5. localizar navegación;
6. localizar multiplayer;
7. localizar persistencia;
8. localizar configuración;
9. determinar qué ya existe;
10. reutilizar lo existente.

NO duplicar sistemas.

---

# 71. Regla para OpenCode / IA programadora

La IA que trabaje en el proyecto debe:

### Antes de modificar

```text
1. inspeccionar;
2. entender;
3. mapear dependencias;
4. identificar código reutilizable;
5. proponer cambios;
6. implementar incrementalmente.
```

No debe comenzar creando decenas de archivos sin analizar el proyecto.

---

# 72. Evitar sobreingeniería

No crear:

```text
20 interfaces
30 managers
10 factories
```

solo porque el diseño lo permite.

Crear únicamente las abstracciones necesarias.

La arquitectura debe ser:

```text
limpia
+
simple
+
extensible
```

---

# 73. Compatibilidad con el mapa OSM

La fuente geográfica actual de la Zona 01 debe mantenerse separada de la lógica de simulación.

Conceptualmente:

```text
OSM
 ↓
Procesamiento geográfico
 ↓
Datos técnicos del mundo
 ↓
Godot World
 ↓
Simulation System
```

El sistema de simulación no debe leer directamente el XML de OSM.

---

# 74. Datos del mundo

El sistema debería poder trabajar con datos como:

```text
zones.json
roads.json
buildings.json
places.json
water.json
```

y posteriormente:

```text
navigation_graph.json
```

Estos datos son infraestructura del mundo.

---

# 75. Futuro crecimiento

El sistema debe permitir pasar de:

```text
Zona 01
```

a:

```text
Zona 01
Zona 02
Zona 03
...
```

sin cambiar la lógica central.

Idealmente:

```text
SimulationManager
```

no debería saber si una entidad está en:

```text
Zona 01
```

o:

```text
Zona 87
```

---

# 76. Transición entre zonas

Una entidad puede moverse:

```text
Zona A
↓
Zona B
```

Si ambas están cargadas:

```text
movimiento normal
```

Si la zona está lejos:

```text
transición abstracta
```

Ejemplo:

```text
08:00
sale de Zona A

08:15
llega a Zona B
```

No hace falta cargar ambas zonas gráficamente.

---

# 77. Un mundo enorme sin cargarlo entero

Esta arquitectura permite que el mapa sea grande aunque el jugador no tenga todo cargado.

Conceptualmente:

```text
MUNDO COMPLETO
─────────────────────────────
│ ABSTRACT                  │
│                           │
│    ┌───────────────┐      │
│    │ LIGHT         │      │
│    │               │      │
│    │   ┌───────┐   │      │
│    │   │ FULL  │   │      │
│    │   │PLAYER │   │      │
│    │   └───────┘   │      │
│    └───────────────┘      │
─────────────────────────────
```

Esto será fundamental para ampliar Baracoa progresivamente.

---

# 78. Principio de escalabilidad

La pregunta no debe ser:

> "¿Podemos simular 1000 NPC?"

La pregunta correcta es:

> "¿Cuántos NPC necesitan realmente simulación detallada en este momento?"

La mayoría de las entidades pueden existir de manera abstracta.

---

# 79. Seguridad multiplayer

Nunca confiar en estados enviados por clientes para decisiones importantes.

El servidor debe validar:

```text
posición
daño
dinero
inventario
interacciones
eventos
NPC
```

La simulación abstracta crítica debe ejecutarse en servidor.

---

# 80. Desconexión de jugadores

Si un jugador abandona:

```text
sus entidades cercanas
```

pueden degradarse.

No debe detenerse necesariamente el mundo.

El servidor continúa simulando el estado global según necesidad.

---

# 81. Reconexión

Al reconectarse:

```text
cliente
↓
servidor
↓
estado actual
↓
materialización
```

El jugador debe recibir el estado actual del mundo relevante para él.

---

# 82. Regla de autoridad

En multiplayer:

```text
SERVER
   ↓
WorldSimulationManager
   ↓
WorldEntity state
   ↓
CLIENT
```

No:

```text
CLIENT
   ↓
decide mundo
```

---

# 83. Configuración

Los valores deben ser configurables.

Ejemplos:

```text
full_radius
light_radius
abstract_radius
full_priority
light_update_interval
abstract_update_interval
max_full_entities
max_light_entities
```

Los nombres son orientativos.

---

# 84. No fijar números prematuramente

No asumir desde ahora:

```text
FULL = 100 metros
LIGHT = 500 metros
```

Esos valores deben determinarse mediante pruebas.

La configuración debe permitir modificarlos fácilmente.

---

# 85. Telemetría de desarrollo

Registrar métricas como:

```text
entities_total
entities_full
entities_light
entities_abstract
simulation_ms
event_queue_size
materialized_entities
```

Esto permitirá detectar cuellos de botella.

---

# 86. Debug commands

Si es posible, incluir comandos de desarrollo como:

```text
spawn_npc
set_simulation_level
advance_time
teleport_player
show_simulation_stats
force_abstract
force_full
```

No tienen que existir en la versión final.

---

# 87. Arquitectura conceptual final

```text
                    WORLD
                      │
             WorldSimulationManager
                      │
       ┌──────────────┼──────────────┐
       │              │              │
     FULL           LIGHT         ABSTRACT
       │              │              │
   AI completa    AI ligera       eventos
   física         estado          horarios
   navegación     aproximado      matemática
   combate        posición        resultados
       │              │              │
       └──────────────┼──────────────┘
                      │
                  WorldEntity
                      │
                   NPCState
                      │
             Persistence Layer
```

---

# 88. Resultado esperado

Cuando este sistema esté terminado, el jugador debería experimentar algo parecido a:

> "No parece que el mundo exista solo cuando estoy mirando."

En cambio:

```text
el mundo tiene memoria
el mundo tiene tiempo
el mundo tiene estados
el mundo tiene eventos
el mundo tiene consecuencias
```

El jugador simplemente observa una parte de ese mundo.

---

# 89. Regla fundamental del proyecto

Toda nueva característica futura debe preguntarse:

> ¿Puede funcionar con el sistema de simulación progresiva?

Ejemplos:

### NPC

Sí.

### Vehículos

Sí.

### Policía

Sí.

### Animales

Sí.

### Comercios

Sí.

### Economía

Sí.

### Misiones

Sí.

### Clima

Sí.

### Relaciones

Sí.

### Eventos

Sí.

Esto debe convertirse en una de las bases arquitectónicas del proyecto.

---

# 90. Instrucciones específicas para la IA programadora

Al implementar este documento:

1. **No reescribir el proyecto completo.**
2. Inspeccionar primero la arquitectura actual.
3. Identificar qué sistemas ya existen.
4. Reutilizar componentes existentes.
5. Implementar el sistema incrementalmente.
6. Mantener compatibilidad con el MVP.
7. No introducir dependencias innecesarias.
8. No añadir sistemas de persistencia complejos antes de necesitarlos.
9. No implementar multiplayer completo únicamente por este documento si todavía no corresponde a la fase actual.
10. Mantener separación entre estado lógico y representación visual.
11. Mantener la posibilidad de utilizar el sistema en servidor.
12. Evitar hardcodear radios y límites.
13. Añadir configuración.
14. Añadir pruebas.
15. Añadir herramientas de debug.
16. Medir rendimiento antes de realizar optimizaciones complejas.
17. Documentar cualquier decisión arquitectónica importante.
18. Si existe conflicto entre este documento y la arquitectura actual, inspeccionar primero y proponer la adaptación mínima necesaria.
19. No eliminar funcionalidades existentes sin justificarlo.
20. No implementar características futuras que no sean necesarias para validar la arquitectura.

---

# 91. Definition of Done

El sistema se considera inicialmente implementado cuando:

- [ ] Existe una representación lógica de una entidad.
- [ ] Existe estado independiente de la representación visual.
- [ ] Existe `FULL`.
- [ ] Existe `LIGHT`.
- [ ] Existe `ABSTRACT`.
- [ ] Las entidades pueden cambiar entre niveles.
- [ ] El cambio no pierde estado.
- [ ] Existe un reloj lógico.
- [ ] Existe una forma básica de eventos.
- [ ] Un NPC puede continuar su actividad mientras está ABSTRACT.
- [ ] El NPC puede volver a FULL de forma coherente.
- [ ] Combate e interacción pueden forzar FULL.
- [ ] Existe un mecanismo inicial de relevancia.
- [ ] Los valores importantes son configurables.
- [ ] Existe información de debug.
- [ ] Hay pruebas básicas de transición.
- [ ] Hay pruebas de avance temporal.
- [ ] El sistema no rompe el MVP existente.
- [ ] La arquitectura queda preparada para futuras zonas de Baracoa.
- [ ] La arquitectura queda preparada para futura simulación server-authoritative.

---

# 92. Lo que NO debe hacerse todavía

No implementar automáticamente:

- una economía completa;
- miles de NPC reales;
- IA policial avanzada;
- tráfico completo;
- sistema social completo;
- clima complejo;
- persistencia online definitiva;
- matchmaking;
- servidores distribuidos;
- microservicios;
- base de datos definitiva para todo;
- optimizaciones prematuras;
- un sistema gigantesco de ECS si no es necesario.

Primero demostrar el concepto con una implementación pequeña y limpia.

---

# 93. Prioridad absoluta

La prioridad es:

```text
CORRECCIÓN
>
COHERENCIA
>
RENDIMIENTO
>
ESCALABILIDAD
>
COMPLEJIDAD
```

No buscar la arquitectura más sofisticada.

Buscar la arquitectura más sencilla que permita crecer correctamente.

---

# 94. Visión a largo plazo

El objetivo final es que el jugador pueda recorrer Baracoa y sentir que está dentro de una ciudad que tiene vida propia.

No solo:

```text
mapa
+
NPC decorativos
```

sino:

```text
CIUDAD
+
PERSONAS
+
HORARIOS
+
TRABAJO
+
RELACIONES
+
DINERO
+
TRANSPORTE
+
EVENTOS
+
CONSECUENCIAS
+
TIEMPO
```

Todo ello funcionando mediante distintos niveles de simulación.

---

# 95. Frase arquitectónica del sistema

> **"No simulamos todo con el mismo nivel de detalle. Simulamos cada cosa con el nivel de detalle que realmente necesita."**

Y para el mundo de Baracoa:

> **"El jugador no crea la vida del mundo; entra en un mundo que ya está viviendo."**

---

## FIN DEL DOCUMENTO

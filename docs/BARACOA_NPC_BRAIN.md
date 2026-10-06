# BARACOA NPC BRAIN
## Arquitectura de inteligencia artificial realista y optimizada para NPC

> **Objetivo:** máximo realismo percibido con el mínimo coste computacional posible.

## 1. Principio central

No se debe intentar simular una mente humana completa ni usar un LLM para cada NPC. El comportamiento debe emerger de sistemas baratos y combinables:

```text
Estado + necesidades + personalidad + percepción + conocimiento
        + memoria + objetivos + Utility AI + planificación
        + comportamiento + eventos
```

La regla principal es:

> **El NPC debe gastar CPU proporcionalmente a la importancia de lo que está haciendo, no proporcionalmente a su existencia.**

Prioridades del proyecto:

1. Optimización
2. Estabilidad
3. Coherencia
4. Realismo percibido
5. Escalabilidad
6. Complejidad

---

# 2. Arquitectura general

```text
NPC
├── Identity
├── Personality
├── Needs
├── Emotions
├── Perception
├── Knowledge
├── Memory
├── Relationships
├── Goals
├── Utility AI
├── GOAP / Planner
├── Behavior Executor
├── Schedule
└── Simulation Adapter
```

Todo coordinado por `WorldSimulationManager`.

El cerebro lógico debe estar separado del cuerpo visual. Un NPC ABSTRACT puede existir como datos sin `CharacterBody2D`, sprites, físicas ni animaciones.

```text
NPCState
   ↓
WorldSimulationManager
   ↓
FULL / LIGHT / ABSTRACT
   ↓
Representación Godot cuando sea necesaria
```

---

# 3. Personalidad

Usar pocos rasgos numéricos, por ejemplo:

```text
agresividad
paciencia
disciplina
sociabilidad
honestidad
valentía
curiosidad
generosidad
prudencia
impulsividad
```

Normalizar a `0.0–1.0`. Empezar con 8–12 rasgos y añadir más solo si aportan comportamiento observable.

La personalidad modifica probabilidades y utilidades; no debe convertirse en cientos de variables.

---

# 4. Necesidades

Base:

```text
hambre
sed
energía/sueño
salud
seguridad
socialización
diversión
dinero
```

No actualizar cada necesidad cada frame. Guardar `last_update` y calcular el cambio según el tiempo transcurrido.

Ejemplo:

```text
hambre += tasa_hambre × delta_horas
energía -= tasa_energía × delta_horas
```

En ABSTRACT esto permite simular horas o días mediante matemáticas y eventos, sin ejecutar miles de frames.

---

# 5. Objetivos

Separar objetivos persistentes y temporales.

Persistentes:

```text
mantener empleo
tener vivienda
ganar dinero
cuidar familia
```

Temporales:

```text
comer
dormir
trabajar
volver a casa
huir
comprar
socializar
```

---

# 6. Utility AI

Utility AI responde:

> **¿Qué debería importarle al NPC ahora?**

Ejemplo:

```text
Comer       0.82
Trabajar    0.60
Dormir      0.41
Socializar  0.25
Explorar    0.10
```

La puntuación debe depender de necesidades, personalidad, contexto, relaciones, peligro, horario y recursos.

No ejecutar la decisión cada frame. Usar cooldowns y reevaluar solo cuando sea necesario.

Para evitar comportamientos robóticos, utilizar umbrales, prioridades y pequeñas variaciones controladas, no solamente `max(utility)` permanentemente.

---

# 7. GOAP

GOAP responde:

> **¿Cómo consigo el objetivo elegido?**

Ejemplo:

```text
Objetivo: comer
        ↓
no hay comida
        ↓
conseguir dinero
        ↓
ir a tienda
        ↓
comprar comida
        ↓
comer
```

Cada acción tiene:

```text
preconditions
effects
cost
```

No ejecutar GOAP continuamente. Replanificar cuando cambie el objetivo, falle el plan, cambie una condición importante o aparezca/desaparezca un recurso.

Guardar el plan actual y reutilizarlo mientras siga siendo válido.

---

# 8. Behavior Executor

GOAP decide el plan; otra capa ejecuta acciones concretas:

```text
caminar
comer
trabajar
hablar
huir
atacar
comprar
dormir
```

En FULL puede utilizarse Behavior Tree para comportamientos complejos y State Machines para estados simples como `idle`, `walking`, `working`, `sleeping`, `combat`.

No hacer que una única técnica controle todo.

---

# 9. Percepción

La percepción debe ser escalonada y barata.

Barata:

```text
distancia
zona
eventos
```

Moderada:

```text
campo visual
línea de visión
raycast
sonido
```

Cara:

```text
análisis detallado
pathfinding complejo
```

La percepción cara solo debe utilizarse cuando la entidad está en FULL o es relevante.

Preferir eventos a polling.

Malo:

```text
cada NPC, cada frame: "¿hay una pelea?"
```

Bueno:

```text
COMBAT_STARTED
↓
notificar NPC relevantes
```

---

# 10. World Truth vs NPC Knowledge

Debe existir una separación estricta entre:

```text
WORLD TRUTH
```

y:

```text
NPC KNOWLEDGE
```

Ejemplo:

```text
WORLD:
Jugador está en Calle A.

NPC:
No sabe dónde está.
```

Un NPC solo puede actuar con información que haya percibido, recibido o inferido.

Cada conocimiento puede guardar:

```text
subject_id
content/type
confidence
source
timestamp
```

Fuentes posibles:

```text
direct
observed
heard
told_by_npc
official
inferred
```

Esto evita policías o NPC que parecen omniscientes.

---

# 11. Memoria

La memoria debe ser selectiva y estructurada.

Categorías:

```text
Short-Term Memory
Episodic Memory
Social Memory
Spatial Memory
Important Memory
```

No guardar conversaciones completas ni texto innecesario. Preferir estructuras compactas:

```text
event_type
subject_id
location_id
confidence
importance
timestamp
```

Ejemplo:

```text
witnessed_crime
subject = player_42
location = street_12
confidence = 0.8
importance = 0.7
```

---

# 12. Memoria con importancia y decay

Cada memoria tiene una importancia aproximada.

```text
comprar pan        → baja
ver un accidente   → media
ser atacado        → alta
```

Las memorias de baja importancia pierden fuerza con el tiempo. Las importantes pueden persistir durante mucho más tiempo.

No almacenar indefinidamente todo.

---

# 13. Consolidación de memoria

Si se repite un evento, convertir recuerdos individuales en conocimiento agregado.

Ejemplo:

```text
asaltos repetidos en Zona 03
↓
DangerScore[Zona_03] = 0.82
```

Esto ahorra memoria y permite aprendizaje.

El NPC puede modificar sus decisiones:

```text
zona peligrosa
↓
ruta habitual pierde utilidad
↓
ruta alternativa gana utilidad
```

---

# 14. Memoria social

Guardar relaciones solo con personas relevantes, no una matriz completa `N × N`.

Ejemplo:

```text
NPC A
├── NPC B → amistad 80
├── NPC C → miedo 60
└── Player → confianza 15
```

Variables posibles:

```text
trust
friendship
fear
respect
hostility
```

Las relaciones cambian por eventos.

```text
ayuda → confianza +
robo → confianza --
traición → hostilidad ++
```

---

# 15. Emociones

Usar estados simples y baratos:

```text
miedo
ira
alegría
tristeza
estrés
confianza
```

No simular psicología completa.

Las emociones modifican Utility AI y comportamiento.

Ejemplo:

```text
miedo ↑ → evitar zona/persona
ira ↑ → mayor probabilidad de confrontar
```

Un evento puede modificar simultáneamente emoción, memoria y conocimiento.

---

# 16. Trabajo real

Los trabajos NO deben ser solamente animaciones.

Cada profesión debe tener conceptualmente:

```text
Occupation
├── schedule
├── workplace
├── tasks
├── required_skills
├── production
├── salary
└── dependencies
```

Ejemplo de tienda:

```text
abre
↓
atiende clientes
↓
vende productos
↓
inventario -1
↓
dinero +precio
↓
stock bajo
↓
genera pedido
↓
recibe mercancía
```

En FULL se puede representar físicamente.

En ABSTRACT:

```text
ventas/hora
producción/hora
salario/hora
```

Se calcula el resultado directamente.

---

# 17. Realismo funcional

No simular detalles que no cambien estado, decisiones o experiencia.

No necesitamos simular cada movimiento de un cajero.

Sí necesitamos simular:

```text
venta
stock
salario
dinero
```

Regla:

> **Causa → decisión → consecuencia es más importante que detalle físico invisible.**

---

# 18. Policía realista

La policía debe trabajar con un sistema de incidentes.

```text
CrimeIncident
├── type
├── location
├── time
├── witnesses
├── evidence
├── suspect_description
├── severity
└── status
```

Flujo:

```text
delito
↓
testigo lo percibe
↓
testigo decide si reporta
↓
se crea incidente
↓
policía recibe información
↓
investiga
↓
obtiene pistas
↓
localiza sospechoso
↓
interviene
```

La policía no debe recibir mágicamente la ubicación exacta del jugador.

Un testigo puede recordar una descripción imperfecta.

---

# 19. Policía y simulación progresiva

Lejos:

```text
investigación abstracta
09:10 recibe reporte
09:25 entrevista testigo
09:40 obtiene pista
```

Cerca:

```text
percepción
navegación
persecución
combate
detención
```

Un policía en combate o interacción directa debe recibir prioridad FULL.

---

# 20. NPC callejeros

Los NPC comunes deben tener:

```text
casa
rutina
trabajo
necesidades
preferencias
memoria limitada
relaciones relevantes
```

Pero no todos deben tener el mismo coste.

Tres categorías prácticas:

### Background
Muy barato; memoria y planificación mínimas.

### Normal
Sistema completo limitado.

### Importante
Memoria profunda, relaciones, misiones y planificación más compleja.

---

# 21. Mental LOD

Así como existe LOD gráfico, habrá LOD mental.

```text
Mental LOD 0 = FULL
Mental LOD 1 = LIGHT
Mental LOD 2 = ABSTRACT
Mental LOD 3 = estado estadístico/eventos
```

### FULL

Puede utilizar:

```text
percepción
Utility AI
GOAP
Behavior
memoria
emociones
navegación
```

pero incluso aquí nada debe ejecutarse innecesariamente cada frame.

### LIGHT

```text
necesidades
objetivo
plan simplificado
movimiento abstracto
eventos
memoria importante
```

### ABSTRACT

```text
horarios
necesidades matemáticas
eventos
producción
economía
relaciones importantes
memorias agregadas
```

Sin física, animación ni colisiones.

---

# 22. Decision cooldown y time slicing

Los NPC no deben decidir 60 veces por segundo.

Usar intervalos configurables según relevancia y simulación.

Las tareas pueden distribuirse:

```text
100 NPC pendientes
↓
20
20
20
20
20
```

en distintos ciclos, respetando un presupuesto de CPU.

---

# 23. Presupuesto de CPU

El sistema debe tener un presupuesto de IA.

Conceptualmente:

```text
AI budget = X ms
```

Si se supera:

```text
posponer tareas no críticas
reducir frecuencia
bajar LOD
```

Prioridad:

```text
combate
interacción
misión
NPC cercano
NPC importante
NPC normal
NPC lejano
```

No establecer números definitivos hasta hacer profiling.

---

# 24. Eventos sobre polling

Todo lo que pueda resolverse mediante eventos debe hacerlo así.

Ejemplos:

```text
PLAYER_ENTERED_ZONE
COMBAT_STARTED
ITEM_BOUGHT
JOB_STARTED
JOB_FINISHED
NPC_DIED
CRIME_REPORTED
WEATHER_CHANGED
```

Los eventos solo despiertan a los sistemas afectados.

---

# 25. Cache y reutilización

Cachear cuando sea válido:

```text
rutas
planes
lugares conocidos
datos estáticos
```

No recalcular rutas constantemente.

Una ruta puede depender de:

```text
origen
destino
versión del mapa
```

Si no cambió nada relevante, reutilizarla.

---

# 26. Spatial partitioning

No consultar todos los NPC del mundo para saber quién está cerca.

Usar posteriormente una estructura como:

```text
Grid
Spatial Hash
Quadtree
```

y combinarla con zonas de Baracoa.

```text
mundo
↓
zona
↓
subzona
↓
entidades cercanas
↓
filtrado por relevancia
```

---

# 27. Datos ABSTRACT

Los NPC ABSTRACT deben mantenerse como datos compactos, no como miles de nodos Godot.

Ejemplo:

```text
NPCState
├── id
├── zone_id
├── position/progress
├── activity
├── needs
├── money
├── schedule_state
├── goal
├── important_memory_summary
└── last_simulation_time
```

---

# 28. Streaming y materialización

```text
estado lógico
↓
materialización
↓
CharacterBody2D + representación
```

Al alejarse:

```text
representación
↓
extraer estado
↓
desmaterializar
↓
continuar simulación abstracta
```

No perder estado.

---

# 29. Ejemplo de NPC completo

NPC: María

```text
trabajo = tienda
casa = zona_03
dinero = 350
hambre = 0.70
energía = 0.80
miedo = 0.10
```

Personalidad:

```text
disciplina = 0.90
prudencia = 0.80
sociabilidad = 0.60
```

Horario:

```text
06:30 despertar
07:30 trabajo
12:00 almuerzo
17:00 casa
22:00 dormir
```

Presencia de un robo:

```text
percepción directa
↓
memoria importance = 90
↓
fear + 0.5
↓
knowledge: zona peligrosa
↓
Utility modifica rutas
```

Al día siguiente puede elegir una ruta alternativa sin que nadie le haya escrito una regla específica para ese robo.

---

# 30. Ejemplo de trabajador productivo

```text
NPC trabajador
↓
trabaja 4 horas
↓
produce 20 unidades
↓
recibe salario
↓
stock aumenta
↓
mercado puede vender
↓
otros NPC consumen
```

Lejos, el resultado se calcula matemáticamente.

Cerca, el jugador puede observar las acciones físicamente.

---

# 31. Economía abstracta

Una tienda puede mantener:

```text
stock
precio
ventas promedio
salarios
pedidos
```

Si pasan 5 horas en ABSTRACT:

```text
ventas ≈ ventas_por_hora × 5
```

El objetivo es conservar consecuencias, no simular cada cliente invisible.

---

# 32. NPC y multiplayer

Objetivo arquitectónico:

```text
SERVER
├── NPCState
├── Memory
├── Knowledge
├── Goals
├── Simulation
├── Economy
└── Events
      ↓
CLIENT
└── Representation
```

El servidor es autoridad sobre decisiones importantes.

No enviar al cliente memoria completa, personalidad completa ni historial completo si no son necesarios.

---

# 33. LLM opcional

No usar LLM por NPC.

Un LLM podría utilizarse en el futuro únicamente para:

```text
diálogos especiales
NPC importantes
contenido narrativo
```

El modelo nunca debe controlar directamente:

```text
dinero
salud
inventario
daño
posición
```

El juego valida las consecuencias.

---

# 34. Optimización específica para 4 GB

El proyecto debe asumir hardware modesto.

Evitar:

- IA pesada por NPC.
- GOAP cada frame.
- percepción completa cada frame.
- nodos Godot para NPC ABSTRACT.
- relaciones N×N.
- rutas recalculadas constantemente.
- polling global.
- allocations excesivas en loops de IA.
- multithreading prematuro.
- sistemas complejos sin profiling.

Preferir:

```text
eventos
timers
time slicing
cache
LOD mental
estado compacto
streaming
spatial partitioning
simulación matemática
```

---

# 35. Realismo perceptual

El sistema no necesita ser científicamente perfecto.

Debe ser coherente.

El jugador tolerará simplificaciones; no tolerará fácilmente:

```text
NPC que aparece de la nada
NPC que atraviesa paredes
policía omnisciente
trabajos sin consecuencias
NPC que olvida inmediatamente un acontecimiento importante
```

Por tanto:

> **Coherencia > complejidad.**

---

# 36. Regla de mínima simulación necesaria

Para cada comportamiento preguntar:

> ¿Cuál es la menor cantidad de información que necesito para producirlo de forma convincente?

Ejemplo de trabajador lejano:

No hace falta:

```text
posición exacta por frame
```

Sí hace falta:

```text
trabajo
lugar
horario
duración
producción
salario
```

---

# 37. Regla de máxima calidad donde importa

```text
jugador / entidades relevantes
→ máxima calidad

cercanos
→ calidad intermedia

lejanos
→ abstractos
```

---

# 38. Pruebas obligatorias

Crear tests para:

### Needs
El hambre aumenta correctamente con tiempo.

### Memory
Una memoria importante persiste.

### Decay
Una memoria común pierde importancia.

### Utility
Hambre alta aumenta utilidad de comer.

### GOAP
Sin comida, el NPC puede encontrar un plan para conseguirla.

### Knowledge
Un NPC no conoce información que nunca recibió.

### Work
Una profesión modifica producción/dinero/stock.

### Police
Un policía trabaja con información imperfecta.

### Simulation
`FULL → LIGHT → ABSTRACT → FULL` conserva estado.

### Determinismo
Una seed fija permite reproducir un comportamiento para depuración.

---

# 39. Debug del cerebro

Debe existir una herramienta de desarrollo para seleccionar un NPC y ver:

```text
ID
simulation level
needs
goal
current plan
current action
emotion
memory count
knowledge count
relationships
job
schedule
```

Un Decision Debugger debe mostrar algo como:

```text
Comer       0.82
Trabajar    0.63
Dormir      0.31
Socializar  0.20
```

Un Memory Debugger:

```text
[90] robo en zona 03
[60] conversación con NPC 21
[10] compra de pan
```

Un Knowledge Debugger:

```text
Jugador: ubicación aproximada, confidence 0.70
Zona 03: peligrosa, confidence 0.90
```

---

# 40. Benchmark

Probar progresivamente:

```text
50 NPC
100 NPC
250 NPC
500 NPC
1000 NPC
```

Medir:

```text
FPS
RAM
CPU
AI time
FULL count
LIGHT count
ABSTRACT count
event queue size
materialized entities
```

No fijar límites definitivos antes de medir en el hardware objetivo.

---

# 41. Graceful degradation

Si aumenta la carga:

```text
1. posponer tareas no críticas
2. reducir frecuencia de decisiones
3. reducir frecuencia de percepción
4. degradar entidades
5. mantener solamente consecuencias importantes
```

Nunca sacrificar estabilidad por simulación innecesaria.

---

# 42. Arquitectura final

```text
                    NPC BRAIN
                        │
       ┌────────────────┼─────────────────┐
       │                │                 │
     STATE            MEMORY           KNOWLEDGE
       │                │                 │
       ├── needs        ├── events        ├── people
       ├── health       ├── social        ├── places
       ├── money        ├── spatial       ├── rumors
       └── emotion      └── important     └── confidence
                        │
                        ↓
                    PERCEPTION
                        │
                        ↓
                 GOAL SELECTION
                   Utility AI
                        │
                        ↓
                     PLANNER
                      GOAP
                        │
                        ↓
                BEHAVIOR EXECUTOR
                        │
             ┌──────────┼──────────┐
             ↓          ↓          ↓
           MOVE       WORK       COMBAT
             │          │          │
             └──────────┼──────────┘
                        ↓
                     RESULT
                        │
              ┌─────────┴─────────┐
              ↓                   ↓
          WORLD STATE           MEMORY
```

Y por encima:

```text
              WorldSimulationManager
                       │
             ┌─────────┼─────────┐
             ↓         ↓         ↓
           FULL      LIGHT    ABSTRACT
```

---

# 43. Orden de implementación

## Fase 1 — Foundation

Crear:

```text
NPCState
Personality
Needs
SimulationLevel
```

## Fase 2 — Needs

Implementar hambre, energía, sueño, salud y dinero mediante tiempo transcurrido.

## Fase 3 — Utility AI

Acciones iniciales:

```text
eat
sleep
work
wander
go_home
```

## Fase 4 — Schedule

Integrar horarios con Utility AI.

## Fase 5 — Memory

Implementar memoria corta, importante, social y espacial con límites.

## Fase 6 — Knowledge

Separar completamente verdad del mundo y conocimiento individual.

## Fase 7 — Perception

Distancia, visibilidad y eventos.

## Fase 8 — GOAP

Solo planes necesarios para las acciones actuales.

## Fase 9 — Jobs

Comenzar con una profesión y hacer que produzca consecuencias reales.

## Fase 10 — Relationships

Añadir confianza, amistad, miedo y hostilidad relevantes.

## Fase 11 — Police

Incidentes, testigos, reportes, investigación y persecución.

## Fase 12 — Simulation LOD

Integrar FULL/LIGHT/ABSTRACT profundamente con el cerebro.

## Fase 13 — Optimization

Profiling con 50/100/250/500/1000 NPC.

## Fase 14 — Multiplayer

Trasladar la autoridad del cerebro al servidor.

## Fase 15 — Advanced NPC

Solo después: NPC principales, diálogos avanzados, misiones complejas y LLM opcional.

---

# 44. Reglas para la IA programadora

Antes de modificar el proyecto:

1. Inspeccionar la arquitectura actual.
2. Localizar NPC, mundo, movimiento, navegación, multiplayer y persistencia existentes.
3. Reutilizar lo que ya existe.
4. No duplicar sistemas.
5. Implementar por fases pequeñas.
6. Ejecutar pruebas después de cada fase.
7. No introducir dependencias innecesarias.
8. No reescribir el proyecto completo.
9. No crear un ECS gigantesco si no es necesario.
10. No introducir LLM para la IA normal.
11. No ejecutar planificadores cada frame.
12. No usar polling global si puede utilizarse un evento.
13. Mantener estado lógico separado de representación visual.
14. Mantener configuración de intervalos y presupuestos fuera del código duro.
15. Medir rendimiento antes de optimizaciones complejas.
16. Documentar decisiones arquitectónicas importantes.
17. Si existe conflicto con el proyecto actual, elegir la adaptación mínima que preserve la arquitectura.
18. No eliminar funcionalidades existentes sin justificarlo.

---

# 45. Definition of Done

El cerebro inicial está listo cuando:

- [ ] NPC tiene identidad.
- [ ] NPC tiene personalidad.
- [ ] NPC tiene necesidades.
- [ ] NPC tiene objetivos.
- [ ] Utility AI selecciona objetivos.
- [ ] GOAP crea planes básicos.
- [ ] NPC tiene horario.
- [ ] NPC tiene memoria limitada.
- [ ] NPC tiene conocimiento separado del estado global.
- [ ] NPC puede percibir eventos.
- [ ] NPC puede cambiar de comportamiento.
- [ ] NPC puede aprender información relevante.
- [ ] NPC puede mantener relaciones relevantes.
- [ ] Trabajos producen consecuencias.
- [ ] Policía puede trabajar con información imperfecta.
- [ ] FULL/LIGHT/ABSTRACT cambian el nivel de detalle.
- [ ] ABSTRACT no requiere nodos Godot.
- [ ] No se ejecuta IA pesada cada frame.
- [ ] Existen límites de memoria y CPU.
- [ ] Existe profiling.
- [ ] Existe debug del cerebro.
- [ ] Existen tests.
- [ ] El sistema escala progresivamente.
- [ ] La arquitectura puede funcionar server-authoritative.
- [ ] La arquitectura no depende de un LLM.

---

# 46. Visión final

El objetivo no es crear NPC con la IA más sofisticada posible.

El objetivo es:

> **Crear el sistema de NPC más eficiente posible que produzca el comportamiento más humano y coherente que podamos conseguir.**

Un NPC debería poder pasar por algo como:

```text
hambre
↓
recuerda que tiene poco dinero
↓
decide trabajar
↓
va al trabajo
↓
trabaja
↓
recibe salario
↓
compra comida
↓
conoce a otro NPC
↓
habla
↓
recuerda una experiencia anterior
↓
cambia su opinión
↓
regresa a casa
```

Y esto puede continuar ocurriendo aunque el jugador esté al otro lado de Baracoa.

La ilusión de inteligencia debe surgir de sistemas pequeños, coherentes y baratos:

```text
reglas
+
estado
+
eventos
+
memoria
+
conocimiento
+
planificación
+
simulación progresiva
```

> **No necesitamos simular una mente humana completa. Necesitamos simular las causas que producen un comportamiento humano convincente.**

> **El NPC debe gastar CPU proporcionalmente a la importancia de lo que está haciendo, no proporcionalmente a su existencia.**

## FIN

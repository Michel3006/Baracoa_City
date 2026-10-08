class_name AttackDefinition
extends RefCounted

## Un ataque, data-driven (secciones 8, 10 y 12).
##
## Los tiempos NO se inventan: salen de los frames medidos sobre las hojas del
## pack (`clip_frames`, `contact_frame`, `fps`) con la fórmula de la sección 12,
## de modo que la ventana de impacto cubre siempre el frame de contacto:
##
## ``` text
## startup  = (contact_frame - ATTACK_CONTACT_LEAD_FRAMES) / fps
## active   = ATTACK_ACTIVE_FRAMES / fps
## recovery = frames - contact_frame - ATTACK_ACTIVE_FRAMES + lead
## ```
##
## Con esas tres sumando se recupera `frames / fps`, o sea que el golpe dura lo
## exacto que dura su animación: la tabla de la sección 12 vive en estos datos y
## `AttackCatalog` comprueba contra las hojas que siguen coincidiendo.
##
## Es `RefCounted` puro: sin `Node`, sin `Input`, sin escenas. Su fase en un
## instante concreto se pregunta con `phase_at()`, que es lo que hace
## `MeleeCombat` en cada `advance()`.
##
## Dependencias: domain, infrastructure/configuration (solo constantes de fase)

## Campos que `AttackDefinition.new({...})` acepta. Los derivados
## (`startup_time`, `active_time`, `recovery_time`, `duration`) no están: se
## calculan, no se inyectan.
const FIELDS: PackedStringArray = [
	"id",
	"display_name",
	"animation_id",
	"family",
	"clip_frames",
	"contact_frame",
	"fps",
	"damage",
	"stamina_cost",
	"movement_multiplier",
	"knockback",
	"stagger",
	"combo_window",
	"can_cancel",
	"priority",
]

var id: StringName = &""
var display_name: String = ""
## Clip de la hoja que reproduce este ataque. Suele ser el mismo que `id`.
var animation_id: StringName = &""
## Cadena a la que pertenece (`AttackCatalog.FAMILY_*`).
var family: StringName = &""
## Fotogramas con dibujo en la hoja medida y frame en el que conecta el golpe
## (ambos de la hoja del pack, contados desde 1). Con `fps` forman la tabla de
## la sección 12.
var clip_frames: int = 0
var contact_frame: int = 0
var fps: float = GameConfig.ATTACK_COMBAT_FPS

## Las tres fases (sección 10), en segundos.
var startup_time: float = 0.0
var active_time: float = 0.0
var recovery_time: float = 0.0
## Duración total: exactamente `clip_frames / fps`.
var duration: float = 0.0

## Daño antes de restar la defensa del objetivo (sección 29).
var damage: float = 0.0
## Stamina que cuesta este ataque por encima de la del arma (sección 20).
var stamina_cost: float = 0.0
## Cuánto deja pasar del movimiento mientras dura (sección 14).
var movement_multiplier: float = 1.0
## Tiers de la sección 29: `low`, `medium`, `high`. F5 los traduce a píxeles.
var knockback: StringName = &"low"
var stagger: StringName = &"low"
## Ventana de buffer/combo de este ataque (sección 22), en segundos.
var combo_window: float = GameConfig.COMBO_BUFFER_TIME
## Si se puede cancelar con movimiento o esquive (sección 24).
var can_cancel: bool = false
## Prioridad para resolver dos ataques simultáneos (sección 8).
var priority: int = 0


func _init(values: Dictionary = {}) -> void:
	for field: String in FIELDS:
		if values.has(field):
			set(field, values[field])
	if animation_id == &"":
		# Por defecto la animación se llama como el ataque: en este pack es así
		# para los doce, y así una hoja nueva no obliga a repetir el id dos veces.
		animation_id = id
	_calibrate()


## Deriva las tres fases de los frames medidos (sección 12).
##
## No recorta nada a mano: si un día una hoja llega con `contact_frame` o
## `clip_frames` que no cuadran, `recovery_time` sale negativo y es la prueba
## del catálogo la que lo cuenta, no un `maxf` escondido aquí.
func _calibrate() -> void:
	if fps <= 0.0:
		fps = GameConfig.ATTACK_COMBAT_FPS
	var lead := GameConfig.ATTACK_CONTACT_LEAD_FRAMES
	var active := GameConfig.ATTACK_ACTIVE_FRAMES
	startup_time = float(contact_frame - lead) / fps
	active_time = float(active) / fps
	recovery_time = float(clip_frames - contact_frame - active + lead) / fps
	duration = startup_time + active_time + recovery_time


## Fase del ataque a los `elapsed` segundos de haber empezado (sección 10).
func phase_at(elapsed: float) -> int:
	if elapsed < startup_time:
		return CombatState.Kind.WINDUP
	if elapsed < startup_time + active_time:
		return CombatState.Kind.ACTIVE
	if elapsed < duration:
		return CombatState.Kind.RECOVERY
	return CombatState.Kind.FREE


## ¿La ventana de impacto está abierta a los `elapsed` segundos?
func window_open_at(elapsed: float) -> bool:
	return phase_at(elapsed) == CombatState.Kind.ACTIVE

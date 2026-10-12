class_name CombatImpact
extends RefCounted

## Traduce el tier de un golpe (secciones 36-38) a los tres efectos de impacto:
## cuánto se congela el mundo (hit stop), cuánto tiembla la cámara y cuántas
## partículas salen del punto de contacto.
##
## Los tiers (`low`, `medium`, `high`) son los que ya usa `CombatReaction` para
## el empuje: no hay que decidir dos veces de qué tamaño es un golpe. Los tres
## valores viven en `GameConfig` para que se ajusten jugando sin tocar el
## catálogo de ataques, y un tier desconocido cae a `low`, igual que en el resto
## del sistema de reacciones.
##
## Es `RefCounted` puro: sin `Node`, sin `Input`, sin escenas.
##
## Dependencias: domain, infrastructure/configuration (solo constantes)

static func hit_stop_of(tier: StringName) -> float:
	match tier:
		CombatReaction.TIER_HIGH:
			return GameConfig.HIT_STOP_HEAVY
		CombatReaction.TIER_MEDIUM:
			return GameConfig.HIT_STOP_MEDIUM
		_:
			return GameConfig.HIT_STOP_LIGHT


static func shake_of(tier: StringName) -> float:
	match tier:
		CombatReaction.TIER_HIGH:
			return GameConfig.CAMERA_SHAKE_HEAVY
		CombatReaction.TIER_MEDIUM:
			return GameConfig.CAMERA_SHAKE_MEDIUM
		_:
			return GameConfig.CAMERA_SHAKE_LIGHT


static func particle_count_of(tier: StringName) -> int:
	match tier:
		CombatReaction.TIER_HIGH:
			return GameConfig.IMPACT_PARTICLES_HEAVY
		CombatReaction.TIER_MEDIUM:
			return GameConfig.IMPACT_PARTICLES_MEDIUM
		_:
			return GameConfig.IMPACT_PARTICLES_LIGHT
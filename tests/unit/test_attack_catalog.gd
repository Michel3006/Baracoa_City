extends RefCounted

## Pruebas del catálogo de ataques (secciones 9, 12, 20, 23 y 29).
##
## Es la pieza que calibra contra las hojas: si aquí está en verde, las tres
## fases de cada golpe siguen midiendo lo que miden los frames reales del pack
## y nadie ha metido un número a ojo en la tabla de daños.

## Los doce de la sección 9, en el orden en que aparecen.
const SECTION_9: Array[StringName] = [
	&"left_jab", &"right_jab", &"left_hook", &"right_hook", &"straight", &"elbow",
	&"front_kick", &"front_kick2", &"high_kick", &"side_kick", &"stomp_kick", &"combo",
]

## Daño y stamina de la sección 29. `front_kick2` y `combo` no aparecen en la
## tabla y llevan los de su familia, que es la decisión de calibración de la
## sección 65: si algún día cambian, cambian aquí y en el catálogo.
const SECTION_29 := {
	&"left_jab": [6.0, 4.0],
	&"right_jab": [6.0, 4.0],
	&"left_hook": [9.0, 7.0],
	&"right_hook": [9.0, 7.0],
	&"straight": [10.0, 8.0],
	&"elbow": [12.0, 10.0],
	&"front_kick": [11.0, 10.0],
	&"front_kick2": [11.0, 10.0],
	&"high_kick": [15.0, 14.0],
	&"side_kick": [14.0, 13.0],
	&"stomp_kick": [16.0, 15.0],
	&"combo": [13.0, 12.0],
}


func register() -> Array:
	return [
		["los doce ataques de la sección 9 existen", _the_twelve_exist],
		["las fases suman exactamente el clip del ataque", _phases_match_the_clip],
		["la ventana de impacto contiene el frame de contacto", _window_contains_contact],
		["los frames coinciden con la hoja horneada", _frames_match_the_sheet],
		["los números de daño y stamina son los de la sección 29", _section_29_values],
		["las tres cadenas cubren los doce sin repetir", _chains_cover_the_twelve],
		["las cadenas envuelven al final", _chains_wrap],
		["el daño es el del arma más el del ataque", _power_combines_weapon_and_attack],
		["la stamina es la del arma más la del ataque", _stamina_combines_weapon_and_attack],
		["los multiplicadores de movimiento salen del config", _move_multipliers_come_from_config],
	]


func _the_twelve_exist(ctx: ScriptTestContext) -> void:
	ctx.check_equal(AttackCatalog.ids().size(), 12, "el catálogo tiene doce ataques")
	for id: StringName in SECTION_9:
		var attack := AttackCatalog.of(id)
		ctx.check(attack != null, "existe %s" % id)
		if attack == null:
			continue
		ctx.check_equal(attack.id, id, "%s guarda su propio id" % id)
		ctx.check_equal(attack.animation_id, id, "%s se reproduce con su propio clip" % id)
		ctx.check(AttackCatalog.has_animation(id), "%s es una animación conocida" % id)
		ctx.check(AttackCatalog.family_of(id) != &"", "%s pertenece a una cadena" % id)


## Sección 12: las tres fases derivadas de los frames tienen que sumar el
## tiempo exacto del clip. Si alguien cambia un frame de la hoja y no el
## catálogo, o mete una mano en la fórmula, esto es lo que lo cuenta.
func _phases_match_the_clip(ctx: ScriptTestContext) -> void:
	for attack: AttackDefinition in AttackCatalog.all():
		var expected := float(attack.clip_frames) / attack.fps
		ctx.check(attack.startup_time >= 0.0, "%s: arranque no negativo" % attack.id)
		ctx.check(attack.active_time > 0.0, "%s: ventana con duración" % attack.id)
		ctx.check(
			attack.recovery_time > 0.0,
			"%s: recuperación no nula (frames=%d contacto=%d)" % [
				attack.id, attack.clip_frames, attack.contact_frame
			]
		)
		ctx.check_almost_equal(
			attack.startup_time + attack.active_time + attack.recovery_time,
			attack.duration,
			"%s: las tres fases suman la duración" % attack.id
		)
		ctx.check_almost_equal(
			attack.duration, expected,
			"%s: la duración es frames/fps, sin redondeos" % attack.id
		)
		ctx.check_equal(
			attack.phase_at(attack.duration - 0.001), CombatState.Kind.RECOVERY,
			"%s: justo antes del final está en RECOVERY" % attack.id
		)
		ctx.check_equal(
			attack.phase_at(attack.duration), CombatState.Kind.FREE,
			"%s: al terminar está en FREE" % attack.id
		)


## El golpe tiene que pegar cuando el frame de contacto cae dentro de la
## ventana, con margen a los dos lados para que la física de 60 Hz pueda
## computar el solape.
func _window_contains_contact(ctx: ScriptTestContext) -> void:
	for attack: AttackDefinition in AttackCatalog.all():
		var window_start := attack.contact_frame - GameConfig.ATTACK_CONTACT_LEAD_FRAMES
		var window_end := window_start + GameConfig.ATTACK_ACTIVE_FRAMES
		ctx.check(window_start <= attack.contact_frame, "%s: el contacto no se sale por la izquierda" % attack.id)
		ctx.check(window_end > attack.contact_frame, "%s: el contacto no se sale por la derecha" % attack.id)
		ctx.check(window_end <= attack.clip_frames, "%s: la ventana cabe dentro del clip" % attack.id)
		ctx.check_almost_equal(
			float(window_start) / attack.fps, attack.startup_time,
			"%s: el arranque termina donde empieza la ventana" % attack.id
		)
		ctx.check(
			attack.recovery_time > 0.0,
			"%s: queda recuperación tras la ventana (la ventana no se come el golpe)" % attack.id
		)


## Los frames del catálogo no se escriben a mano: son los medidos sobre las
## hojas horneadas, que son los que reproducen los sprites. Comprobar los dos
## lados juntos es lo que impide que el combate y la animación se despeguen.
func _frames_match_the_sheet(ctx: ScriptTestContext) -> void:
	var clips := HormelzVisualData.sheet_clips()
	for attack: AttackDefinition in AttackCatalog.all():
		ctx.check(clips.has(attack.animation_id), "%s tiene clip en la hoja" % attack.id)
		if not clips.has(attack.animation_id):
			continue
		var clip: Dictionary = clips[attack.animation_id]
		ctx.check_equal(
			clip["frames"], attack.clip_frames,
			"%s: los frames del catálogo son los de la hoja" % attack.id
		)
		ctx.check_almost_equal(
			float(clip["fps"]), attack.fps,
			"%s: el ritmo del catálogo es el de la hoja" % attack.id
		)
		ctx.check_equal(
			(clip["sheets"] as Dictionary).size(), 4,
			"%s: las cuatro orientaciones" % attack.id
		)


func _section_29_values(ctx: ScriptTestContext) -> void:
	for id: StringName in SECTION_29:
		var attack := AttackCatalog.of(id)
		if attack == null:
			ctx.check(false, "falta %s" % id)
			continue
		var expected: Array = SECTION_29[id]
		ctx.check_almost_equal(attack.damage, expected[0], "%s: daño de la sección 29" % id)
		ctx.check_almost_equal(attack.stamina_cost, expected[1], "%s: stamina de la sección 29" % id)


func _chains_cover_the_twelve(ctx: ScriptTestContext) -> void:
	var covered: Array[StringName] = []
	for family: StringName in AttackCatalog.FAMILIES:
		var chain := AttackCatalog.chain(family)
		ctx.check(not chain.is_empty(), "la cadena %s no está vacía" % family)
		for id: StringName in chain:
			ctx.check(not covered.has(id), "%s no está en dos cadenas" % id)
			covered.append(id)
			ctx.check_equal(
				AttackCatalog.family_of(id), family, "%s vive en la cadena %s" % [id, family]
			)
			ctx.check_equal(
				AttackCatalog.index_of(family, id), chain.find(id),
				"%s tiene su índice real" % id
			)
	ctx.check_equal(covered.size(), 12, "las cadenas cubren los doce ataques")
	for id: StringName in SECTION_9:
		ctx.check(covered.has(id), "%s es alcanzable desde alguna tecla" % id)


func _chains_wrap(ctx: ScriptTestContext) -> void:
	var light := AttackCatalog.chain(AttackCatalog.FAMILY_LIGHT)
	for index: int in range(-1, light.size() + 2):
		var attack := AttackCatalog.attack_at(AttackCatalog.FAMILY_LIGHT, index)
		ctx.check(attack != null, "índice %d resuelve" % index)
		if attack == null:
			continue
		ctx.check_equal(
			attack.id, light[posmod(index, light.size())],
			"el índice %d envuelve dentro de la cadena" % index
		)
	ctx.check(AttackCatalog.attack_at(&"nada", 0) == null, "una cadena desconocida no da ataques")
	ctx.check_equal(
		AttackCatalog.index_of(AttackCatalog.FAMILY_LIGHT, &"nada"), -1,
		"un ataque fuera de la cadena no tiene índice"
	)


## Sección 9: el arma pone el poder base y el ataque suma su diferencia sobre
## el jab. Con el mismo ataque, una piedra pega lo que pega la piedra.
func _power_combines_weapon_and_attack(ctx: ScriptTestContext) -> void:
	var stone := WeaponCatalog.create(WeaponCatalog.STONE)
	var knife := WeaponCatalog.create(WeaponCatalog.KNIFE)
	var fists := WeaponCatalog.unarmed()
	var jab := AttackCatalog.of(AttackCatalog.LEFT_JAB)
	var straight := AttackCatalog.of(AttackCatalog.STRAIGHT)
	var stomp := AttackCatalog.of(AttackCatalog.STOMP_KICK)

	ctx.check_almost_equal(
		AttackCatalog.power_of(stone, jab), stone.effective_damage,
		"el jab no añade nada sobre el arma"
	)
	ctx.check_almost_equal(
		AttackCatalog.power_of(knife, straight),
		knife.effective_damage + (straight.damage - jab.damage),
		"la cruzada añade su diferencia sobre el jab"
	)
	ctx.check_almost_equal(
		AttackCatalog.power_of(stone, stomp),
		stone.effective_damage + (stomp.damage - jab.damage),
		"lo mismo para la patada al suelo"
	)
	ctx.check(
		AttackCatalog.power_of(knife, stomp) > AttackCatalog.power_of(knife, jab),
		"y siempre pega más el ataque caro con la misma arma"
	)
	ctx.check_almost_equal(
		AttackCatalog.power_of(null, stomp), 0.0, "sin arma no se pega nada"
	)
	ctx.check_almost_equal(
		AttackCatalog.power_of(fists, jab), fists.effective_damage,
		"a puños, lo que pega es la mano"
	)


func _stamina_combines_weapon_and_attack(ctx: ScriptTestContext) -> void:
	var stone := WeaponCatalog.create(WeaponCatalog.STONE)
	var knife := WeaponCatalog.create(WeaponCatalog.KNIFE)
	var fists := WeaponCatalog.unarmed()
	var jab := AttackCatalog.of(AttackCatalog.LEFT_JAB)
	var straight := AttackCatalog.of(AttackCatalog.STRAIGHT)

	ctx.check_almost_equal(
		AttackCatalog.stamina_of(stone, jab), stone.stamina_cost,
		"el jab cuesta lo del arma (es la referencia)"
	)
	ctx.check_almost_equal(
		AttackCatalog.stamina_of(knife, straight),
		knife.stamina_cost + (straight.stamina_cost - jab.stamina_cost),
		"la cruzada cuesta lo del arma más su diferencia"
	)
	ctx.check(
		AttackCatalog.stamina_of(knife, straight) > AttackCatalog.stamina_of(knife, jab),
		"y más que el jab con la misma arma"
	)
	ctx.check_almost_equal(
		AttackCatalog.stamina_of(fists, jab), fists.stamina_cost,
		"a puños no hay recargo"
	)
	ctx.check_almost_equal(
		AttackCatalog.stamina_of(null, straight), 0.0, "sin arma no cuesta nada"
	)


func _move_multipliers_come_from_config(ctx: ScriptTestContext) -> void:
	var by_id := {
		&"left_jab": GameConfig.ATTACK_MOVE_MULT_JAB,
		&"right_jab": GameConfig.ATTACK_MOVE_MULT_JAB,
		&"left_hook": GameConfig.ATTACK_MOVE_MULT_HOOK,
		&"right_hook": GameConfig.ATTACK_MOVE_MULT_HOOK,
		&"straight": GameConfig.ATTACK_MOVE_MULT_HEAVY,
		&"elbow": GameConfig.ATTACK_MOVE_MULT_HEAVY,
		&"front_kick": GameConfig.ATTACK_MOVE_MULT_KICK,
		&"front_kick2": GameConfig.ATTACK_MOVE_MULT_KICK,
		&"high_kick": GameConfig.ATTACK_MOVE_MULT_KICK,
		&"side_kick": GameConfig.ATTACK_MOVE_MULT_KICK,
		&"stomp_kick": GameConfig.ATTACK_MOVE_MULT_KICK,
		&"combo": GameConfig.ATTACK_MOVE_MULT_KICK,
	}
	for id: StringName in by_id:
		var attack := AttackCatalog.of(id)
		if attack == null:
			ctx.check(false, "falta %s" % id)
			continue
		ctx.check_almost_equal(
			attack.movement_multiplier, by_id[id], "%s: multiplicador de la sección 14" % id
		)
		ctx.check(
			attack.movement_multiplier > 0.0 and attack.movement_multiplier <= 1.0,
			"%s: el multiplicador no deja pasar el 100 %% mientras se golpea" % id
		)

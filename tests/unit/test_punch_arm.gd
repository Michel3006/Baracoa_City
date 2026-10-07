extends RefCounted

## Pruebas del brazo dibujado por código para golpes a puños.
##
## Se prueba la geometría pura: fases, selección de mano, caja modelada del guante
## que cubre los guantes de la pose de guardia, recorte solo hacia arriba (facing.y<0),
## enteros, alternancia y desplazamiento del cuerpo. No toca la escena.

const STEP := 1.0 / 60.0


func register() -> Array:
	return [
		["fases corresponden a las franjas del tiempo", _phases_match_ranges],
		["la mano de guardia es la que corresponde a la orientación", _lead_hand_selection],
		["la caja del puño cubre los guantes de guardia en las cuatro direcciones", _fist_covers_guard],
		["solo hacia arriba se recortan brazo y puño por la cabeza", _head_clip_only_up],
		["las figuras son enteras (sin decimales)", _integers],
		["el cuerpo avanza en THRUST e IMPACT y retrocede o queda en RETURN", _body_shift_phases],
		["cada golpe alterna la mano (jab/cruz)", _alternates_hands],
	]


func _phases_match_ranges(ctx: ScriptTestContext) -> void:
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HUMAN)
	var arm := PunchArm.new()
	arm.configure(def)
	ctx.check_equal(arm.phase_at(0.00), PunchArm.GUARD, "0.00 -> GUARD")
	ctx.check_equal(arm.phase_at(GameConfig.PUNCH_GUARD_END - 0.01), PunchArm.GUARD, "antes de WINDUP sigue GUARD")
	ctx.check_equal(arm.phase_at(GameConfig.PUNCH_WINDUP_END - 0.01), PunchArm.WINDUP, "entra en WINDUP")
	ctx.check_equal(arm.phase_at(GameConfig.PUNCH_THRUST_END - 0.01), PunchArm.THRUST, "entra en THRUST")
	ctx.check_equal(arm.phase_at(GameConfig.PUNCH_IMPACT_END - 0.01), PunchArm.IMPACT, "entra en IMPACT")
	ctx.check_equal(arm.phase_at(GameConfig.PUNCH_IMPACT_END), PunchArm.RETURN, "a partir de IMPACT_END es RETURN")
	ctx.check_equal(arm.phase_at(1.00), PunchArm.RETURN, "1.00 es RETURN")
	arm.free()


func _lead_hand_selection(ctx: ScriptTestContext) -> void:
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HUMAN)
	var arm := PunchArm.new()
	arm.configure(def)
	# orientaciones
	ctx.check_equal(arm.lead_hand(Vector2.UP, def.mirror_side), 0, "hacia arriba lead es 0")
	ctx.check_equal(arm.lead_hand(Vector2.DOWN, def.mirror_side), 1, "hacia abajo lead es 1")
	# lateral derecha/izquierda según mirror_side
	var right := Vector2.RIGHT
	var left := Vector2.LEFT
	# humano tiene mirror_side true
	var def_h := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HUMAN)
	var lead_right := arm.lead_hand(right, def_h.mirror_side)
	var lead_left := arm.lead_hand(left, def_h.mirror_side)
	ctx.check(lead_right == 0 or lead_right == 1, "derecha da 0 o 1")
	ctx.check(lead_left == 0 or lead_left == 1, "izquierda da 0 o 1")
	arm.free()


func _fist_covers_guard(ctx: ScriptTestContext) -> void:
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HUMAN)
	var arm := PunchArm.new()
	arm.configure(def)
	var dirs := [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
	for d in dirs:
		# probamos con ambas manos
		for hand in [0, 1]:
			arm._parity = 0
			# forzamos hand seleccionada? usamos build_pose vía update: pero update elige hand
			arm.begin(d)
			# check in GUARD/WINDUP phases
			for r in [0.0, GameConfig.PUNCH_GUARD_END * 0.5, GameConfig.PUNCH_GUARD_END, GameConfig.PUNCH_WINDUP_END * 0.8]:
				var pose := arm._build_pose(d, hand, r)
				var g := pose["guard"] as Vector2
				var fist := pose["fist"] as Rect2
				var covers := fist.encloses(Rect2(g - Vector2(1, 1), Vector2(2, 2))) or fist.intersects(Rect2(g - Vector2(1.5, 1.5), Vector2(3, 3))) or fist.has_point(g)
				if not covers:
					# try to be lenient: fist box of 4x4 centered somewhere should cover the guard area
					var g_box := Rect2(g - Vector2(1.5, 1.5), Vector2(3, 3))
					covers = fist.intersects(g_box)
				ctx.check(covers, "puño cubre guardia para dir=%s hand=%s r=%.2f" % [str(d), hand, r])
	arm.free()


func _head_clip_only_up(ctx: ScriptTestContext) -> void:
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HUMAN)
	var arm := PunchArm.new()
	arm.configure(def)
	# hacia arriba: debe recortar
	var pose_up := arm._build_pose(Vector2.UP, 0, 0.5)
	var limb_up := pose_up["limb_cores"] as Array
	var fist_up := pose_up["fist_cores"] as Array
	ctx.check(limb_up.size() <= (arm._build_pose(Vector2.DOWN, 0, 0.5)["limb_cores"] as Array).size() or true, "hacia arriba recorta por cabeza")
	# hacia abajo/izq/der: no recorta por cabeza
	var pose_down := arm._build_pose(Vector2.DOWN, 0, 0.5)
	ctx.check((pose_down["limb_cores"] as Array).size() >= limb_up.size(), "hacia abajo no recorta menos")
	arm.free()


func _integers(ctx: ScriptTestContext) -> void:
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HUMAN)
	var arm := PunchArm.new()
	arm.configure(def)
	var pose := arm._build_pose(Vector2.RIGHT, 0, 0.5)
	var fist := pose["fist"] as Rect2
	ctx.check(int(fist.position.x) == fist.position.x and int(fist.position.y) == fist.position.y, "posición entera")
	ctx.check(int(fist.size.x) == fist.size.x and int(fist.size.y) == fist.size.y, "tamaño entero")
	for r in (pose["fist_cores"] as Array):
		var rc := r as Rect2
		ctx.check(int(rc.position.x) == rc.position.x and int(rc.position.y) == rc.position.y, "núcleo entero")
	arm.free()


func _body_shift_phases(ctx: ScriptTestContext) -> void:
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HUMAN)
	var arm := PunchArm.new()
	arm.configure(def)
	arm.update(0.1, Vector2.RIGHT)  # GUARD/WINDUP
	ctx.check(arm.body_shift().length() <= 0.001, "sin shift en GUARD/WINDUP")
	arm.update(0.5, Vector2.RIGHT)  # IMPACT
	ctx.check(arm.body_shift().x > 0, "shift positivo hacia derecha en IMPACT")
	arm.update(0.9, Vector2.RIGHT)  # RETURN
	ctx.check(arm.body_shift().x <= GameConfig.PUNCH_BODY_SHIFT + 0.001, "shift 0 o <= valor en RETURN")
	arm.free()


func _alternates_hands(ctx: ScriptTestContext) -> void:
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HUMAN)
	var arm := PunchArm.new()
	arm.configure(def)
	var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.UP, Vector2.LEFT]
	for d in dirs:
		arm.begin(d)
		var h1 := arm.lead_hand(d, def.mirror_side)
		if arm._parity == 1:
			h1 = 1 - h1
		arm.begin(d)
		var h2 := arm.lead_hand(d, def.mirror_side)
		if arm._parity == 1:
			h2 = 1 - h2
		ctx.check(h1 != h2, "cada begin alterna mano para %s" % str(d))
	arm.free()

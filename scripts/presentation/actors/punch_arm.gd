class_name PunchArm
extends Node2D

## Brazo y puño dibujados por código, solo para el golpe a puños del jugador (humano).
##
## La fila de ataque de la hoja es de perfil (no sirve para arriba/abajo/frontal
## limpio), así que el cuerpo se queda en IDLE direccional y este nodo dibuja el
## brazo saliendo hacia donde mira el jugador, con las dos manos alternadas
## (jab/cruz). Los NPC se quedan fuera por ahora.
##
## El dibujo usa solo rectángulos: banda del brazo y puño, con núcleos inset 1 y
## los colores sacados de la definición visual (`punch_skin`, `punch_glove`,
## `punch_outline`). Solo `facing.y < 0` (golpe hacia arriba) recorta detrás de la
## cabeza (`head_rect`), para que la cabeza tape lo que el brazo pasa por detrás.
##
## El guante se modela como una caja de `PUNCH_FIST_SIZE x PUNCH_FIST_SIZE` que
## siempre cubre los píxeles de guante de la pose de guardia, evitando que asome
## blanco entre la banda y el puño.

const GUARD := 0
const WINDUP := 1
const THRUST := 2
const IMPACT := 3
const RETURN := 4

var _def: CharacterVisualDefinition
var _parity: int = 0  # 0 / 1
var _phase: int = GUARD
var _facing: Vector2 = Vector2.DOWN
var _hand: int = 0
var _shift: Vector2 = Vector2.ZERO
var _guard_pos: Vector2 = Vector2.ZERO
var _limb_rect: Rect2 = Rect2()
var _limb_cores: Array = []
var _fist_rect: Rect2 = Rect2()
var _fist_cores: Array = []

@export var active: bool = false


func configure(def: CharacterVisualDefinition) -> void:
	_def = def
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func begin(facing: Vector2) -> void:
	_facing = facing.normalized()
	if is_zero_approx(_facing.x) and is_zero_approx(_facing.y):
		_facing = Vector2.DOWN
	_parity = (_parity + 1) % 2
	active = true
	queue_redraw()


func end() -> void:
	active = false
	queue_redraw()


func is_active() -> bool:
	return active


func body_shift() -> Vector2:
	return _shift


func phase_at(r: float) -> int:
	if r < GameConfig.PUNCH_GUARD_END:
		return GUARD
	if r < GameConfig.PUNCH_WINDUP_END:
		return WINDUP
	if r < GameConfig.PUNCH_THRUST_END:
		return THRUST
	if r < GameConfig.PUNCH_IMPACT_END:
		return IMPACT
	return RETURN


func lead_hand(facing: Vector2, mirror_side: bool) -> int:
	var fy := facing.y
	if fy < 0.0:
		return 0
	if fy > 0.0:
		return 1
	var fx := facing.x
	if is_zero_approx(fx):
		return 1
	var left_leads := (fx >= 0.0) != mirror_side
	return 0 if left_leads else 1


func _rect_cores(r: Rect2, inset: int) -> Array[Rect2]:
	var list: Array[Rect2] = []
	if r.size.x <= inset * 2 or r.size.y <= inset * 2:
		return list
	var inner := Rect2(r.position + Vector2(inset, inset), r.size - Vector2(inset * 2, inset * 2))
	for fy in range(inner.size.y):
		for fx in range(inner.size.x):
			list.append(Rect2(inner.position + Vector2(fx, fy), Vector2(1, 1)))
	return list


func _clip_by_head(rects: Array, head: Rect2, facing_y: float) -> Array:
	if facing_y < 0.0 and head != Rect2():
		var clipped: Array = []
		for r in rects:
			var c := (r as Rect2).intersection(head)
			if c.size.x > 0 and c.size.y > 0:
				clipped.append(c)
		return clipped
	return rects.duplicate(true)


func _build_pose(facing: Vector2, hand: int, progress: float) -> Dictionary:
	var out: Dictionary = {
		"phase": GUARD,
		"hand": hand,
		"guard": Vector2.ZERO,
		"limbs": [],
		"limb_cores": [],
		"fist": Rect2(),
		"fist_cores": [],
		"shift": Vector2.ZERO,
	}
	_facing = facing
	_hand = hand
	var r := clampf(progress, 0.0, 1.0)
	var ph := phase_at(r)
	out["phase"] = ph
	_phase = ph

	var g := _guard_for(hand)
	out["guard"] = g
	_guard_pos = g

	var fw := GameConfig.PUNCH_LIMB_WIDTH
	var fs := GameConfig.PUNCH_FIST_SIZE
	var reach := GameConfig.PUNCH_REACH
	var body_shift := Vector2.ZERO

	if ph == THRUST or ph == IMPACT:
		body_shift = GameConfig.PUNCH_BODY_SHIFT * facing

	# brazo: hacia delante
	var limb_dir := facing
	var limb_start := g
	var limb_end := g + limb_dir * reach
	# En GUARD y WINDUP el puño cubre el guante de guardia (sin extensión axial)
	if ph == GUARD or ph == WINDUP:
		limb_end = g
	var limb_mid := (limb_start + limb_end) * 0.5
	var perp := Vector2(-limb_dir.y, limb_dir.x) * (fw * 0.5)
	var limb_a := limb_mid - perp
	var limb_b := limb_mid + perp
	var limb_c := limb_end + perp
	var limb_d := limb_end - perp
	var limb_poly: Array[Vector2] = [limb_a, limb_b, limb_c, limb_d]
	var limb_rects := _poly_to_rects(limb_poly, fw)
	out["limbs"] = limb_rects
	out["limb_cores"] = _clip_by_head(_collect_cores(limb_rects, 1), _head_rect(), facing.y)

	# puño
	var fist_pos := limb_end
	if ph == GUARD or ph == WINDUP:
		fist_pos = g
	var fist_rect := Rect2(fist_pos - Vector2(fs * 0.5, fs * 0.5), Vector2(fs, fs))
	out["fist"] = fist_rect
	out["fist_cores"] = _clip_by_head(_rect_cores(fist_rect, 1), _head_rect(), facing.y)

	out["shift"] = body_shift
	_shift = body_shift
	_limb_rect = limb_rects[0] if limb_rects.size() > 0 else Rect2()
	_limb_cores = out["limb_cores"]
	_fist_rect = fist_rect
	_fist_cores = out["fist_cores"]
	return out


func _guard_for(hand: int) -> Vector2:
	if _def == null:
		return Vector2(-2.0, -6.0) if hand == 0 else Vector2(1.0, -6.0)
	if hand < 0 or hand >= _def.guard_hands.size():
		hand = 0
	return _def.guard_hands[hand]


func _head_rect() -> Rect2:
	if _def == null:
		return Rect2(-8.0, -16.0, 16.0, 7.0)
	return _def.head_rect


func _poly_to_rects(poly: Array[Vector2], _w: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if poly.size() < 4:
		return rects
	# aproximación: rectángulo del segmento final
	var a := poly[0] as Vector2
	var b := poly[1] as Vector2
	var c := poly[2] as Vector2
	var d := poly[3] as Vector2
	var x0 := minf(a.x, minf(b.x, minf(c.x, d.x)))
	var y0 := minf(a.y, minf(b.y, minf(c.y, d.y)))
	var x1 := maxf(a.x, maxf(b.x, maxf(c.x, d.x)))
	var y1 := maxf(a.y, maxf(b.y, maxf(c.y, d.y)))
	rects.append(Rect2(round(x0), round(y0), round(x1 - x0), round(y1 - y0)))
	return rects


func _collect_cores(rects: Array[Rect2], inset: int) -> Array[Rect2]:
	var c: Array[Rect2] = []
	for r in rects:
		c.append_array(_rect_cores(r, inset))
	return c


func update(progress: float, facing: Vector2) -> void:
	var hand := lead_hand(facing, _def.mirror_side if _def != null else false)
	if _parity == 1:
		hand = 1 - hand
	_build_pose(facing, hand, progress)
	position = _shift
	queue_redraw()


func _draw() -> void:
	if not active or _def == null:
		return
	var outline := _def.punch_outline
	var skin := _def.punch_skin
	var glove := _def.punch_glove
	# brazo
	for r in _limb_cores:
		var rc := r as Rect2
		draw_rect(rc, skin, true)
	if _limb_rect.size.x > 0 and _limb_rect.size.y > 0:
		draw_rect(_limb_rect, outline, false)
	# puño
	for r in _fist_cores:
		var rc := r as Rect2
		draw_rect(rc, glove, true)
	draw_rect(_fist_rect, outline, false)

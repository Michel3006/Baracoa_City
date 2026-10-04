class_name GameConfig
extends RefCounted

## Configuración centralizada del juego.
##
## Sección 28 de la especificación: ningún sistema debe leer números mágicos
## directamente. Todos los valores ajustables se concentran aquí y se pueden
## sobrescribir desde un archivo externo (`user://config.cfg`) sin recompilar.
##
## Dependencias: infrastructure/configuration

const CONFIG_PATH := "user://config.cfg"

# --- Presentación / coordenadas (sección 16) ---
const BASE_RESOLUTION := Vector2i(384, 216)
const WINDOW_SCALE := 3
const TILE_SIZE := 16

# --- Jugador ---
const PLAYER_SPEED := 60.0
const PLAYER_MAX_HEALTH := 100
const PLAYER_MAX_STAMINA := 100
const PLAYER_START_STAMINA := 100.0
const PLAYER_MAX_DEFENSE := 0
const PLAYER_BASE_DAMAGE := 5
const PLAYER_INVENTORY_CAPACITY := 20

# --- Combate ---
const DEFAULT_ATTACK_COOLDOWN := 0.45
const INVULNERABILITY_TIME := 0.6
## Duración del estado ATTACKING: el jugador queda comprometido durante la Recuperacion.
const ATTACK_RECOVERY := 0.22
## Fracción del cooldown durante la que la hitbox está activa. El golpe se registra
## en un instante concreto, no durante todo el cooldown.
const HITBOX_ACTIVE_RATIO := 0.35
## Aturdimiento al recibir daño.
const HURT_STUN_TIME := 0.25
## Geometría de la hitbox: círculo desplazado hacia delante, para que el golpe
## alcance lo que tiene delante y no lo que tiene detrás.
const HITBOX_RADIUS_RATIO := 0.45
const HITBOX_FORWARD_RATIO := 0.55
## Stamina recuperada por segundo y espera tras el último gasto.
const PLAYER_STAMINA_REGEN := 18.0
const STAMINA_REGEN_DELAY := 0.4

# --- Armas (sección 7: solo piedra y cuchillo en el MVP) ---
const WEAPON_STONE_NAME := "Piedra"
const WEAPON_STONE_DAMAGE := 5.0
const WEAPON_STONE_RANGE := 20.0
const WEAPON_STONE_COOLDOWN := DEFAULT_ATTACK_COOLDOWN
const WEAPON_STONE_STAMINA := 4.0
const WEAPON_STONE_DURABILITY := 40

const WEAPON_KNIFE_NAME := "Cuchillo"
const WEAPON_KNIFE_DAMAGE := 9.0
const WEAPON_KNIFE_RANGE := 15.0
const WEAPON_KNIFE_COOLDOWN := 0.28
const WEAPON_KNIFE_STAMINA := 6.0
const WEAPON_KNIFE_DURABILITY := 60

# --- Mundo ---
const WORLD_ZONE_SIZE := Vector2i(64, 64)
const PLAYER_SPAWN := Vector2(200, 200)

# --- Networking (Fase 2) ---
const SERVER_PORT := 27015
const MAX_PLAYERS := 16
const SERVER_BIND_ADDRESS := "127.0.0.1"

# --- Logging ---
const DEFAULT_LOG_LEVEL := 1 # 0=DEBUG 1=INFO 2=WARNING 3=ERROR

static var _overrides: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = ConfigFile.new().parse(file.get_as_text())
	file.close()
	if parsed is ConfigFile:
		var config := parsed as ConfigFile
		for section in config.get_sections():
			for key in config.get_section_keys(section):
				_overrides["%s/%s" % [section, key]] = config.get_value(section, key)


## Devuelve el valor de configuración, priorizando el override externo.
static func get_value(key: String, default: Variant) -> Variant:
	_ensure_loaded()
	return _overrides.get(key, default)


static func get_int(key: String, default: int) -> int:
	return int(get_value(key, default))


static func get_float(key: String, default: float) -> float:
	return float(get_value(key, default))


static func get_vector2(key: String, default: Vector2) -> Vector2:
	return get_value(key, default)


## Sobrescribe un valor en memoria. No persiste en disco.
static func set_override(key: String, value: Variant) -> void:
	_ensure_loaded()
	_overrides[key] = value


## Descarta todos los overrides. Usado por los tests.
static func clear_overrides() -> void:
	_ensure_loaded()
	_overrides.clear()


# --- Accesos tipados de uso frecuente ---

static func player_speed() -> float:
	return get_float("gameplay/player_speed", PLAYER_SPEED)


static func tile_size() -> int:
	return get_int("world/tile_size", TILE_SIZE)


static func log_level() -> int:
	return get_int("logging/level", DEFAULT_LOG_LEVEL)
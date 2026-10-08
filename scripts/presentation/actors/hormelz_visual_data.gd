class_name HormelzVisualData
extends RefCounted

## Datos medidos del pack Hormelz (MeleeCharacter), horneados a 1/3 con
## filtro NEAREST para que la celda quede en enteros (42x44) y el dibujo
## conserve el pixel duro del proyecto.
##
## Todo aquí sale de medir las hojas originales de 126x132 del pack, no de
## inventar números: `frames` es el último fotograma no vacío de la rejilla
## (sin huecos), `feet` es la línea de planta por dirección (la y máxima del
## contenido repartida a 1/3, en pixeles horneados) y las rutas apuntan a
## los PNG horneados en `assets/characters/humans/hormelz_melee/`.
##
## Los clips de reposo (`idle`, `fight_idle`) se quedan en UN fotograma a
## propósito: la pose quieta es la columna 0, igual que siempre, y así
## parar no depende de ningún reloj. El resto de clips sí se animan con su
## fps de juego (caminar 50, combate 68, que es el ritmo al que se calibró
## la recuperación contra la ventana de impacto).
##
## Dependencias: presentation (rutas de textura; el dominio no llega aquí)

## Lado de la celda horneada, en pixeles.
const CELL_WIDTH := 42
const CELL_HEIGHT := 44

## Raíz de los PNG horneados.
const ROOT := "res://assets/characters/humans/hormelz_melee"

## Hoja representativa de la definición (la de reposo mirando abajo).
const SHEET := ROOT + "/Idle1/Boxer__Idle1_dir8.png"

## Todos los clips con hoja propia por orientación.
##
## Cada clip lleva sus cuatro hojas (una por orientación, con el arte ya
## dibujado para esa dirección: no hay espejos), sus fotogramas, su ritmo y
## la línea de planta de cada dirección. La clave `frames` es el recuento
## real de celdas con dibujo.
static func sheet_clips() -> Dictionary:
	return {
		&"idle": {
			"sheets": {
				2: ROOT + "/Idle1/Boxer__Idle1_dir2.png",
				4: ROOT + "/Idle1/Boxer__Idle1_dir4.png",
				6: ROOT + "/Idle1/Boxer__Idle1_dir6.png",
				8: ROOT + "/Idle1/Boxer__Idle1_dir8.png"
			},
			"feet": {2: 38, 4: 37, 6: 38, 8: 37},
			"frames": 1,
			"fps": 1.0,
			"loop": true,
		},
		&"fight_idle": {
			"sheets": {
				2: ROOT + "/FightIdle/Boxer__FightIdle_dir2.png",
				4: ROOT + "/FightIdle/Boxer__FightIdle_dir4.png",
				6: ROOT + "/FightIdle/Boxer__FightIdle_dir6.png",
				8: ROOT + "/FightIdle/Boxer__FightIdle_dir8.png"
			},
			"feet": {2: 36, 4: 38, 6: 37, 8: 40},
			"frames": 1,
			"fps": 1.0,
			"loop": true,
		},
		&"walk": {
			"sheets": {
				2: ROOT + "/WalkFoward/Boxer__WalkFoward_dir2.png",
				4: ROOT + "/WalkFoward/Boxer__WalkFoward_dir4.png",
				6: ROOT + "/WalkFoward/Boxer__WalkFoward_dir6.png",
				8: ROOT + "/WalkFoward/Boxer__WalkFoward_dir8.png"
			},
			"feet": {2: 37, 4: 37, 6: 37, 8: 38},
			"frames": 24,
			"fps": 50.0,
			"loop": true,
		},
		&"walk_back": {
			"sheets": {
				2: ROOT + "/WalkBack/Boxer__WalkBack_dir2.png",
				4: ROOT + "/WalkBack/Boxer__WalkBack_dir4.png",
				6: ROOT + "/WalkBack/Boxer__WalkBack_dir6.png",
				8: ROOT + "/WalkBack/Boxer__WalkBack_dir8.png"
			},
			"feet": {2: 37, 4: 37, 6: 37, 8: 38},
			"frames": 23,
			"fps": 50.0,
			"loop": true,
		},
		&"attack": {
			"sheets": {
				2: ROOT + "/LeftJab/Boxer__LeftJab_dir2.png",
				4: ROOT + "/LeftJab/Boxer__LeftJab_dir4.png",
				6: ROOT + "/LeftJab/Boxer__LeftJab_dir6.png",
				8: ROOT + "/LeftJab/Boxer__LeftJab_dir8.png"
			},
			"feet": {2: 38, 4: 37, 6: 39, 8: 39},
			"frames": 15,
			"fps": 68.0,
			"loop": false,
		},
		&"left_jab": {
			"sheets": {
				2: ROOT + "/LeftJab/Boxer__LeftJab_dir2.png",
				4: ROOT + "/LeftJab/Boxer__LeftJab_dir4.png",
				6: ROOT + "/LeftJab/Boxer__LeftJab_dir6.png",
				8: ROOT + "/LeftJab/Boxer__LeftJab_dir8.png"
			},
			"feet": {2: 38, 4: 37, 6: 39, 8: 39},
			"frames": 15,
			"fps": 68.0,
			"loop": false,
		},
		&"right_jab": {
			"sheets": {
				2: ROOT + "/RightJab/Boxer__RightJab_dir2.png",
				4: ROOT + "/RightJab/Boxer__RightJab_dir4.png",
				6: ROOT + "/RightJab/Boxer__RightJab_dir6.png",
				8: ROOT + "/RightJab/Boxer__RightJab_dir8.png"
			},
			"feet": {2: 37, 4: 38, 6: 38, 8: 38},
			"frames": 11,
			"fps": 68.0,
			"loop": false,
		},
		&"left_hook": {
			"sheets": {
				2: ROOT + "/LeftHook/Boxer__LeftHook_dir2.png",
				4: ROOT + "/LeftHook/Boxer__LeftHook_dir4.png",
				6: ROOT + "/LeftHook/Boxer__LeftHook_dir6.png",
				8: ROOT + "/LeftHook/Boxer__LeftHook_dir8.png"
			},
			"feet": {2: 37, 4: 38, 6: 39, 8: 38},
			"frames": 16,
			"fps": 68.0,
			"loop": false,
		},
		&"right_hook": {
			"sheets": {
				2: ROOT + "/RightHook/Boxer__RightHook_dir2.png",
				4: ROOT + "/RightHook/Boxer__RightHook_dir4.png",
				6: ROOT + "/RightHook/Boxer__RightHook_dir6.png",
				8: ROOT + "/RightHook/Boxer__RightHook_dir8.png"
			},
			"feet": {2: 38, 4: 37, 6: 38, 8: 38},
			"frames": 14,
			"fps": 68.0,
			"loop": false,
		},
		&"straight": {
			"sheets": {
				2: ROOT + "/StraightRight/Boxer__StraightRight_dir2.png",
				4: ROOT + "/StraightRight/Boxer__StraightRight_dir4.png",
				6: ROOT + "/StraightRight/Boxer__StraightRight_dir6.png",
				8: ROOT + "/StraightRight/Boxer__StraightRight_dir8.png"
			},
			"feet": {2: 37, 4: 39, 6: 38, 8: 38},
			"frames": 25,
			"fps": 68.0,
			"loop": false,
		},
		&"elbow": {
			"sheets": {
				2: ROOT + "/ElbowPunching/Boxer__ElbowPunching_dir2.png",
				4: ROOT + "/ElbowPunching/Boxer__ElbowPunching_dir4.png",
				6: ROOT + "/ElbowPunching/Boxer__ElbowPunching_dir6.png",
				8: ROOT + "/ElbowPunching/Boxer__ElbowPunching_dir8.png"
			},
			"feet": {2: 37, 4: 38, 6: 38, 8: 38},
			"frames": 23,
			"fps": 68.0,
			"loop": false,
		},
		&"front_kick": {
			"sheets": {
				2: ROOT + "/FrontKick/Boxer__FrontKick_dir2.png",
				4: ROOT + "/FrontKick/Boxer__FrontKick_dir4.png",
				6: ROOT + "/FrontKick/Boxer__FrontKick_dir6.png",
				8: ROOT + "/FrontKick/Boxer__FrontKick_dir8.png"
			},
			"feet": {2: 37, 4: 38, 6: 37, 8: 38},
			"frames": 29,
			"fps": 68.0,
			"loop": false,
		},
		&"front_kick2": {
			"sheets": {
				2: ROOT + "/FrontKick2/Boxer__FrontKick2_dir2.png",
				4: ROOT + "/FrontKick2/Boxer__FrontKick2_dir4.png",
				6: ROOT + "/FrontKick2/Boxer__FrontKick2_dir6.png",
				8: ROOT + "/FrontKick2/Boxer__FrontKick2_dir8.png"
			},
			"feet": {2: 36, 4: 39, 6: 37, 8: 39},
			"frames": 25,
			"fps": 68.0,
			"loop": false,
		},
		&"high_kick": {
			"sheets": {
				2: ROOT + "/HighKick/Boxer__HighKick_dir2.png",
				4: ROOT + "/HighKick/Boxer__HighKick_dir4.png",
				6: ROOT + "/HighKick/Boxer__HighKick_dir6.png",
				8: ROOT + "/HighKick/Boxer__HighKick_dir8.png"
			},
			"feet": {2: 36, 4: 39, 6: 37, 8: 39},
			"frames": 33,
			"fps": 68.0,
			"loop": false,
		},
		&"side_kick": {
			"sheets": {
				2: ROOT + "/SideKick/Boxer__SideKick_dir2.png",
				4: ROOT + "/SideKick/Boxer__SideKick_dir4.png",
				6: ROOT + "/SideKick/Boxer__SideKick_dir6.png",
				8: ROOT + "/SideKick/Boxer__SideKick_dir8.png"
			},
			"feet": {2: 37, 4: 38, 6: 38, 8: 38},
			"frames": 20,
			"fps": 68.0,
			"loop": false,
		},
		&"stomp_kick": {
			"sheets": {
				2: ROOT + "/StompKick/Boxer__StompKick_dir2.png",
				4: ROOT + "/StompKick/Boxer__StompKick_dir4.png",
				6: ROOT + "/StompKick/Boxer__StompKick_dir6.png",
				8: ROOT + "/StompKick/Boxer__StompKick_dir8.png"
			},
			"feet": {2: 36, 4: 38, 6: 37, 8: 39},
			"frames": 29,
			"fps": 68.0,
			"loop": false,
		},
		&"combo": {
			"sheets": {
				2: ROOT + "/Combo/Boxer__Combo_dir2.png",
				4: ROOT + "/Combo/Boxer__Combo_dir4.png",
				6: ROOT + "/Combo/Boxer__Combo_dir6.png",
				8: ROOT + "/Combo/Boxer__Combo_dir8.png"
			},
			"feet": {2: 37, 4: 39, 6: 38, 8: 39},
			"frames": 27,
			"fps": 68.0,
			"loop": false,
		},
		&"roll_forward": {
			"sheets": {
				2: ROOT + "/ForwardRoll/Boxer__ForwardRoll_dir2.png",
				4: ROOT + "/ForwardRoll/Boxer__ForwardRoll_dir4.png",
				6: ROOT + "/ForwardRoll/Boxer__ForwardRoll_dir6.png",
				8: ROOT + "/ForwardRoll/Boxer__ForwardRoll_dir8.png"
			},
			"feet": {2: 43, 4: 40, 6: 38, 8: 42},
			"frames": 16,
			"fps": 68.0,
			"loop": false,
		},
		&"roll_stand": {
			"sheets": {
				2: ROOT + "/StandRoll/Boxer__StandRoll_dir2.png",
				4: ROOT + "/StandRoll/Boxer__StandRoll_dir4.png",
				6: ROOT + "/StandRoll/Boxer__StandRoll_dir6.png",
				8: ROOT + "/StandRoll/Boxer__StandRoll_dir8.png"
			},
			"feet": {2: 37, 4: 40, 6: 43, 8: 42},
			"frames": 33,
			"fps": 68.0,
			"loop": false,
		},
		&"hit_light": {
			"sheets": {
				2: ROOT + "/HitHeadLight/Boxer__HitHeadLight_dir2.png",
				4: ROOT + "/HitHeadLight/Boxer__HitHeadLight_dir4.png",
				6: ROOT + "/HitHeadLight/Boxer__HitHeadLight_dir6.png",
				8: ROOT + "/HitHeadLight/Boxer__HitHeadLight_dir8.png"
			},
			"feet": {2: 37, 4: 38, 6: 38, 8: 39},
			"frames": 12,
			"fps": 68.0,
			"loop": false,
		},
		&"hit_body": {
			"sheets": {
				2: ROOT + "/HitBody/Boxer__HitBody_dir2.png",
				4: ROOT + "/HitBody/Boxer__HitBody_dir4.png",
				6: ROOT + "/HitBody/Boxer__HitBody_dir6.png",
				8: ROOT + "/HitBody/Boxer__HitBody_dir8.png"
			},
			"feet": {2: 37, 4: 38, 6: 39, 8: 39},
			"frames": 21,
			"fps": 68.0,
			"loop": false,
		},
		&"hit_head": {
			"sheets": {
				2: ROOT + "/HitHead/Boxer__HitHead_dir2.png",
				4: ROOT + "/HitHead/Boxer__HitHead_dir4.png",
				6: ROOT + "/HitHead/Boxer__HitHead_dir6.png",
				8: ROOT + "/HitHead/Boxer__HitHead_dir8.png"
			},
			"feet": {2: 37, 4: 38, 6: 38, 8: 39},
			"frames": 18,
			"fps": 68.0,
			"loop": false,
		},
		&"dead": {
			"sheets": {
				2: ROOT + "/Die1/Boxer__Die1_dir2.png",
				4: ROOT + "/Die1/Boxer__Die1_dir4.png",
				6: ROOT + "/Die1/Boxer__Die1_dir6.png",
				8: ROOT + "/Die1/Boxer__Die1_dir8.png"
			},
			"feet": {2: 42, 4: 44, 6: 40, 8: 41},
			"frames": 65,
			"fps": 68.0,
			"loop": false,
		},
		&"dead_alt": {
			"sheets": {
				2: ROOT + "/Die2/Boxer__Die2_dir2.png",
				4: ROOT + "/Die2/Boxer__Die2_dir4.png",
				6: ROOT + "/Die2/Boxer__Die2_dir6.png",
				8: ROOT + "/Die2/Boxer__Die2_dir8.png"
			},
			"feet": {2: 42, 4: 42, 6: 42, 8: 42},
			"frames": 63,
			"fps": 68.0,
			"loop": false,
		},
	}

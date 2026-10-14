# Personalización visual (ropa y peinados)

Punto de entrada de la carpeta. Qué es, cómo se usa y **cómo se añade** una prenda
o un peinado sin romper nada y sin gastar presupuesto.

| documento | qué contiene |
| --- | --- |
| `docs/Plan_Ropa_Peinados_Baracoa_City.md` | El plan maestro (fases, presupuesto, entregables). Manda. |
| `INFORME_COMPATIBILIDAD.md` | Fase 0: qué hay, qué se puede tocar, cuánto cuesta de verdad. |
| `PLAN_ROPA_PEINADOS.md` | Estrategia de arte y arquitectura propuesta. |
| `IMPLEMENTACION_FASE_3.md` | Lo que se construyó (sistema visual), medidas, validación y limitaciones. |
| `IMPLEMENTACION_FASE_4.md` | Lo que se construyó (pantalla del vestuario), medidas, validación en vivo y lo que falta. |
| `PIXELLAB_GENERATION_LOG.md` | Registro de generaciones (hoy: **0 de 40**). |
| `prueba_ropa_vs_base.png` | Demostración: base (izquierda) vs camiseta+pelo (derecha), 6×. |

## La idea en una frase

El personaje es un boxeador **sin camiseta** y con **2.236 fotogramas** en 92
hojas. Redibujar la ropa por IA es imposible con 40 generaciones, así que la
prenda se **calcula desde el propio dibujo**: se recolocan los píxeles de piel del
torso por los colores de la prenda. Cuesta **0 generaciones**, vale para todas las
direcciones y animaciones, y la alineación es exacta porque son los mismos
píxeles.

## Cómo añadir una camiseta o un peinado (coste 0)

Todo es **datos**, no arte. Se añade una fila a una tabla en
`scripts/presentation/customization/garment_catalog.gd`:

```gdscript
# 1) Un id.
const SHIRT_ORANGE := &"shirt_orange"

# 2) Sus cuatro tonos, en el MISMO orden que SKIN_KEYS
#    (base, sombra, luz, oscura). Ver la regla de abajo.
const SHIRT_COLORS := {
    ...
    SHIRT_ORANGE: [Color("d9822b"), Color("a85f1f"), Color("f0a860"), Color("7a4416")],
}

# 3) Añadirlo a la lista que lo publica.
static func shirt_ids() -> Array[StringName]:
    return [..., SHIRT_ORANGE]
```

Con eso ya sale en las **92 hojas** a la vez. Para probarlo:

```gdscript
player.set_shirt(GarmentCatalog.SHIRT_ORANGE)   # o set_hair(...)
```

Y en el juego, sin tocar código: **`C`** abre el **vestuario** (ver
`IMPLEMENTACION_FASE_4.md`). Navega con los ejes, elige con izquierda/derecha,
cambia de fila con arriba/abajo, confirma con `E`. Elegir es ponerse.

### Reglas que no se negocian

1. **Cuatro tonos, en el orden base → sombra → luz → oscura.** Son las claves que
   sustituyen los cuatro tonos de piel del pack (`f7a566`, `ef7d57`, `ffcd75`,
   `d05d55`). Si el orden se cruza, el sombreado del cuerpo se invierte.
2. **Los colores de estado tienen que quedar libres.** El rojo es "me han dado" y
   el violeta es "aturdido": una prenda no puede usar esos tonos o se confunde con
   un golpe. Por eso los tintes de estado mandan sobre el color propio.
3. **No hay PNG que mantener.** Añadir un color no cuesta nada. Cambiar la **forma**
   (un peinado real, una capa, un sombrero) sí necesita una imagen: eso ya es otro
   nivel, con su coste y su autorización.
4. **Nada de esto entra en el dominio ni en el combate.** Es presentación.

## Cómo comprobarlo (no se mira, se cuenta)

```bash
# Suites con los casos de la prenda.
godot --headless --script res://tests/support/test_runner.gd          # 237/237
godot --headless --script res://tests/integration/startup_runner.gd   # 35/35
```

Y la comprobación de que **se ve** (requiere `xvfb`, no vale `--headless`):

```bash
export LC_ALL=C LANG=C
xvfb-run -a godot --rendering-driver opengl3 --script res://tests/support/screenshot.gd -- /tmp/shot.png 60
```

Una captura se revisa **contando píxeles** del color de la prenda, no mirándola.
Los números exactos de la última validación están en `IMPLEMENTACION_FASE_3.md` y
`IMPLEMENTACION_FASE_4.md` (ahí el recuento es exacto: 62 píxeles de prenda en
pantalla = 62 píxeles opacos de la superposición).

## Lo que queda abierto

- **Peinado con forma.** El color de pelo solo pinta la coronilla, porque el pack
  va rapado. Un peinado de verdad necesita un overlay por dirección: el usuario
  decidió **dibujarlo gratis** con `pixelart_workbench` (0 generaciones). Es el
  siguiente incremento; lleva su propia capa y sus pruebas.
- **Interfaz de selección — hecha.** Vestuario con `C`, panel propio, vista previa
  espejo y exclusión mutua con la mochila. Detalle en `IMPLEMENTACION_FASE_4.md`.
- **Persistencia.** La apariencia no se guarda en `GameSession`; se pierde al
  cerrar el juego.

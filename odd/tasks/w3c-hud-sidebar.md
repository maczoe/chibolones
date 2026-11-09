# W3c: in-game HUD sidebar (artboard B)

Implement design/shop-hud-planning/02-hud-sidebar.html (chosen by the
user) in the gameplay HUD. Placeholders for sprites; colors and screen
proportions close to the artboard (1600x900 design -> 1920x1080 game).

## Specs

S1: User request (verbatim): «vamos a implementar B — HUD Barra Lateral
    (Balatro, Slay the Spire) en el hud de godot para el gameplay, si
    necesitas agregar sprites usa placeholders por ahora, necesito
    verlo ingame antes de decidir, manten los colores y las
    proporciones en pantalla los más cercano posible a artboard»
S2: Layout (artboard 02 + canvas comments resolved): sidebar izquierda
    (~336px en 1920) con: título (theme_name / TABLERO N · BLOQUE X ·
    JEFE), Objetivo con barra de progreso, Puntos, Dinero, Chibolones
    (propios/tamano + quedan N tiros), En mano (orb sprite + nombre +
    descripción del efecto) y bolso scrollable con la canica activa
    resaltada (clic selecciona). Rail derecho arriba: premios activos
    (orb + nombre + descripción del efecto). Arriba centro: regla del
    tablero (borde rosa, texto amarillo). Abajo centro: franja de
    mensajes de ayuda/notificación (borde rosa, texto amarillo,
    sublínea violeta). Abajo izquierda: zona BONUS reservada (oculta
    hasta que existan bonos).
S3: Convenciones de texto: «Dinero» (no Cash), «Chibolones» (no
    canicas) como etiqueta del stat, «Bonus» para bonos. Paleta:
    #120a26/#1d1240/#241552/#2e1b58/#ffe066/#ff6fb5/#4deeea/#cdb8ff.
S4: Sprites placeholder: orb de canica = círculo con palette[0] de la
    def (por material un color característico); orb de premio =
    círculo cian/teal. Nada de assets nuevos.
S5: Compatibilidad: la API pública del HUD (set_shots, set_timer,
    set_selected_marble, set_prizes, flash, show_game_over,
    show_defeat, set_breakdown y labels usados por tests) sigue
    existiendo; los tests que pinnean textos viejos se actualizan al
    nuevo formato.

## Tasks

T1 (S2,S3,S4,S5): Rewrite scripts/board/hud.gd to the sidebar layout;
    adapt board.gd call sites; bag selection signal; update tests
    (run_loop, inventory, debug_mode) to the new texts. Route: inline.

## Log

L1: S1 (verbatim). Elección del usuario: artboard B del design
    shop-hud-planning, iterado con 8 comentarios de canvas (resueltos).

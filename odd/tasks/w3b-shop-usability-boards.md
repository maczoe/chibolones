# W3b: shop usability & board variety

Follow-up unit after the user's first full playtest (reached board 6).
Four changes: inventory view + sell, effect descriptions, shop focus
restore, random board order. Then the user replays and gives feedback.

## Specs

S1: User observations (verbatim):
    1. «Necesito poder ver mi inventario actual (premios y canicas), el
    inventario se puede vender a un valor de rescate de la mitad del
    precio de compra redondeado hacia arriba, esto se debe a que me
    lleno rápido de inventario y no puedo cambiar a otros premios que
    tengan sinergia»
    2. «Necesito saber que hacen los premios y las canicas, agrega una
    descripción del efecto visible en la pantalla de compras»
    3. «Al seleccionar un premio o comprar en la tienda se pierde el
    focus de los controles y tengo que usar el mouse para continuar o
    seguir comprando, podrías repararlo»
    4. «Para dar variedad a una run, podrías colocar los tableros de
    manera aleatoria, solo tomando en cuenta que el tablero 1 siempre
    será el básico y los tableros de jefe permanecen pero de manera
    aleatoria»

S2: Decision: rescate = mitad del precio de lista ACTUAL del item (el
    escalado por bloque), redondeado hacia arriba. La venta vive en la
    tienda (sección de inventario) y solo ahí. Guardia: no se puede
    vender la última canica del bolso; los premios se venden libres.
    Vender saca del inventario de la run (una copia por venta).

S3: La tienda muestra la descripción del efecto de cada canica y premio
    en venta (texto de efecto, derivado de effect+params; el flavor
    sigue siendo lore aparte).

S4: Foco: tras comprar, vender o reroll, el foco vuelve al primer
    control habilitado de la tienda; los botones deshabilitados siguen
    fuera del ciclo de foco. Todo manejable sin mouse.

S5: Orden de tableros (GDD §3): tablero 1 = tablero básico; jefes fijos
    en 4/8/12/16/20 con el tier de su bloque; los demás tableros se
    sortean al azar del pool no-jefe, sin repeticiones dentro de cada
    bloque. Orden nuevo por run. Endless: 21+ tableros de tier jefe al
    azar. El modo debug conserva su tablero elegido (sin azar).

## Tasks

T1 (S3): Effect descriptions: MarbleDef.effect_description() y
    PrizeDef.effect_description(); la tienda las muestra en cada card.
    Route: inline.
T2 (S2): Inventory section in shop: lista de canicas y premios con
    cantidad, botón vender por item, Economy.rescue_price(def, block),
    Game.sell_marble/sell_prize con guardia de última canica.
    Route: inline.
T3 (S4): Shop focus restore after buy/sell/reroll (refoco al primer
    habilitado). Route: inline.
T4 (S5): Random board order per run in Game (board 1 basic, bosses
    fixed, no repeats per block; endless boss-tier random; debug
    untouched). Route: inline.
T5: Tests (sell/rescue, descriptions, focus, board order) + suite
    completa verde. Route: inline.

## Log

L1: Las 4 observaciones del playtest del usuario (S1, verbatim).
L2: Decisiones: rescate mitad del precio actual; mínimo 1 canica;
    jefes fijos + azar normal; refoco automático en la tienda.

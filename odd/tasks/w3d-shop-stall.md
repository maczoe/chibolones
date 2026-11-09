# W3d: shop screen artboard 06 (fair stall)

Implement design/shop-hud-planning/06-shop-stall.html in the Godot shop
scene, keeping the artboard's design as closely as the engine allows.
Keyboard/gamepad arrows AND touch/mobile must both work; the inventory
section needs vertical scroll capacity.

## Specs

S1: User request (verbatim): «Podrías implementar el diseño del artboard
    C — Tienda Puesto de Feria (Dave the Diver, Balatro) en la tienda de
    Godot tratando de mantener el diseño del artboard lo mejor posible
    manteniendo un estilo coherente, y considerando que se podrá navegar
    con flechas y con controle táctiles en mobile, también toma en cuenta
    que la parte del inventario pueda llegar a necesitar scroll vertical»
S2: Layout (artboard 06 iterado, 10 comentarios de canvas resueltos):
    cabecera con banderines + título "Tienda de la Feria" + subtítulo
    (TABLERO N · BLOQUE X DE 5), badge de dinero arriba derecha y badges
    de topes debajo; mostrador central de 4 cards (CHIBOLON/PREMIO, orb
    sprite, nombre, descripción, precio junto a COMPRAR); sección inferior
    de 2 columnas al ancho del mostrador (1248px@1720): Servicios+Opciones
    (canica extra y reroll con precio junto al botón; Opciones: CONTINUAR,
    INFORMACIÓN PARTIDA, REGRESAR AL MENU, ABANDONAR) e inventario con
    scroll vertical (filas .service-row: orb + nombre + desc violeta +
    precio junto a VENDER). Estética: paleta candy (#120a26/#1d1240/
    #241552/#2e1b58/#ffe066/#ff6fb5/#4deeea/#cdb8ff), banderines rosa/
    cian/amarillo.
S3: Navegación: flechas (focus neighbors + arrows en grilla), Enter
    activa; touch: botones reales clickeables, scroll táctil del
    inventario. El foco inicial va a COMPRAR de la primera card;
    después de comprar/vender/reroll, refoco al primer habilitado.
S4: Convenciones vigentes: rótulo "CHIBOLON" en cards de canicas;
    textos alineados a la izquierda en las columnas inferiores; precios
    inline con su botón; desc siempre visible (filas uniformes, ellipsis
    en 1 línea si excede); dinero = $N.
S5: Compatibilidad: se mantienen las APIs de pantalla usadas por tests
    (shop_focus: _find_buttons, CONTINUAR habilitado con foco inicial,
    buy buttons COMPRAR, VENDER rows, disabled fuera del ciclo de foco)
    y las de Game (buy_marble/buy_prize/buy_extra_pack/reroll_shop/
    sell_marble/sell_prize). Los textos esperados por tests se actualizan
    al nuevo formato.
S6: Botones de opciones nuevos: INFORMACIÓN PARTIDA, REGRESAR AL MENU y
    ABANDONAR quedan como acciones definidas: INFORMACIÓN PARTIDA abre
    un panel con el estado de la run (tablero, bloque, dinero, bolso,
    premios); REGRESAR AL MENU y ABANDONAR terminan la run (confirmación
    simple para ABANDONAR) y vuelven al menú. Su lógica es mínima (W3d);
    la pantalla de información de partida completa es mejora futura.

## Tasks

T1 (S1-S6): Rewrite scripts/ui/shop_screen.gd to the fair-stall layout;
    option buttons with minimal handlers; focus navigation + touch;
    inventory scroll; update tests. Route: inline. Commit: b6f51f3
    (suite 16/16 verde, gdcheck OK). Pendiente: partida visual del
    usuario.

## Log

L1: S1 (verbatim). Artboard 06 elegido e iterado por el usuario (10
    comentarios de canvas resueltos).

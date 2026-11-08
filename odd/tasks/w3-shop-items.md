# W3: shop v1, economy & items

Unit = content-plan W3: 10 marbles, 10 prizes, shop v1, playable end to end.
Numbers are tunable in M5; effects extend the M2 hook contract (on_event).

## Specs

S1: User request (verbatim): «vamos a iniciar con la fase de implementación
    de tienda, economía e items, me vas ayudando a generar esta unidad
    haciendo preguntas y yo contesto». Scope decision: «W3 completa» —
    los 10 canicas (content-plan §4.1), los 10 premios (§4.2) y shop v1,
    con criterio de listo «Jugable punta a punta»: gana tablero → tienda
    abre → compra → efecto aplica en el tablero siguiente.

S2: Decision: «Precio en el .tres del item» — cada MarbleDef/PrizeDef
    guarda su precio base (MarbleDef.price y PrizeDef.price ya existen,
    nunca leídos). Economy mantiene solo la escala por bloque
    (price_scale). La tabla DEF_BASE_PRICES de economy.gd deja de ser
    fuente; los precios de common/fire/glass/trompo migran a sus .tres.

S3: Decision: «Bandas por rareza» — común $2-3, uncommon $4-5, rara $7.
    Rarezas según content-plan: canicas 5 comunes / 3 uncommon / 2 raras;
    premios 6 comunes / 3 uncommon / 1 rara. Precios concretos (tunables):
    Canicas — Comun C$2, Fuego C$3, Rebote C$3, Agata C$3, Remolino C$3,
    Vidrio U$4, Teledirigida U$5, Trampa U$5, Nitro R$7, Espejo R$7.
    Premios — Pelota C$2, Osito C$3, Muñeco C$3, Billete C$3, Carpa C$3,
    Globo C$3, Trompo U$4, Rayo U$4, Boleto U$5, Corona R$7.
    Vidrio: break 20% (content-plan: «the 20% value lands with the M3
    marble data»; hoy glass.tres tiene 0.25 → corregir a 0.20).

S4: Decision: «Extendemos el contrato» — implementar on_event(event, ctx)
    según docs/architecture.md:61-75 (hoy no existe). Puntos de evento
    nuevos necesarios: board_end, refund, marble_spawn, throw_start/end,
    money_changed. Los premios dejan de estar special-caseados
    (wall_hit_mult en prize_def.gd:29-33 y board.gd:1003-1006 se migran
    al contrato).

S5: Decision: «Sorteo aleatorio con pesos» — el stock de la tienda sortea
    2 canicas + 2 premios del pool desbloqueado con pesos por rareza
    (común más frecuente), más pack extra y reroll (content-plan §7).
    Sin repeticiones dentro de un stock.

S6: Decision del usuario (verbatim): «Implementar tope, 2 slot de bolso
    de premios al inicio, 10 slot de canicas al inicio». Comprar sobre el
    tope queda bloqueado (UI deshabilitada + API rechaza). Carpa en
    Miniatura = +1 slot de canicas (GDD §4.2: «Carpa en Miniatura (+1
    marble slot in the bag)»). Los slots de premios quedan fijos en 2
    para W3.

S7: (Corregido con D1 revisado del GDD): toda canica jugada sale del ammo
    al resolverse el throw (S4, ya implementado y probado en
    tests/inventory.gd) y el inventario completo se restaura al inicio de
    cada tablero; solo la rotura de Vidrio la quita para el resto de la
    run. La distincion common/magic es de comportamiento del efecto, no
    de consumo por tirada: single_use queda como marcador de categoria,
    sin logica nueva.

S8: Efectos de canicas (content-plan §4.1, verbatim resumido en Log L2):
    Común (baseline), Fuego speed x1.25, Vidrio score x2 + break 20%,
    Agata (mass 1.5, estable al viento), Remolino (curva hacia el centro),
    Teledirigida (elegir notch, homing suave), Rebote (refund incluso
    fuera de los lados), Nitro (speed x1.6, un solo uso), Trampa (se
    clava en cualquier toque, incluso rápido), Espejo (copia el score del
    throw anterior).

S9: Efectos de premios (content-plan §4.2): Osito (+50 flat al terminar
    el tablero), Trompo de Madera (x1.5 por golpe de pared, ya embarcado),
    Muñeco de Nieve (skip_speed a la mitad), Pelota de Goma (rebote de
    canicas x1.3), Billete de la Suerte (+$2 por refund), Globo (un throw
    extra por tablero), Boleto Retro (el primer throw de cada tablero se
    repite si hizo score 0), Carpa en Miniatura (+1 slot de bolso),
    Rayo (canicas de fuego speed x1.5), Corona del Circo (x1.1 a todo,
    rara).

S10: Verificación: tests deterministas headless (patrón tests/run_loop.gd)
     para economía, precios, topes, compras, single-use y cada efecto
     observable; suite completa verde; run manual punta a punta.

## Tasks

T1 (S2,S3): Prices/rarity into defs: add rarity to MarbleDef, set price
    + rarity on all .tres, Economy reads def price, retire
    DEF_BASE_PRICES, fix glass break 0.20. Route: inline.
    Commit: 307f6ad feat(items): item-owned base prices and rarity
T2 (S4): Implement on_event hook contract (architecture.md:61-75):
    PrizeDef.on_event + registration, EventBus wiring for board_end /
    refund / marble_spawn / throw lifecycle; migrate trompo off special
    case. Route: inline. Commit: 80bc06d feat(hooks): M3 on_event contract
T3 (S9): Prize effects: Osito, Billete, Muñeco, Pelota, Rayo, Corona,
    Globo (extra_throws wiring). Route: inline.
    Commit: 26608fe feat(prizes): wave-3 prize effects
T4 (S6,S7): Bag caps + purchase APIs in Game (buy_marble/buy_prize,
    caps 10/2, Carpa +1 marble slot, single-use consumption on throw).
    Route: inline. Commit: feat(run): bag caps and purchase APIs
T5 (S8): Marble effects needing new systems: Agata (wind steady),
    Remolino (center curve), Teledirigida (homing), Rebote (refund),
    Nitro (one-shot), Trampa (embed anywhere), Espejo (copy prev score).
    Route: inline. Commit: feat(marbles): wave-3 marble effects
T6 (S1,S3,S5): Content data: remaining 7 marbles + 9 prizes .tres with
    price/rarity/flavor; random weighted stock; shop v1 UI functional
    (buy, reroll, extra pack, money, caps). Route: inline.
    Commit: feat(shop): functional shop and wave-3 content
T7 (S10): End-to-end verification: extend tests/run_loop.gd (economy,
    purchases, caps, single-use, effects), full suite green, manual run.

## Log

L1: «vamos a iniciar con la fase de implementación de tienda, economía e
    items, me vas ayudando a generar esta unidad haciendo preguntas y yo
    contesto»
L2: Decisiones del usuario (2026-01, sesión W3): «W3 completa» · «Precio
    en el .tres del item» · «Extendemos el contrato» · «Jugable punta a
    punta» · «Bandas por rareza» · «Sorteo aleatorio con pesos» ·
    «Implementar tope, 2 slot de bolso de premios al inicio, 10 slot de
    canicas al inicio»
L3: Mapa de exploración: MarbleDef.price nunca leído; on_event no
    implementado (architecture.md:74); Game.extra_throws escrito y jamás
    leído (game.gd:66); single_use sin usar; sin API de compra;
    shop_screen.gd placeholder con CONTINUAR solo.
L4: T2 implementado: PrizeDef effect+params (EFFECT_EVENTS),
    Game.dispatch_event, board dispatches throw_started/marble_spawn/
    wall_hit/board_ended + relay throw_ended, refund money_delta por
    EventBus. Trompo migrado a effect+params (wall_hit_mult retirado).
    Nota de slice: 547 lineas en 2 commits (307f6ad + 80bc06d) — al
    cerrar la feature, evaluar chained PRs; proximo commit inicia slice
    nuevo.
L5: T3 implementado: efectos Globo (extra_throw), Pelota (bounce_scale
    via ctx marble_spawn), Rayo (fire_speed_mult condicionado a def.id),
    Muñeco (skip_speed_scale, board.effective_skip_speed), Corona
    (score_mult_all: embeds + total final). Osito/Billete ya en T2.
    Aprendizaje: apply_central_impulse no se refleja en linear_velocity
    hasta el proximo physics step (los tests deben await 1 frame).
L6: Correccion de S7 al reconciliar con D1 revisado del GDD (decision
    de usuario 2026-11-08): el consumo por tirada ya es el comportamiento
    del ammo para TODAS las canicas; single_use sin logica nueva.

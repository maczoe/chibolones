# Debug mode + marble inventory

Single-board debug match setup from the main menu, and a consumable marble
inventory per board (loadout restored between boards).

## Specs

Quotes are the user's verbatim words unless marked [decision].

- S1: "en una opción llamada debug mode nueva en el menu principal al entrar
  en debug mode, se podrá personalizar una partida de un solo tablero"
- S2: "se puede seleccionar el tablero, en el menu indica el nombre del
  tablero y cual es el gimmick"
- S3: "también se pueden seleccionar de alguna manera los premios activos y
  las canicas para iniciar (las 5 iniciales)"
- S4: "hay un lista de canicas que están en el inventario, el usuario puede
  seleccionar cual jugar y después de jugarla sale de ese inventario, por lo
  que no se puede volver a jugar la canica de la lista al anotar"
- S5 [decision]: "Todas se consumen en el tablero, pero se restauran en el
  siguiente tablero" — every played marble (scored, settled, off-board,
  timed out) leaves the board ammo; the full run inventory is restored as
  ammo when the next board starts. A BROKEN marble (glass durability roll,
  M2) is not restored: it is lost for the rest of the run.
- S6 [decision]: empty ammo without reaching the objective = defeat
  (board lost, run over), same as running out of shots today.
- S7 [decision]: a refunded marble (exits through the player edge) returns
  to the board ammo; it is not consumed.
- S8 [decision]: debug mode scope "Esencial": board picker (shows board
  name + gimmick), active prize picker, starting marble picker; block
  factor x1, no money/economy in the match; results return to the menu.
- S9 [derived]: throws per board = marbles in the board ammo (no fixed
  `shots_per_board` cap when running with the inventory); HUD "Canicas
  restantes" shows ammo left / ammo total.
- S10 [derived]: a normal run starts with 5 common marbles in the inventory
  (economy v1, content-plan §2). Debug mode uses exactly the marbles picked
  in the menu.

## Tasks

- T1 (S4,S5,S6,S7,S9,S10) Inventory core: run inventory in `Game`,
  per-board ammo copy, consume on throw resolve, refund returns it, restore
  at board start, break = permanent loss, defeat when ammo empties short of
  objective, HUD count. Route: worker. Commit: 14a6741 DONE
- T2 (S1,S2,S3,S8) Debug mode: new menu option, debug setup screen (board
  picker with name+gimmick, prize toggles, marble picker), single-board
  custom match launch, back to menu on result. Route: worker. Commit:
  d8fb954 DONE
- T3 Docs: README (menu + inventory rules), GDD D1 revision note. Route:
  inline. Commit: docs.

## Log

- L1: "ok, para realizar el ajuste y el debug de tableros necesito que
  agregues un par de cosas en una opción llamada debug mode nueva en el
  menu principal al entrar en debug mode, se podrá personalizar una partida
  de un solo tablero, se puede seleccionar el tablero, en el menu indica el
  nombre del tablero y cual es el gimmick, también se pueden seleccionar de
  alguna manera los premios activos y las canicas para iniciar (las 5
  iniciales). Aprovechando podemos programar el inventario de canica en la
  partida, hasta ahora hay 5 tiros que pueden ser de cualquiera de las
  canicas programadas, la idea es que hay un lista de canicas que están en
  el inventario, el usuario puede seleccionar cual jugar y después de
  jugarla sale de ese inventario, por lo que no se puede volver a jugar la
  canica de la lista al anotar, de esta manera se agrega el tema estrategia
  para decidir que canicas comprar cuales llevar en el inventario, sinergias
  con los premios y dificultad al tener canicas especiales compradas
  limitadas"
- L2 [decisions]: all marbles consumed in-board, restored next board (user
  custom answer); empty ammo short of objective = defeat; refund returns to
  inventory; debug scope Esencial.

## Seams (explore map, path:line)

- Bag today: `autoload/game.gd:41` `bag: Array[MarbleDef]`, seeded from
  `SAMPLE_MARBLES` (`:23`, `:67-72`); selection cycling in
  `scripts/board/board.gd:343-364`; launch `board.gd:386-427`; resolves in
  `_update_flight` `board.gd:430-510` (refund `:442`, off_board `:450`,
  settled `:483`, timed_out `:496`, embed `:518-539`).
- Removal seam: `board.gd:751-766` `_remove_from_bag()` +
  `EventBus.marble_removed` (`autoload/event_bus.gd:25-27`) — reason
  `&"thrown"` documented, never emitted yet.
- Shots: `scripts/core/shooting_rules.gd:30`, consumed at
  `scripts/board/board.gd:97` and `:424`. `Game.extra_throws`
  (`game.gd:58`) is dead code.
- Run state: `autoload/game.gd` Phase enum `:7`, `start_run` `:61-84`
  (hardcodes bag/prize/board 1), board identity `:97-141`. No single-board
  entry point.
- Prizes: `Game.prizes` (`game.gd:43`, one hardcoded trompo `:24`,
  `:73-75`); consumed by `scripts/scoring/score_engine.gd:44-48`, HUD
  badges `board.gd:122` / `hud.gd set_prizes`.
- Menu: `scripts/ui/menu.gd` (`_build` `:18`, JUGAR `:46-48`,
  `_on_play_pressed` `:68-70` → `Game.start_run()`).
- ContentDB enumerators for pickers: `autoload/content_db.gd:55,59,95,99`.
- HUD: `scripts/board/hud.gd` (`set_shots` `:67`, `set_selected_marble`
  `:78`, `set_prizes` `:~108`).
- Tests: `tests/*.gd` are SceneTree scripts installing autoloads manually
  (see `tests/run_loop.gd:16-35`); run with
  `godot --headless --path . --script res://tests/<x>.gd` (README:239-244).

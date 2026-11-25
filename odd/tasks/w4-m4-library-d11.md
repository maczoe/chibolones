# W4/M4: library, persistence and unlocks (D11)

Turns the per-run collection into a profile that survives the process: a save
file, an unlock pool that grows with the player, and the library screen D11
asks for (index of marbles and prizes with rarity, name, lore, effect text and
placeholder art). Source: `docs/gdd/design-decisions-v2.md` D11 + D3 in
`docs/gdd/gdd.md`, ordered as W4/M4 by `docs/gdd/content-plan.md`.

## Specs

- S1 (user request, verbatim): «después de dejar todo limpio iniciamos con
  W4/M4 que incluye D11».
- S2 (D3, `docs/gdd/gdd.md:181-185`, verbatim): «**D3 resolved: unlocks
  content.** The library persists across runs (save file); discovering/obtaining
  a marble or prize adds it to the pool available in future runs' shops. First
  runs draw from a starter pool; the collection grows the roguelike over time.
  Locked entries show as silhouettes with a hint, fair-catalog style.»
- S3 (D11, `docs/gdd/design-decisions-v2.md`, verbatim): «The library gains an
  index of: cosmetic prizes, usable prizes, consumable prizes, game songs, game
  sound effects and marbles. Every entry shows: rarity (common / rare /
  legendary), name, lore text, effect description, and a 3D model + sprite.
  First wave may use tinted placeholder models; lore + effect text define
  identity before art.»
- S4 (W4/M4 rows, verbatim): «| W4 | Library + unlocks (save file), first-run
  starter pool | M4 |»; «| **M4** | Library + persistence (per D3 and D11),
  unlock pool if chosen | save/load round-trip test |».
- S5 (open question being closed here, verbatim): «Unlock pool split for first
  runs (M4): which 6 marbles / 6 prizes are available before any unlock.»
- S6 [decision 2026-11-23, option picked by the user] Unlock source: **both**
  — «logros: garantizados, en orden / cofres: 10% de revelar item bloqueado /
  (tope: 1 revelación por run)».
- S7 [decision 2026-11-23] Save scope: **collection + stats + settings**
  («Colección + stats + ajustes»). No meta currency and no tickets: those
  depend on D15.
- S8 [decision 2026-11-23] Library v1 shows **marbles + prizes** (permanent,
  consumable, cosmetic) plus **empty song/SFX tabs** with a
  «próximamente» card, so the information structure is fixed now.
- S9: Settings persist (audio levels, text speed) and are applied at boot; no
  settings screen is required by this unit.
- S10: Existing behavior preserved: a profile written by a future version, a
  truncated file or a missing file never destroys collected data silently — the
  file is written atomically and an unreadable file is kept aside, not
  overwritten in place.

## Tasks

- T1 [S7,S10] `SaveGame` autoload: versioned profile dict (collection, unlocks,
  stats, settings), pure `to_dict`/`from_dict`, atomic write via temp + rename,
  corrupt-file quarantine, defaults on first run. Route: inline.
- T2 [S5,S6] Starter pool + unlock table as data: 6 marbles / 6 prizes start
  available, milestone unlocks by board cleared and run won, `available_*`
  queries. Route: inline.
- T3 [S6] Chest discovery: 10% chance to reveal a locked prize, at most one
  reveal per run, revealed item unlocks and collects. Route: inline.
- T4 [S2,S7] Acquisition hooks: marbles and prizes collected into the profile,
  run end records stats, starter pool feeds `Game.STARTING_MARBLES`. Route:
  inline.
- T5 [S9] Settings persistence + boot application. Route: inline.
- T6 [S3,S8] Library screen (`scenes/library/library.tscn` +
  `scripts/ui/library_screen.gd`): tabs, entry cards (rarity, name, lore, effect
  text, placeholder art), locked silhouettes with a hint, keyboard/gamepad/touch
  navigation. Route: inline.
- T7 [S1] Entry points: menu button enabled, library reachable from the pause
  menu. Route: inline.
- T8 [S4] `tests/save_load.gd` (round trip, defaults, corrupt file, idempotent
  unlock/collect, stats accumulation) plus extensions to the chest, economy and
  run suites; full suite green. Route: inline.
- T9 [S4] Docs: M4 DELIVERED, W4 status, D11 status, README if a command
  changed. Route: inline.

## Result

Closed 2026-11-23 on branch `feat/w4-library-unlocks`; every task DONE with a
commit holding it:

- T1 + T2 — `03bea82`: `autoload/save_game.gd`, `scripts/core/unlock_table.gd`,
  `data/balance/unlocks.tres`, `tests/save_load.gd`, `tests/unlocks.gd`.
- T3 — `59dd09d`: `Economy.chest_draw_discovery` + `chest_discovery_pool`, the
  per-run cap in `Game.discovery_used`, board wiring, `tests/chest_discovery.gd`.
- T4 — `ed19ff3`: shop stock from the unlocked pool, collection hooks,
  milestone unlock on board clear, run-end stats.
- T5 — `5b37257`: settings applied at boot (`apply_settings`).
- T6 + T7 — `9779ff7`: `scenes/library/`, `scripts/ui/library_screen.gd`, menu
  and pause entry points, `tests/library.gd`.
- T8 — full suite green (every `tests/*.gd`), plus an independent verification
  pass that found three real defects (see L7); the fixes and their regressions
  are in the commit that follows this document.
- T9 — this status block, `docs/architecture.md` M4 DELIVERED, the W4 row and
  the resolved pool split in `content-plan.md`, D11 moved to implemented in
  `design-decisions-v2.md`, and the `gdd.md` meta loop.

Contenido de `data/balance/unlocks.tres` (tuning lives there, not in code):
starter marbles `agata, common, fire, rebote, remolino, glass`; starter prizes
`muneco, globo, osito, carpa, trompo, pelota`; milestones board 4
`teledirigida`, 8 `rayo`, 12 `trampa`, 16 `corona`, 20 `espejo`; run won `nitro`
+ `boleto`. Cosmetics and `billete` only arrive through a chest discovery.

Pending for the user: one visual playtest of the library (menu entry, locked
silhouettes, the collection marker) and of a first run's shop pool.

## Log

- L1 (user request, verbatim): «puedes ordenar la documentación, limpiar el
  árbol, el hud y shop están bien así por ahora márcalo done, después de dejar
  todo limpio iniciamos con W4/M4 que incluye D11».
- L2 (audit before this unit, commit 6e3f1bc): the four W3 units closed with the
  user's acceptance «el hud y shop están bien así por ahora»; `project.godot` had
  lost its `[rendering]` section (M0 T1's mobile fallback) and was restored; the
  five dirty `.svg.import` files were line-ending noise only.
- L3 (groundwork map, 2026-11-23): no persistence exists at all (zero `user://`,
  `FileAccess`, `JSON`), no unlock concept (`autoload/economy.gd:80,91,166` only
  filters per-run duplicates), `Game.cosmetics` (`autoload/game.gd:63`) is the
  only cosmetic record and dies with the run, the menu library button is a
  disabled placeholder (`scripts/ui/menu.gd:53-56`), and no library artboard
  exists in `design/`.
- L4 (decisions, user answers): unlock source = achievements + chest discovery
  (S6); save scope = collection + stats + settings (S7); library v1 = marbles +
  prizes + empty song/SFX tabs (S8).
- L5 (starter pool proposal, to adjust in playtest): marbles `agata, common,
  fire, rebote, remolino` (the five commons already in `STARTING_MARBLES`) +
  `glass`; prizes `muneco, globo, osito, carpa, trompo, pelota`. Achievements:
  board 4 → `teledirigida`, board 8 → `rayo`, board 12 → `trampa`, board 16 →
  `corona`, board 20 → `espejo`, run won → `boleto` + `nitro`. Cosmetics
  (`banderin`, `foto`, `silbato`) and `billete` come from chest discovery.
- L6 (T6/T7, delegated `gentle-ai-worker`): library screen built in code with six
  tabs, silhouette cards with the milestone/chest hint, "en la colección" marker
  and per-tab counts ("CANICAS 6/10"); menu entry via `change_scene_to_node` with
  `return_to = "menu"`; the pause entry instantiates the library as a child
  overlay instead of changing scene, because the board is the live scene and a
  scene change would discard the run. The first handoff timed out while reading
  `shop_screen.gd`, so it was relaunched with an explicit line-range reading
  budget.
- L7 (T8, independent verification, verdict FAIL): the persistence core held
  (atomic write, quarantine, validation, idempotence, round trip), but three real
  defects landed: (A) `_quarantine` deleted a previous `.corrupt` backup before
  moving the new one; (B) a restructured future-version section was silently
  dropped on load+save; (C) Godot 4.7 registers project autoloads under
  `--script` too, so `run_loop.gd` wrote the developer's real `user://profile.json`
  through the T4 hooks. Advisories: int overflow on stats, type-only settings
  validation, stale "autoloads are not registered" comments.
- L8 (fixes, T8): quarantine now uses the first free `.corrupt.N` name so no copy
  aside is ever deleted; a profile whose `version` is newer than ours is copied to
  `<path>.v<version>` before the first save on top of it; `SaveGame._ready()`
  points the path at `user://test_<suite>.json` when the engine runs with
  `--script` (verified: `profile.json` mtime unchanged across a `run_loop` run,
  `test_run_loop.json` created instead); stats are clamped and must be finite,
  numeric settings are clamped and non-numeric ones fall back to the default; the
  stale comments in `tests/chests.gd`, `tests/run_loop.gd` and `tests/library.gd`
  corrected.
- L9 (regressions added): `save_load.gd` grows four cases — two unreadable
  profiles keep both copies, a `.v99` backup keeps a restructured future profile,
  garbage numbers keep sane defaults, and a `--script` run never points at the
  player profile — plus the dead-suite guard (44 checks observed).
- L10 (T8, lint): `gdlint` capped the class at 20 public methods and `SaveGame`
  had 23 — the profile facade was also doing audio. The audio application moved
  to `scripts/core/audio_settings.gd` (`AudioSettings.apply(save)`), the unused
  `has_profile()` is gone and the unlock-table accessor became the private
  `_table()`; the public surface is the profile API only.

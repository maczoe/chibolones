# M2.5 — Board identity (theme, colors, backdrop variant, emblem)

Give each of the 20 run boards its own identity: name + active effects
in the HUD, per-board palette, a backdrop shader variant, and a
representative SVG emblem (deck art). Board definitions become data:
20 BoardDef .tres files replace the single classic def for the run.

## Specs

S1 (user): "agregar el nombre del tablero y el efecto en el hud para identificarlo"
S2 (user): "cada tablero tenga un color diferente, un fondo con shader diferente y una imagen svg representativa del tema"
S3 (content-plan §3): board names/gimmicks per the 20-board table; modifiers assignment moves into BoardDef data.

## Tasks

T1 [S2,S3] 20 BoardDefs (board_01..board_20.tres) with theme_name from content-plan, per-board palette, backdrop style/colors, emblem SVG, modifiers list. Commit W1.
  - Evidence: `data/boards/board_01..board_20.tres` (board N = def N-1) + `data/art/emblem_01..emblem_20.svg`; palettes per block, `modifiers` list per the U3 mapping.
T2 [S2] Backdrop shader variants (waves/spiral/rays) + BoardDef.backdrop_style field. Commit W1.
  - Evidence: `backdrop.gdshader` (unchanged waves) plus `backdrop_spiral.gdshader` and `backdrop_rays.gdshader`, same uniforms; `BoardDef.backdrop_style` + `backdrop_shader_path()` (unknown = waves); `board.gd _build_backdrop()` picks it.
T3 [S1] HUD board title + effects line; announcements keep working. Commit W2.
  - Evidence: `hud.set_board_title()` (top-center name + effects, `Sin modificadores` when none); `board.gd` sets it from the def and opens with the `Tablero N: <nombre>` cue, then the modifier announcements, then the controls hint.
T4 [S1-S3] Tests: defs load, unique ids/names, modifiers match content-plan mapping, board scene uses run board's def; all suites green. Commit W2.
  - Evidence: `tests/themes.gd` prints THEMES OK (defs/emblems/backdrop styles, modifier mapping incl. endless clamp, board 4 renders "El Tablero Borracho" with Borracho in the HUD, no-run path uses def 0 objective-less, boss base 100 / normal 60 semantics); smoke, run_loop and hooks stay green.
T5 Docs (README boards, architecture, content-plan cross-check). Commit W3.
  - Evidence: README board section (20 boards table, block palettes, backdrop variants, emblem, HUD identity) + tests section; `docs/architecture.md` M2.5 row and BoardDef type note; content-plan §3 "boards implemented as data (M2.5)" note and §4.3 assignment update.

## Log

L1 (user): "podrias agregar el nombre del tablero y el efecto en el hud para identificarlo, ademas podrias hacer que cada tablero tenga un color diferente, un fondo con shader diferente y una imagen svg representativa del tema, es para darle flavor a cada tablero"

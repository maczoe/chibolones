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
T2 [S2] Backdrop shader variants (waves/spiral/rays) + BoardDef.backdrop_style field. Commit W1.
T3 [S1] HUD board title + effects line; announcements keep working. Commit W2.
T4 [S1-S3] Tests: defs load, unique ids/names, modifiers match content-plan mapping, board scene uses run board's def; all suites green. Commit W2.
T5 Docs (README boards, architecture, content-plan cross-check). Commit W3.

## Log

L1 (user): "podrias agregar el nombre del tablero y el efecto en el hud para identificarlo, ademas podrias hacer que cada tablero tenga un color diferente, un fondo con shader diferente y una imagen svg representativa del tema, es para darle flavor a cada tablero"

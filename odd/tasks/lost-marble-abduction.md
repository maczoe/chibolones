# Lost marble abduction

Marbles trapped bouncing near embedded marbles (magnet, wind, or plain
contact) hang the throw until timeout; lost marbles now get a UFO-style
vertical abduction.

## Specs

- S6: "hay un problema que ocurre con los tableros de magneto, viento o simplemente cuando existe una canica en un agujero y otra canica llega cerca del agujero empieza a rebotar sobre la canica hasta que sucede el timeout del tiro"
- S7: "cuando una canica tiene timeout o se encuentra quieta sin anotar, podrías hacer un efecto de que se eleva como capturada por una nave espacial sobre el eje vertical, simulando que fue 'absorbida' por lo que se perdió el tiro"

## Tasks

- T1 (S6) DONE (38c63fa): embedded marbles get a low-bounce PhysicsMaterial at embed time, so arriving marbles lose energy and settle — board.gd
- T2 (S6) DONE (38c63fa): magnet stops pulling at contact distance and damps the marble instead, so it can never fight the physics into an occupied notch — board_theme.gd
- T3 (S6) DONE (38c63fa): stuck detector: a marble that barely displaces for ~2 s while FLIGHT abducts as lost, ending the volley without the 15 s timeout — board.gd
- T4 (S7) DONE (38c63fa): settle and timeout losses play the abduction: the marble freezes, rises on the world vertical inside a fading light beam, spins, shrinks, frees itself; the throw resolution does not wait for the animation — board.gd
- T5 DONE (38c63fa): headless suites + gdcheck on changed .gd

## Tasks (second round)

- T6 (S7) DONE: abduction presentation shared by settle, stuck, and timeout losses — board.gd _abduct_marble — commit on top of d80fdbc, merged into 38c63fa (`fix(board): trapped marbles resolve instead of bouncing to timeout`).

## Log

- L1: "hay un problema que ocurre con los tableros de magneto, viento o simplemente cuando existe una canica en un agujero y otra canica llega cerca del agujero empieza a rebotar sobre la canica hasta que sucede el timeout del tiro. Podrías proponerme soluciones a este bug ?"
- L2: "podrías implementar las 3, y cuando una canica tiene timeout o se encuentra quieta sin anotar, podrías hacer un efecto de que se eleva como capturada por una nave espacial sobre el eje vertical, simulando que fue 'absorbida' por lo que se perdió el tiro" (user picked options A + B + C and added the abduction effect)

L3 (2026-11-23 audit): T1-T6 marcadas DONE con evidencia (38c63fa, ancestro de main); las líneas de tarea no llevaban marcador desde el cierre de la unidad y el código está en scripts/board/board.gd (_abduct_marble:986).

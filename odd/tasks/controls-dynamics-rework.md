# Controls and dynamics rework

Rework board geometry, shooting controls, board edges and the capture
mechanic of the chibolones POC (`scripts/main.gd`, single self-contained
file). Decisions confirmed by the user: an embedded marble is immovable
(only bounce physics against it) and its score is added immediately when
it embeds.

## Specs

S1: "Podrías hacer el tablero un poco más largo para que existe mayor innercia con la inclinación y los tiros no vayan tan directos"
S2: "Podrías aumentar la separación entre los agujeros para que sea posible apuntar mejor, no importa que el tablero se vuelve más ancho"
S3: "Podrías hacer que la dirección de tiro de la segunda fase ya no sea automática sino que sea controlable por medio de las flechas de dirección izquierda y derecha, agrega un límite para que la dirección no pueda apuntar fuera del tablero"
S4: "Podrías regresar los bordes del tablero a los costados y al fondo. La canica si puede salir en base a la inclinación e innercia con otros obstaculos más adelante, así que las reglas se mantienen"
S5: "el juego original tiene muescas en la madera del tamaño de una canica (no queda justa ni sobrada lo necesario para que pueda quedar insertada en la muesca), esto permite que la canica quede incrustada con la mitad de su circunferencia expuesta, lo que hace que no pueda caer otra canica en el mismo agujero, además le agregar interacción de físicas al chocar con las otras canicas que se tiran"
S6 (user decision): canica incrustada "No se puede sacar" — quedа fija, solo rebote contra ella.
S7 (user decision): puntaje "Inmediato, al incrustarse".

## Tasks

T1 [S1] DONE commit ef81ce9. Enlarge board length (5.0 -> 7.0), spread rows, move launch point and camera to match.
T2 [S2] DONE commit ef81ce9. Widen hole spacing X (0.5 -> 0.8) and board width (3.0 -> 4.2); AIM_LIMIT follows BOARD_W.
T3 [S3] DONE commit (W2+W3 slice). TILT phase: manual left/right arrow control with per-side angle limit so the guide never points off the board.
T4 [S4] DONE commit ef81ce9. Add side and back walls (low, marble can still hop over with inertia); keep existing out-of-board rules.
T5 [S5,S6,S7] DONE commit (W2+W3 slice). Replace hole capture with notch embedding: marble freezes centered at surface level (half circumference exposed), notch becomes occupied (no second capture), embedded marble collides physically with later shots, score added immediately.
T6 [S1-S7] DONE. gdcheck OK (3 files), physics_probe OK, smoke OK (full round, embed scored +10); README and doc header updated.

Log L3: verification evidence - smoke test attempt 4 embedded a marble and scored 10 (immediate scoring, S7); physics probe confirms no spawn-through-board regressions.

## Log

L1 (user request, verbatim): "Podrías cambiar un poco los controles y dinámicas luego pasaremmos a la parte de game design:
1. Podrías hacer el tablero un poco más largo para que existe mayor innercia con la inclinación y los tiros no vayan tan directos
2. Podrías aumentar la separación entre los agujeros para que sea posible apuntar mejor, no importa que el tablero se vuelve más ancho
3. Podrías hacer que la dirección de tiro de la segunda fase ya no sea automática sino que sea controlable por medio de las flechas de dirección izquierda y derecha, agrega un límite para que la dirección no pueda apuntar fuera del tablero
4. Podrías regresar los bordes del tablero a los costados y al fondo. La canica si puede salir en base a la inclinación e innercia con otros obstaculos más adelante, así que las reglas se mantienen
5. Hay una mecánica que es un poco dificil de explicar que sucede en el juego original de Guatemala. En lugar de que los agujeros sean grandes y la canica caiga por ellos, el juego original tiene muescas en la madera del tamaño de una canica (no queda justa ni sobrada lo necesario para que pueda quedar insertada en la muesca), esto permite que la canica quede incrustada con la mitad de su circunferencia expuesta, lo que hace que no pueda caer otra canica en el mismo agujero, además le agregar interacción de físicas al chocar con las otras canicas que se tiran. Podrías implementar esta nueva funcionalidad, si tienes preguntas me lo dices"
L2 (user decisions via questionnaire): embedded marble "No se puede sacar"; score "Inmediato, al incrustarse".

L3: all six tasks verified; smoke run embedded a marble on attempt 4 and scored 10 immediately (S7 evidence).

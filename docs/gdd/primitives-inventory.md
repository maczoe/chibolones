# Chibolones — Primitives & Content Inventory (docs primario de handoff)

Fotografía de lo implementado a la fecha (leído de los `.tres` reales:
`data/boards`, `data/modifiers`, `data/marbles`, `data/prizes`) y de las
primitivas del pipeline. Base para la lluvia de ideas (altas/bajas) y
para el catálogo de primitivas del pivot (design-decisions-v2.md).
Nota: tableros 13-20 usan bonificadores placeholder; el plan real está
en `content-plan.md` §3.

## 1. Primitivas actuales

### Por BoardDef (data)
| Primitiva | Configura |
| --- | --- |
| `objective_target` | Umbral de score (único tipo de objetivo hoy) |
| `modifiers[]` | 0-2 bonificadores (lista §2) |
| `cols/rows/spacing_*/first_row_z/row_scores` | Grilla de muescas y valores por fila |
| `width/length/thickness/tilt_deg/wall_*` | Geometría física del tablero |
| `aim_limit_margin/launch_depth/capture_*/skip_speed` | Apuntado y captura |
| Paleta + `backdrop_*` + `backdrop_style` | Ambiente: waves / spiral / rays |
| `floor_checker_*` | Piso (solo checker hoy; ver D16) |
| `length` | Duración del show |

### Por BoardModifierDef (bonificadores)
| id | Parámetro |
| --- | --- |
| borracho | `value_shuffle` |
| cronometrado | `decision_timer_sec` |
| cuerda | `wall_bounciness`, `wall_hit_mult` |
| espejo | `center_mult` |
| fantasma | `phase_notch` |
| iman | `magnet_strength` |
| mochila | `cover_notch` |
| mojado | `friction_scale` |
| trapecio | `grid_swing_speed` |
| ventoso | `wind_strength` |

### Del motor (no data aún)
Aim → tilt (guía limitada) → potencia oscilante; devolución por
rodado de vuelta; clavadas escollo físico; over-wall = pierde tiro y
canica; rollo de durabilidad (vidrio); swap de munición Up/Down;
recompensa `base + per_marble + bonus`; tienda (2 canicas, 2 premios,
1 pack, 1 reroll); precios por bloque; boss cada 4; endless.

## 2. Tableros actuales (implementado)

| # | Tablero | Target | Modifiers |
| --- | --- | --- | --- |
| 1 | Tablero Clasico | 60 | — (tutorial) |
| 2 | Tablero de Cuerda | 60 | cuerda |
| 3 | Tablero Mojado | 60 | mojado |
| 4 | JEFE: El Tablero Borracho | 100 | borracho |
| 5 | Tablero Espejo | 60 | espejo |
| 6 | Tablero Ventoso | 60 | ventoso |
| 7 | Tablero Mochila | 60 | mochila |
| 8 | JEFE: La Barraca Sellada | 100 | ventoso + espejo |
| 9 | Tablero Fantasma | 60 | fantasma |
| 10 | Tablero Iman | 60 | iman |
| 11 | Tablero Trapecio | 60 | trapecio |
| 12 | JEFE: El Truco Final | 100 | fantasma + iman |
| 13 | Tablero de Vidrio | 60 | mojado (placeholder) |
| 14 | Tablero Culebra | 60 | cuerda (placeholder) |
| 15 | Tablero Mil Voces | 60 | mojado + cuerda (placeholder) |
| 16 | JEFE: El Show de Medianoche | 100 | mojado + cuerda |
| 17 | Tablero de Cuerdas Tricioneras | 60 | ventoso + cuerda |
| 18 | Tablero Cronometrado | 60 | cronometrado |
| 19 | Tablero Espejismo | 60 | fantasma (placeholder) |
| 20 | JEFE: El Quinto Cinco | 100 | trapecio + cronometrado |

Todos comparten matriz 10/20/30/50 y objetivo por umbral; D9/D12 los
rompen.

## 3. Items actuales

### Canicas (10)
| Canica | Rareza | Uso | Mecánica |
| --- | --- | --- | --- |
| Comun | común | permanente | ninguna |
| Fuego | común | permanente | speed x1.25 |
| Vidrio | infrecuente | permanente | score x2, break 20% |
| Agata | común | permanente | mass 1.5, wind_steady |
| Remolino | común | permanente | center_pull |
| Teledirigida | infrecuente | consumible | homing |
| Rebote | común | consumible | side_refund |
| Nitro | rara | consumible | speed x1.6 |
| Trampa | infrecuente | consumible | embed_anywhere |
| Espejo | rara | consumible | copy_prev |

### Premios (10)
| Premio | Rareza | Efecto (params) |
| --- | --- | --- |
| Osito | común | board_end_flat (50) |
| Trompo | infrecuente | wall_mult (1.5) |
| Muñeco de Nieve | común | skip_speed_scale (0.5) |
| Pelota de Goma | común | bounce_scale (1.3) |
| Billete de la Suerte | común | refund_money (2) |
| Globo | común | extra_throw (1/board) |
| Boleto Retro | infrecuente | first_throw_replay |
| Carpa en Miniatura | común | bag_slots (+1) |
| Rayo | infrecuente | fire_speed_mult (1.5) |
| Corona del Circo | rara | score_mult_all (1.1) |

## 4. Estado de ideas para las nuevas mecánicas (levantado en esta sesión)

- **Faltan como primitivas** (D9-D16): tipos de objetivo (exacto /
  lista / regla / rango), matriz configurable + agujeros trampa, cofres
  (fijos y probabilisticos con rareza y rueda), rampas/plataformas,
  layouts generadores (triangulo invertido, radial, un agujero), clases
  de premios (permanente/consumible/cosmetico), verificador de
  ganabilidad, piso configurable (D16).
- **Candidatas a desactivar** (decision del usuario pendiente):
  cronometrado (estres sin decision, choca con objetivos de planeacion),
  mochila (negacion pura, puede sentirse injusta); fantasma tiene
  potencial si interactua con el objetivo del tablero.
- **Orden de implementacion acordado** (design-decisions-v2.md):
  D12+D9 (matriz + objetivos + checker) -> D8+D10 (+D11) (clases de
  premios + cofres + biblioteca) -> D13+D14 doseados -> D15 (tickets +
  gachapon + hub).

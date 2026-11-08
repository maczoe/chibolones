# Chibolones — Style Guide v1 (M0.5 reference)

Rules for building future content so every asset stays coherent.

## Palette (circo surreal)

| Token | Hex | Use |
| --- | --- | --- |
| Deep void | `#0d0920` | Room background, deepest dark |
| Ink outline | `#120b26` | Outlines, HUD text shadows |
| Cabinet dark | `#2e1b58` | Frames, walls, end overlay |
| Board violet | `#5b34a6` | Play surface, mid accents |
| Fog violet | `#3a1f6e` | Ambient light, fog |
| Candy pink | `#ff6fb5` | Spotlight, messages, accents |
| Neon cyan | `#4deeea` | Notch rings, guide, power bar |
| Candy yellow | `#ffe066` | Bulbs, stat labels, popups |
| Alarm red | `#ff4d6d` | Danger/break states (M2+) |
| Chalk white | `#fff7ff` | Notch numbers, message outlines |

## Materials

- **Marbles** (one model, identity by `MarbleDef.style`):
  - `swirl`: solid palette color, metallic 0.1, roughness 0.25.
  - `fire`: dark core `#330d05`, emission orange `#ff731a` @ 2.0.
  - `glass`: alpha 0.78, metallic 0.6, roughness 0.03, rim + inner glow.
- **Cabinet**: `_paint_material` with optional subtle emission (0.18).
- **Lights**: dark room (ambient 0.45-0.7 per theme), one warm spotlight
  over the cabinet, glow enabled (threshold 1.0) — emission values ≥ 2.0
  bloom; keep decorative emission below that unless intended to glow.
- **Deck art**: transparent-background SVG, candy palette, outline strokes
  12-14px, placed via BoardDef (deck, sides); decals render_priority -1.
- **UI**: candy labels (yellow text `#ffe066`, outline `#120b26`),
  pink pill messages, cyan/pink striped power bar.

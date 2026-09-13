# Pushing geometry regression fixtures

Read-only production responses captured 2026-09-12, reduced to geometry,
step modes, maneuvers and totals. Coordinates are longitude/latitude in GeoJSON.
OSM-derived geometry: OpenStreetMap contributors, ODbL (https://www.openstreetmap.org/copyright).

Underpass: Falkensteinstrasse (48.106400, 11.592893) to
Scharfreiterplatz (48.105727, 11.593405).
Commute: (48.146703, 11.517093), the two above intermediate stops,
then (48.092410, 11.648295).

Standard and direct were captured independently. These fixtures test display
of backend-reported modes, not correctness of the older production profiles.
No live network requests are required by the regression tests.

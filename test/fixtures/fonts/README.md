# Layout test fonts

Roboto regular and bold are copied from Flutter 3.47.6's
`bin/cache/artifacts/material_fonts` and distributed under the accompanying
Apache 2.0 license (`roboto_license.txt`).

The destination-summary widget tests load these fixed fixtures to verify real
text geometry instead of the square Ahem test font. Keeping them here avoids
depending on optional font files in the host Flutter SDK cache. These are test
fixtures only and are not declared as application assets.

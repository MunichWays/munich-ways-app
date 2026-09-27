# Routing guidance regression fixtures

`birketweg-osrm-2026-09-26.json` is the unchanged saved RadlNavi response
from the routing analysis in munichways-radlnavi. Its envelope contains the
original request URL, retrieval timestamp and full OSRM-compatible response.
Coordinates in the API are longitude/latitude.

The test `test/ui/map/birketweg_offset_guidance_test.dart` feeds `response`
through the real RadlNaviApi parser using MockClient (no live network access),
then passes the resulting route to VoiceGuidance.

Before the offset-pair fix, the parser retained continue/left and turn/right,
but the pair filter removed both: display at the route start returned null.
After the fix it shows "In 50 m links" and announces both turns together.
A variant with turn/left protects against fixing only the continue type.

Validation on 2026-09-27: flutter analyze --no-pub passed. All 52 tests in
birketweg_offset_guidance_test.dart, voice_guidance_test.dart and
radlnavi_api_test.dart passed, including Balanstrasse, Lautensackstrasse,
route replacement and off-route recovery. Five of these tests are new.

Only opposite slight turn pairs remain eligible for suppression. Existing
angle adjustment, distance thresholds, progress advancement and speech
scheduling are unchanged. In particular, the 25 m advancement rule can delay
the separate second instruction on close turns; the combined announcement is
covered here. Device TTS and a physical ride have not been tested.

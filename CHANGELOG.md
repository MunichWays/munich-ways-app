# Changelog

## 3.1.13+52 - 2026-08-03
* Added saved destinations and improved place search and route planning guidance.
* Improved voice guidance, maneuver instructions, and the visual connection between routes and their destinations.
* Added a bundled cycling-network fallback so ratings remain available when the full network cannot be downloaded at startup.
* Added retry feedback when the initial cycling-network download fails.
* Improved Android map startup, location handling, and behavior when returning to the app.
* Improved accessibility labels and touch targets for important map and route controls.

## 3.0.0+31
* Migrated the map stack from `flutter_map` to MapLibre and removed legacy map code paths.
* Introduced a new map overlay layout with modal sheets for info, settings, bike network selection, place search, and street details.
* Added map controls customization (button visibility/settings) and improved on-map navigation UX, including loading and off-screen destination handling.
* Switched to a customized OpenFreeMap Positron style and improved map readability (label halo, line layering, zoom-aware route widths).

##  2.0.2+27
* Version fix

##  2.0.2+26
* Show all at start

##  2.0.1+25
* map rotation

##  2.0.0+24
* routing by RadlNeva.de
  
##  1.2.2+23
* Fix Crash on zooming out map
* Set Android Target SDK to API 33

##  1.2.1+21
* Version fix

##  1.2.1+20
* Switch to Mapillary API v4. Mapillary images are displayed again.

##  1.2.0+19
* Direction arrow to the destination is displayed in the edge of the screen.

## 1.1.2+18 - in Progress

## 1.1.1+17
* Update munichways.com url to munichways.de url

## 1.1.0+16
* Add custom text for first search #52
* Add Gesamtznetz quick toggle #55
* Adjust display of lines on map to improve visibility #44
* Move delete radlnetz to settings #56
* Fix Trigger search action over keyboard #53
* Fix zoom/rotation of OSMCreditsWidget
* flutter_map update to improve performance
* flutter update to 2.10.0

## 1.0.1+14
* Keep screen awake while destination locating is active
* Allow to display App when screen is locked on Android

## 1.0.0+13
* Fix Radlvorrang description

## 0.0.10+12
* Add Location Search
* Update flutter to 2.2.1

## 0.0.9+11
* Adjust to geojson changes
* Add caching to improve data consumption
* Fix asking repeatedly for enable location services on Android

## 0.0.8+10
* Upgrade to flutter 1.22.4
* Fix route color
* Fix iOS App icon
* Migrate to Radl-Vorrangnetz V03
* Update StreetDetails
* Update Bikenetselection
* Add Mapillary Image to Streetdetails

## 0.0.7+9
* Update Logo
* Move map along current position
* Remove refresh button on map
* Update API to gesamtnetz_V02.geojson

## 0.0.6+8
* Fix missing internet permission on android

## 0.0.5+7
* Use flutter_maps with OpenStreetMap

## 0.0.4+6
* Bugfix: Hide grey (planned) routes

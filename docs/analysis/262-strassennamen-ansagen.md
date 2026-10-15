# #262: Straßennamen ansagen (Build 80)

Branch: `feature/262-strassennamen-ansagen`, App-Version `3.2.1+80`.

RadlNavi liefert den Namen des ausgehenden Weges bereits pro OSRM-Step.
Die App hatte jedoch nur den Wechsel zwischen Straße und Radweg am Manöver
gespeichert. Für einen Wechsel Straße → Straße war die ausgehende Wegart
deshalb nicht verfügbar. Der Parser übernimmt jetzt zusätzlich die bekannte
ausgehende Wegart für Fahrrad-Steps; die bisherige Wechselinformation bleibt
für ihre bisherigen Aufgaben erhalten.

Gesprochene Vorankündigungen und unmittelbare Abbiegehinweise ergänzen bei
bekannter Straße und vorhandenem Namen „in <Straßenname>“, beispielsweise
„Hier rechts abbiegen, in Landsberger Straße.“ Das gilt auch für jeden Teil
einer kombinierten Ansage zweier kurzer Abbiegungen. Englische Ansagen
verwenden „onto <name>“. Leerraum im Namen wird bereinigt.

Bei Radwegen, Schiebestrecken oder unbekannter Wegart werden keine
Straßennamen ergänzt. Fehlt der Name, bleibt beim Wechsel auf eine Straße
„auf Straße“ erhalten; Straße → Straße bekommt weiterhin keinen Zusatz.
„auf Radweg“ bleibt erhalten. Die kompakten Kartenhinweise, Auswahl und
Zeitpunkte der Manöver, TTS-Steuerung und Neuberechnung bleiben unverändert.
Es gibt keine zusätzlichen Netzwerkabfragen. Auch native GPX-Snapshots laufen
durch denselben Parser. Alte Antworten ohne Wegklassifikation behalten die
bisherige Ansage, da ihr Name allein keine sichere Unterscheidung erlaubt.
BRouter wird nicht verändert.

## Handy- und Betatest

1. Mit RadlNavi/OSRM eine Route mit Straße → Straße und Radweg → Straße
   starten. Vorankündigung und direkte Ansage enthalten den Namen der Straße,
   in die eingebogen wird. Auch zwei kurz aufeinanderfolgende Abbiegungen
   prüfen: jeder Teil nennt die richtige Straße.
2. Auf einen benannten Radweg wechseln und auf einem solchen abbiegen:
   „auf Radweg“ und die bisherigen Richtungsansagen bleiben erhalten,
   der Straßenname wird nicht zusätzlich gesprochen.
3. Eine Straße ohne Namen prüfen: vom Radweg „auf Straße“, von einer anderen
   Straße nur die Richtung. Keine leeren oder doppelten Zusätze.
4. Ansagen aus-/einschalten, Navigation beenden und neu starten sowie nach
   vorübergehendem GPS-/Netzausfall zurückkehren. Ansagen müssen wie bisher
   wieder einsetzen; kein doppeltes Abspielen. Deutsch und Englisch prüfen.
5. Gespeicherte Originalroute und normalen BRouter-Fallback öffnen: Import,
   Routenverlauf und Navigation müssen weiterhin funktionieren.

## Technischer Prüfstand

- Dart-Format und `git diff --check` erfolgreich.
- Vollständige statische Flutter-Analyse ohne Befund.
- 107 gezielte Tests erfolgreich: Wegarten/Straßennamen, Sprachführung samt
  Wiederaufnahme, Birketweg-Geometrie, RadlNavi-/BRouter-Parser und GPX-Snapshot.
- Vollständige App-Testsuite vor Commit/Push: 681 bestanden; ein opt-in
  RadlNavi-Livetest ohne `RADLNAVI_LIVE_TEST=true` nicht ausgeführt.
- Der Nutzer hat den abschließenden Handytest erfolgreich bestätigt; der
  Flutter-Lauf ist beendet und das Handy abgezogen. Der Agent hat kein Gerät
  installiert oder gestartet.
- Kein zusätzlicher Android-/iOS-Build durch den Agenten; die Änderung betrifft
  Dart-Daten und Ansagetexte. Die iOS-Prüfung bleibt gesondert erforderlich.
- Abschlussprüfung vor dem ausdrücklich beauftragten Commit und Push.

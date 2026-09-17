# Constraints

- Kein Simulator/Emulator-Boot (M1, 8GB RAM) — macOS-Build/-Run ist ok, kein
  iOS-Simulator nötig für dieses Projekt ohnehin.
- Schwere lokale Builds vermeiden wo möglich; `xcodebuild` für dieses ~7k-LOC
  Projekt ist unkritisch, aber keine parallelen/mehrfachen Vollbuilds ohne
  Grund.
- Kein Squash-Merge — Branch selbst sauber halten (rebase -i vor Merge), dann
  `git merge`/"Merge commit" bzw. "Rebase and merge".
- Keine stillen Scope-Erweiterungen oder Verhaltensänderungen — alles, was
  über den ursprünglichen Funktionsumfang hinausgeht, explizit im
  Impl-Report benennen.
- Verifikation vor Fertigmeldung: tatsächlicher App-Start/Beobachtung nötig,
  Build-grün allein zählt nicht als Funktionsnachweis.
- Für neue UI-Inputs mit festen Optionen: Dropdown/Select statt Freitext
  (mit "Andere…"-Escape falls nötig).

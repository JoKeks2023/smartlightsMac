# Scope

Der Auftrag ist bewusst breit ("alles"). Damit das kein unbegrenztes Fass wird,
wird in Phasen geschnitten. Jede Phase ist für sich abgeschlossen, buildbar und
kann einzeln committet werden.

## Phase 1 — Architektur & Hygiene (in scope, diese Session)
- Toten Code entfernen (`StubServices.swift`, ungenutzte Reste).
- `GoveeModels.swift` (1938 Zeilen) in fachliche Einheiten aufteilen
  (Models / Stores / Discovery / Transports als eigene Dateien im
  bestehenden `Services/`-Ordner-Stil).
- Offensichtliche Code-Smells beheben (Force-Unwraps, Duplikate), ohne
  Verhalten zu ändern.
- `.DS_Store` aus Git entfernen, `.gitignore` prüfen/ergänzen.

## Phase 2 — Bugs & Stabilität (in scope, diese Session)
- Bestehende Unit-Tests laufen lassen, Lücken an kritischen Stellen
  (Discovery-Merge, Persistence, Settings) identifizieren und schließen.
- Bekannte Schwachstellen aus FEATURES.md ("Known Limitations",
  Troubleshooting-Abschnitte) gezielt nachvollziehen — nur fixen, was
  reproduzierbar/nicht nur behauptet ist.

## Phase 3 — Doku & Repo-Hygiene (in scope, diese Session)
- README.md/FEATURES.md von Marketing-Ton auf ehrlichen, aktuellen Stand
  bringen (was funktioniert wirklich, was ist WIP).
- Roadmap-Abschnitt aktualisieren, damit er zu Phase 4 passt.

## Phase 4 — UI/UX-Überarbeitung (in scope, diese Session, nach Phase 1)
Nutzer-Hinweis (2026-09-17): Projekt wurde ursprünglich mit GitHub Copilot
gebaut, Qualität war "noch nicht so gut", UI ist "ziemlich shitty".
- `ContentView.swift` UI strukturell überarbeiten (Layout, Komponenten,
  Konsistenz), nicht nur Code intern aufräumen.
- Design-Richtung: jorisconrad-design-language-Skill als Basis nutzen
  (eigene, wiederverwendbare Design-Sprache des Nutzers), soweit auf
  AppKit/SwiftUI-macOS übertragbar; sonst native macOS-HIG-Patterns
  (Sidebar/Split-View, native Controls) als Fallback.
- Sichtbare Ist-Analyse vor Umbau: App tatsächlich starten und Screenshots/
  Beobachtung nutzen, nicht nur Code lesen (Verifikationsregel).

## Phase 5 — Offene Roadmap-Punkte (teilweise in scope)
Aus der bestehenden Roadmap ist "alles fertigstellen" in einer Session nicht
realistisch (native Hue-Bridge-API, LIFX-LAN, Szenen/Automation, Zeitpläne,
Music-Sync, Multi-Window, Shortcuts-Integration sind je für sich eigene
Feature-Umfänge). Vorgehen:
- Umsetzbar diese Session: **native Philips Hue Bridge API** (klar
  dokumentiertes lokales REST-Protokoll, hoher Nutzwert, größter
  Non-HomeKit/HA-Lückenschluss laut eigener Roadmap).
- Explizit zurückgestellt und als Folge-Tasks dokumentiert (nicht
  stillschweigend fallen gelassen): LIFX-LAN-Protokoll, Szenen/Automation,
  Zeitplan/Timer, Music Sync, Multi-Window, Shortcuts-Integration.

## Out of scope
- Distribution/Code-Signing/App-Store-Vorbereitung.
- iOS-Companion-App (separates Repo).
- Simulator/Emulator-Tests (per globaler Regel: kein Simulator-Boot).

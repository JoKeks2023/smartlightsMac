# Validation-Report

## Automatisiert, tatsächlich ausgeführt

- `xcodebuild … build` (Debug, `platform=macOS`): **grün**, nach jedem
  einzelnen Commit erneut geprüft (nicht nur am Ende).
- `xcodebuild … -only-testing:"Govee MacTests" test`: **4/4 grün**, nach
  jeder funktionalen Änderung erneut ausgeführt.
- `Govee MacUITests`: hängt beim App-Verbindungsaufbau — bestätigt als
  Umgebungsproblem, nicht durch diese Änderungen verursacht (bereits vor
  dieser Session in derselben Form beobachtet). Nicht als Regressions-
  Nachweis nutzbar in dieser Umgebung.

## Manuell, mit echter App-Ausführung (kein reines "Build grün")

- App gestartet, lokale-Netzwerk-Berechtigung erteilt, LAN-Discovery hat
  **zwei echte Govee-Geräte** im Nutzer-Netzwerk gefunden (H6008, H619A) —
  vor und nach dem Architektur-Split, vor und nach dem UI-Umbau. Screenshots
  während der Session gemacht (nicht im Repo abgelegt).
- Power/Brightness/Color-Temp-Controls im Screenshot mit dem neuen Teal-
  Akzent sichtbar funktionsfähig (Slider-Werte, Checkbox-Zustand).
- Shortcuts-App geöffnet, um App-Intents-Registrierung zu prüfen — GUI-
  Automatisierung dort nicht zuverlässig abschließbar (mehrere
  System-Dialoge). Als Ersatz-Beleg: `ExtractAppIntentsMetadata` schreibt
  jetzt tatsächlich `Metadata.appintents` (vorher: "Metadata extraction
  skipped, no AppIntents.framework dependency found").
- Widget-Target: Build bettet `GoveeWidgetExtension.appex` sichtbar in
  `Govee Mac.app/Contents/PlugIns` ein. `pluginkit -m -p
  com.apple.widgetkit-extension` zeigt das Widget in dieser Session
  (Debug-Build aus DerivedData, nicht über Xcode selbst gestartet) **nicht**
  in der Liste installierter Widgets — siehe Einschränkung unten.

## Nicht verifiziert (explizit offen, siehe auch
`06_fragen_und_entscheidungen.md`)

- **Hue-Bridge-Pairing**: kein echtes Hue-Bridge-Gerät im Netzwerk der
  Session verfügbar. Code kompiliert, Logik wurde gegen die offizielle
  Hue-API-Doku (Link-Button-Flow, `/api` POST, Fehlercode 101) implementiert,
  aber nicht End-to-End gegen echte Hardware getestet.
- **Widget in der Notification-Center-Galerie**: nicht bestätigt live
  sichtbar. Wahrscheinlichste Ursache: Debug-Build aus `xcodebuild` statt
  aus Xcode selbst gestartet registriert Extensions nicht immer sauber bei
  LaunchServices/`pluginkit`. `WIDGET_SETUP.md` enthält jetzt konkrete
  Schritte, das morgen mit `⌘R` aus Xcode zu prüfen.
- **Shortcuts in der Kurzbefehle-App-UI**: Metadaten-Generierung bestätigt,
  aber nicht visuell in der App bestätigt, dass die Actions dort auftauchen.
- **LIFX**: bewusst nicht angefasst (war schon vorher als "nicht
  implementiert" bekannt, kein neuer Regressionscheck nötig).

## Nachtrag: CI auf dem PR

Nach dem Öffnen von PR #13 stand die CI dauerhaft auf "queued" — Ursache
war `runs-on: macos-13`, ein von GitHub bereits entferntes Runner-Image
(bestätigt über die Actions-API: Status blieb `queued` ohne `runner_id`).
Zusätzlich verwendete der Workflow `timeout 600 …`, ein GNU-Coreutils-Befehl,
der auf macOS-Runnern nicht existiert (`command not found`, Exit 127) — das
hätte den Build unabhängig vom Runner-Image ebenfalls kaputt gemacht.
Beides gefixt (`.github/workflows/ci.yml`: `macos-15`, `timeout` entfernt,
Tests auf `Govee MacTests` beschränkt wegen des bekannten UI-Test-Hangs).
Danach: **beide Checks grün** (Build and Test 1m55s, Swift Syntax Check
15s), PR-Status `MERGEABLE`/`CLEAN`.

## Ehrlichkeitshinweis

Kein Punkt oben wird als "fertig getestet" behauptet, wenn nur der Build
grün war. Wo echte Hardware/UI-Interaktion fehlt, steht das hier explizit,
nicht stillschweigend als "✅ erledigt" in der Doku.

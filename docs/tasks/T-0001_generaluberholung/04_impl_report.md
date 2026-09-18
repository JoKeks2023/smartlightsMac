# Impl-Report

Branch: `overhaul/t-0001-general-overhaul` (13 Commits, siehe `git log
main..overhaul/t-0001-general-overhaul`)

## Phase 1 — Architektur & Hygiene ✅

- `Govee Mac/Services/*` und `Govee Mac/Views/APIKeyEntryView.swift`
  (7 Dateien, ~1.500 Zeilen) waren **nie im Xcode-Target** — archiviert nach
  `Archive/uncompiled-services-2026-09-17/` statt gelöscht (Nutzerentscheidung).
- Zwei verwaiste `.entitlements`-Duplikate (`_OLD`, `_Original`) gelöscht.
- `GoveeModels.swift` (1938 Zeilen) aufgeteilt in `Core/{Keychain,Models,
  Stores}.swift`, `Transports/{DeviceProtocols,CloudTransport,LANTransport,
  HomeKitTransport,HomeAssistantTransport,HueTransport,WLEDTransport,
  LIFXTransport}.swift`, `DMX/DMXEngine.swift`, `GoveeController.swift`
  (Top-Level). Reine Verschiebung, kein Verhaltensunterschied (per Fork
  durchgeführt, Build+Tests danach grün).
- Neuer `Core/DeviceControlResolver.swift`: eigenständige Kopie der
  Transport-Prioritätslogik für die App-Intents-Einstiegspunkte, bewusst
  **nicht** von `GoveeController.getControl(for:)` wiederverwendet, um dessen
  bestehendes Verhalten (inkl. HomeKit-Reihenfolge) nicht anzufassen.

## Phase 2 — Bugs & Stabilität ✅ (im Rahmen der übrigen Arbeit)

- Bestehende 4 Unit-Tests liefen vor und nach jeder Änderung grün.
- UI-Test-Target hängt beim Verbindungsaufbau (Umgebungsproblem, nicht
  durch diese Änderungen verursacht) — mit `-only-testing:"Govee MacTests"`
  umgangen für alle Verifikationsläufe.

## Phase 3 — Doku & Repo-Hygiene ✅

- README.md, FEATURES.md, AI_CONTEXT.md, MANUFACTURER_INTEGRATION.md,
  WIDGET_SETUP.md, COMPANION_APP_CONNECTION.md, IOS_BRIDGE_DEVELOPER_GUIDE.md,
  IOS_COMPANION_GUIDE.md korrigiert bzw. mit Status-Hinweisen versehen.

## Phase 4 — UI/UX-Überarbeitung ✅

- Auslöser: Nutzerhinweis, Projekt sei mit GitHub Copilot gebaut worden,
  UI sei "ziemlich shitty".
- Vorher/Nachher per echtem App-Start verifiziert (Screenshots während der
  Session).
- Ein einziges Accent-Color-Asset (Teal, hell/dunkel) ersetzt verstreute
  Ad-hoc-Farbverläufe (lila/pink für Gruppen, blau/cyan für Cloud,
  orange/gelb für HomeKit/Slider).
- Sidebar-Zeilen entkarteln: kein `.thinMaterial`-Card-in-List mehr,
  native List-Selection statt eigenem Highlight.
- Sentence-case durchgängig ("Add device" statt "Add Device", "Unbekannt"
  → "Unknown").
- HSB-Farbrad im Custom-Color-Picker bewusst unangetastet (echter Inhalt,
  keine Dekoration).

## Phase 5 (User-Anfrage nachts) — Touch Bar, Widgets, Shortcuts

- **Touch Bar**: bereits vollständig implementiert (`TouchBarSupport.swift`,
  921 Zeilen) und im Target. Nutzt `GoveeController`-Methoden, die
  automatisch von der neuen Hue-Unterstützung profitieren. Keine Änderung
  nötig.
- **Hue-Bridge-Pairing**: `HueBridgeDiscovery.pair(bridgeIP:)` implementiert
  (Link-Button-Flow, Polling bis 30s), `discoverCandidateBridges()` für
  Bridge-Suche, echte Lichter-Abfrage via `/api/<username>/lights` statt
  immer leerem Array. Settings-UI: "Philips Hue"-Sektion mit Find/Pair/Unpair.
- **Shortcuts/Siri**: `AppIntents/DeviceIntents.swift` — `SetLightPowerIntent`,
  `SetLightBrightnessIntent`, `GoveeMacShortcuts` (AppShortcutsProvider).
  HomeKit/DMX bewusst ausgeklammert (siehe Code-Kommentare).
- **Widget-Target**: `GoveeWidgetExtension` als echtes WidgetKit-Extension-
  Target neu angelegt (`mcp__xcode__XcodeNewTarget`, Template "Widget
  Extension"), in `Govee Mac.app/Contents/PlugIns` eingebettet.
  `Core/Models.swift` zusätzlich ins Widget-Target aufgenommen (Multi-Target-
  Membership) statt Typ-Duplikat. `DeviceStore.saveDevices()` spiegelt jetzt
  in die App-Group-Suite `group.com.govee.mac` (vorher nur lokale
  UserDefaults — das Widget hätte sonst nie Daten bekommen).

## Bekannte Tool-Probleme während der Arbeit (für zukünftige Sessions)

- `mcp__xcode__XcodeWrite` hat bei **mehreren Dateien in einer neuen Gruppe
  in einem Batch** nur die letzte Datei korrekt in die Sources-Build-Phase
  eingetragen (Fork-Befund) bzw. bei **einer einzelnen neuen Datei mit neuer
  Elterngruppe** die Gruppe als Geschwister von "Govee Mac" auf Projekt-
  Root-Ebene angelegt statt darunter, und die physische Datei ebenfalls auf
  Root-Ebene statt unter `Govee Mac/` geschrieben (zweimal beobachtet:
  `AppIntents/DeviceIntents.swift`, ursprünglich auch bei `Core`/`Transports`/
  `DMX`). Jedes Mal manuell nachkorrigiert (Datei verschoben, Gruppen-
  Nesting und fehlende PBXBuildFile/Sources-Einträge in `project.pbxproj`
  ergänzt) und per Build verifiziert.
- `mcp__xcode__XcodeNewTarget` hat dagegen sauber funktioniert und einen
  korrekten `PBXFileSystemSynchronizedRootGroup` für das neue Widget-Target
  erzeugt (neueres Xcode-Projektformat) — Dateien, die dort per
  Dateisystem abgelegt werden, brauchen keine manuelle Registrierung.

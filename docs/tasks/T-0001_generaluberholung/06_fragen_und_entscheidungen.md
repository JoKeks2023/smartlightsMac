# Offene Fragen & autonome Entscheidungen

Nutzer hat am 2026-09-17 abends volle Autonomie gegeben: "mach die app
fertig... füge Touchbar integration hinzu, widgets, Shortcuts... mach es ohne
user input... bei wichtigen sachen frage sie mich einfach morgen und wenn du
es wirklich brauchst um weiterzumachen dann entscheide selbst was du als
richtig siehst."

Dieses Dokument protokolliert Entscheidungen, die ich in Abwesenheit selbst
getroffen habe (mit Begründung), plus Fragen, die eine echte Nutzerentscheidung
brauchen und morgen gestellt werden sollten.

## Bereits getroffene autonome Entscheidungen

1. **iOS-Sync-Code archiviert statt gelöscht/reaktiviert** — per expliziter
   Nutzerantwort vorher schon geklärt (nicht autonom).
2. **Stale `.entitlements`-Duplikate gelöscht** (`_OLD`, `_Original`) — nicht
   referenziert, eindeutig Müll, keine Ermessensfrage.
3. **README/FEATURES.md Ehrlichkeits-Korrektur** — Fakten aus dem Code
   direkt übernommen, keine Interpretation nötig.

## Fragen für morgen

*(wird während der Session weiter befüllt — siehe unten für Stand)*

- **Widget-Extension-Target**: `GoveeWidget/GoveeWidget.swift` existiert, aber
  es gibt kein Xcode-Target dafür (`WIDGET_SETUP.md` verlangt manuelles
  Anlegen). Ich lege das Target selbst an (ist mechanisch, keine
  Design-Entscheidung) — falls die Group-ID `group.com.govee.mac` aus
  irgendeinem Grund nicht mehr zur Apple-ID/Team des Nutzers passt, muss er
  das morgen in Signing & Capabilities nachziehen; ich kann das ohne
  Apple-Developer-Login nicht verifizieren.
- **Hue-Bridge-Pairing-Flow**: Ich implementiere den "Link-Button drücken"
  Auth-Flow, kann ihn aber mangels echter Hue Bridge im Netzwerk nur gegen
  Code-Review/Compile verifizieren, nicht end-to-end gegen echtes Gerät. Bitte
  morgen mit echter Bridge testen.
- **Shortcuts/App Intents**: Ich lege App Intents für Power/Brightness/Color
  pro Gerät an. Bezeichnung/Phrasing der Shortcuts (z.B. "Turn on {Device}")
  wähle ich selbst; falls andere Formulierung gewünscht, bitte Feedback.
- **UI-Überarbeitung**: Ich nutze den `jorisconrad-design-language`-Skill als
  Grundrichtung (dunkles, ruhiges, natives macOS-Look), soweit sinnvoll auf
  AppKit/SwiftUI übertragbar. Das ist eine Geschmacksentscheidung — bitte
  morgen gegenprüfen, ob das die gewünschte Richtung trifft, bevor mehr Zeit
  in Feinschliff investiert wird.

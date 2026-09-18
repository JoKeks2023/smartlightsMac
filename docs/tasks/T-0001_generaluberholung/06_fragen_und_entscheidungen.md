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

## Stand am Morgen (2026-09-18) — für dich zum Gegenlesen

Alle vier ursprünglich offenen Punkte wurden umgesetzt (siehe
`04_impl_report.md`/`05_validation_report.md` für Details). Was ich davon
**nicht** selbst verifizieren konnte und was du bitte prüfst:

- **Widget-Extension-Target**: angelegt, baut, wird ins App-Bundle
  eingebettet. In der Notification-Center-Widget-Galerie habe ich es nicht
  live gesehen — vermutlich weil ich die App per `xcodebuild` statt per
  ⌘R aus Xcode gestartet habe (Debug-Builds aus DerivedData registrieren
  Extensions nicht immer sauber bei LaunchServices). Bitte einmal mit ⌘R
  aus Xcode starten und in Notification Center → Edit Widgets nach "Govee
  Lights" suchen. Falls es fehlt: Signing & Capabilities beider Targets
  prüfen (App Groups `group.com.govee.mac` sollte in beiden aktiv sein,
  `DEVELOPMENT_TEAM` wurde automatisch von deinem bestehenden Team
  übernommen).
- **Hue-Bridge-Pairing**: Code ist fertig (Link-Button-Flow, Discovery,
  Lichter-Abfrage), aber ich hatte keine echte Hue Bridge im Netzwerk zum
  Testen. Bitte mit echter Bridge verifizieren (Settings → Philips Hue →
  Find Hue Bridges → Link-Button drücken → Pair).
- **Shortcuts/App Intents**: "Set Light Power" und "Set Light Brightness"
  sind implementiert und die Metadaten-Extraktion läuft jetzt tatsächlich
  (vorher komplett übersprungen, da keine AppIntents-Dependency existierte).
  Ob sie so in der Kurzbefehle-App auftauchen wie gedacht, habe ich nicht
  abschließend visuell bestätigen können (mehrere System-Dialoge haben die
  GUI-Automatisierung blockiert). Bitte kurz die Kurzbefehle-App öffnen und
  nach "Govee" suchen.
- **UI-Überarbeitung**: Ich habe den `jorisconrad-design-language`-Skill als
  Grundrichtung genommen — ein einziger Teal-Akzent statt der vorherigen
  Regenbogen-Verläufe (lila/pink/orange/gelb/blau/cyan je nach Widget),
  flachere Sidebar ohne Card-in-List, Sentence-Case durchgängig. Das ist
  ein erster Schritt, kein kompletter Neubau — Fensterlayout/-größe und
  Detailkomponenten (z.B. der Custom-Color-Picker) sind noch im alten
  Stil. Wenn dir die Richtung gefällt, sag Bescheid, dann mache ich mehr
  davon; falls nicht, bevor ich weiter Zeit reinstecke, bitte kurz
  gegensteuern.

## Ursprüngliche Fragen (vor der Nacht-Session, zur Nachvollziehbarkeit)

# Archiv: nie kompilierter Service-Code

Ausgelagert im Rahmen von [T-0001](../../docs/tasks/T-0001_generaluberholung/)
am 2026-09-17.

Diese Dateien lagen unter `Govee Mac/Services/` und `Govee Mac/Views/`,
waren aber **in keinem Xcode-Target referenziert** (Prüfung: kein Treffer in
`Govee Mac.xcodeproj/project.pbxproj`, keine `PBXFileSystemSynchronizedRootGroup`
für diese Ordner). Sie wurden nie gebaut, nie getestet, und stehen teils in
Namenskonflikt mit real genutztem Code in `GoveeModels.swift`
(z. B. `APIKeyKeychain` existiert dort erneut, als `enum` statt `struct`).

Inhalt:
- `Services/APIKeyKeychain.swift` — Duplikat, echte Version lebt in
  `GoveeModels.swift` (`enum APIKeyKeychain`).
- `Services/GoveeController.swift` — Duplikat/Vorläufer, echte Version ist
  `class GoveeController` in `GoveeModels.swift`.
- `Services/StubServices.swift` — Demo-/Platzhalter-Discovery, unbenutzt.
- `Services/CloudSyncManager.swift`,
  `Services/MultiTransportSyncManager.swift`,
  `Services/RemoteControlProtocol.swift` — Infrastruktur für die im README
  beworbene "iOS-Companion-App-Bridge" (CloudKit/Local-Network/Bluetooth-Sync,
  Remote-Control-API). Real nie ans Target angebunden, nie gegen die
  iOS-Companion-App getestet.
- `Views/APIKeyEntryView.swift` — vermutlich Vorläufer der API-Key-Eingabe,
  die heute in `ContentView.swift` lebt.

## Warum nicht gelöscht
Auf Nutzerwunsch erstmal aufbewahrt statt gelöscht, falls die iOS-Companion-
Anbindung später doch real umgesetzt werden soll. Vor einer Wiederbelebung:
gegen den aktuellen Stand von `GoveeModels.swift` abgleichen (dort hat sich
seitdem einiges weiterentwickelt) und in einer eigenen Aufgabe planen statt
einfach wieder ins Target zu ziehen.

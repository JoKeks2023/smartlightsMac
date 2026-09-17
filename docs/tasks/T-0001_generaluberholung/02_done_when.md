# Done-when

- [ ] `xcodebuild … build` bleibt grün nach jeder Phase.
- [ ] `StubServices.swift` entfernt (oder Grund dokumentiert, falls doch
      referenziert wird).
- [ ] `GoveeModels.swift` in mehrere fokussierte Dateien aufgeteilt,
      Verhalten unverändert (Tests + manueller Start bestätigen das).
- [ ] Bestehende Unit-Tests laufen grün; neue Tests für mind. die
      kritischsten identifizierten Lücken vorhanden.
- [ ] App wurde tatsächlich gestartet und die Kernflows (Geräteliste,
      Power/Brightness/Color, Settings) manuell beobachtet — nicht nur
      Build-grün als Nachweis.
- [ ] ContentView UI überarbeitet, App danach erneut gestartet und
      Screenshot/Beobachtung als Beleg im Impl-Report.
- [ ] README.md/FEATURES.md entsprechen dem tatsächlichen Stand (keine
      unbelegten ✅-Behauptungen mehr für Dinge, die nicht verifiziert sind).
- [ ] Native Hue-Bridge-API implementiert und mindestens gegen eine
      Mock/manuelle Prüfung verifiziert (falls keine echte Bridge verfügbar
      ist: das explizit als Einschränkung im Validation-Report vermerken).
- [ ] Zurückgestellte Roadmap-Punkte (LIFX-LAN, Szenen, Zeitpläne,
      Music-Sync, Multi-Window, Shortcuts) als klar benannte Folge-Tasks
      dokumentiert, nicht stillschweigend fallen gelassen.
- [ ] Impl-Report (`04_impl_report.md`) und Validation-Report
      (`05_validation_report.md`) ausgefüllt, mit konkreten Belegen
      (Build-Log-Auszüge, Testergebnisse, Screenshots).

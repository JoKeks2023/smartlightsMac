# T-0001 — Generalüberholung Govee Mac

## Auftrag

User-Anfrage (2026-09-17): "dieses projekt ist ewig alt. lass es uns doch mal
generalüberholen und fertig machen"

Nutzer hat auf Rückfrage bestätigt: alle vier Bereiche sind im Fokus:
1. Code-Qualität & Architektur
2. Bugs & Stabilität
3. Offene Roadmap-Punkte fertigstellen
4. Doku & Repo-Hygiene

Workflow: Feature-Branch + PR (kein Squash-Merge, siehe globale Git-Regel).

## Ausgangslage

- Build ist grün (`xcodebuild … build` erfolgreich, kaum Warnings).
- ~7.000 LOC Swift, Kernlogik stark konzentriert in `GoveeModels.swift` (1938
  Zeilen) und `ContentView.swift` (1532 Zeilen).
- `StubServices.swift` ist toter Code (nirgends referenziert).
- README.md/FEATURES.md sind stark euphorisch/marketing-artig formuliert
  (viele ✅/🎉) und teils veraltet; eigener Roadmap-Abschnitt listet mehrere
  offiziell unfertige Punkte.
- Git-History der letzten Commits wirkt wie unstrukturierte Ad-hoc-Fixes.

Branch: `overhaul/t-0001-general-overhaul`

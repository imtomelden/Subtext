# UX Revamp Phase 0 Baseline

This document defines the baseline measurement protocol and UX performance contract for the Bear-like revamp.

## Core Flows To Measure

- App load to usable content (`loadAll.success`)
- Project list to editor transition (`projects.navigation.transition`, `list_to_editor`)
- Editor to project list transition (`projects.navigation.transition`, `editor_to_list`)
- Save current context (`saveCurrent.home`, `saveCurrent.projects`, `saveCurrent.settings`)
- Command palette open and apply (`palette.open.requested`, `palette.selection.applied`)
- Markdown preview render cost (OSLog category: `ux.preview`)

## Measurement Source

- In-app `EventLog` entries:
  - Category `ux.perf` for latency samples
  - Category `ux.event` for non-latency interaction markers
- Unified logging (Console.app):
  - `subsystem`: `com.subtext.app`
  - categories: `ux.perf`, `ux.preview`

## Initial UX Contract (Phase 0 Targets)

- Project list/editor navigation transition: target `<= 120ms` median
- Save command acknowledgement path: target `<= 180ms` median
- Command palette open request to visible sheet: target `<= 100ms` median
- Markdown preview parse/render:
  - `<= 16ms` for typical edits
  - `<= 50ms` for large documents
  - no sustained spikes during continuous typing

## Baseline Capture Protocol

1. Launch app and load a representative repo.
2. Run each core flow 10 times with realistic content size.
3. Export Event Log (Settings -> Event Log -> Copy all).
4. Capture preview render timings from Console.app (`ux.preview`).
5. Record p50/p95 latency and note visible jank observations.

## Exit Criteria For Phase 0

- Instrumentation is present for all listed core flows.
- Team has one baseline run with p50/p95 for each flow.
- UX contract thresholds are agreed before Phase 1 changes begin.

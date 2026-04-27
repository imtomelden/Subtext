# UX Revamp - Phase 3 Handoff

Use this handoff to start a new agent directly on Phase 3 (visual-system redesign).

## START HERE

Continue from **Phase 2 checkpoint complete/in-progress stabilization**, not from Phase 0/1.

Core architecture and interaction choreography work has landed. The next priority is visual-system implementation and polish.

## CURRENT STATUS

- **Phase 0**: Implemented (instrumentation + baseline tooling), but baseline capture remains unreliable in practice and is deferred by product acceptance.
- **Phase 1**: Closed by product acceptance after stable build/test verification.
- **Phase 2**: Major interaction architecture work implemented and validated; remaining closure item is manual stress validation.
- **Immediate priority**: Start **Phase 3** design-token + UI-surface redesign work.

## PLAN FILE (authoritative context)

- `/Users/tomblagden/.cursor/plans/bear-like_ux_revamp_18b85ecc.plan.md`

Plan already includes:
- status updates
- Phase 1 closure decision
- Phase 2 checkpoint summary
- remaining pre-close Phase 2 manual stress item

## KEY PHASE 2 IMPLEMENTED FILES

- `Subtext/Views/Projects/ProjectsRootView.swift`
  - explicit navigation surface state
  - directional transitions
  - rapid transition coalescing (latest target wins)
- `Subtext/Views/Components/SlidingPanel.swift`
  - stable right-rail choreography (reduced layout jump)
  - rapid open/close coalescing
  - shared motion/coalescing helpers currently housed here:
    - `UXMotion`
    - `CoalescedTransitionQueue`
- `Subtext/Views/ContentView.swift`
  - unified modal coordinator for command surfaces
  - queued modal handoff on dismiss
  - duplicate rapid command-palette open suppression
- `Subtext/Views/Settings/SiteSettingsView.swift`
  - unified settings modal coordinator

## VERIFICATION STATUS

- Repeated build sanity checks passed:
  - `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" build`
- Repeated test runs passed:
  - `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" test`
- Lint checks on touched files were clean during implementation.

## STILL OUTSTANDING (CARRY FORWARD)

- Manual stress pass for Phase 2 closure (rapid keyboard command loops, rapid project switching under realistic dataset size).
- Optional follow-up refactor: move `UXMotion` and `CoalescedTransitionQueue` into a dedicated shared file once project include workflow is confirmed (previous standalone file attempt was not auto-included by project file).

## WHAT NEXT AGENT SHOULD DO FIRST (PHASE 3)

1) Run build/test sanity before new visual changes:
   - `xcodebuild ... build`
   - `xcodebuild ... test`
2) Define/land a design-token layer (type, spacing, radii, surface hierarchy, semantic color roles) and wire it into primary surfaces.
3) Begin UI redesign passes in this order:
   - editor chrome and reading rhythm
   - cards/lists/panels visual consistency
   - empty/loading/error polish
4) Keep keyboard/focus affordances explicit while reducing visual noise.
5) Update the plan file after each reviewable chunk.

## PHASE 3 PRIMARY TARGET FILES (from plan)

- `Subtext/Views/Projects/BlockCardView.swift`
- `Subtext/Views/Projects/BlockEditorPanel.swift`
- `Subtext/Views/Projects/ProjectEditorView.swift`
- `Subtext/Views/Projects/ProjectsListView.swift`
- `Subtext/Views/Sidebar/SidebarView.swift`

## HANDOFF NOTES

- Do not regress Phase 2 coalescing/choreography behavior while applying visual changes.
- Preserve perceived speed: avoid introducing heavy synchronous work in render paths.
- Keep each change set reviewable and phase-scoped.

# UX Revamp - Phase 4 Handoff

Use this handoff to start a new agent directly on Phase 4 (file/parsing pipeline responsiveness).

## START HERE

Continue from **Phase 3 visual-system completion + stabilization**, not from earlier phases.

Design-token and primary surface redesign work is complete. The next priority is reducing synchronous pipeline pressure and making heavy operations progressively non-blocking.

## CURRENT STATUS

- **Phase 0**: Implemented; baseline capture reliability remains deferred by product acceptance.
- **Phase 1**: Closed by product acceptance after stable build/test verification.
- **Phase 2**: Interaction architecture/choreography implemented and validated; manual stress validation remains a carry-forward closure item.
- **Phase 3**: Completed (token layer, editor/list/card/panel redesign, empty/error polish, writing focus mode).
- **Phase 4**: Engineering implementation is functionally complete; closeout now depends on manual stress/perf validation pass.
- **Transition**: Main plan now marks `pipeline-async` complete and `qa-and-hardening` in progress; active implementation focus shifts to **Phase 5**.

## PLAN FILE (authoritative context)

- `/Users/tomblagden/.cursor/plans/bear-like_ux_revamp_18b85ecc.plan.md`
- Phase 5 handover: `/Users/tomblagden/Documents/Projects/Subtext/docs/ux-revamp-phase-5-handoff.md`

Plan currently reflects:
- Phase 3 chunked completion notes through final cleanup
- `bear-visual-system` marked completed
- remaining carry-forward manual stress item from Phase 2

## PHASE 3 COMPLETION SNAPSHOT

Key surfaces already updated:
- `Subtext/Views/Projects/BlockCardView.swift`
- `Subtext/Views/Projects/BlockEditorPanel.swift`
- `Subtext/Views/Projects/ProjectEditorView.swift`
- `Subtext/Views/Projects/ProjectsListView.swift`
- `Subtext/Views/Sidebar/SidebarView.swift`

Token/system layer:
- `Subtext/Views/Components/GlassBackground.swift`
  - shared typography tokens
  - spacing/radius scales
  - semantic surface/fill roles

Additional polish landed:
- source preview error-state surface consistency
- project editor focus mode (distraction-reduced writing state)
- block editor token consistency sweep

## VERIFICATION STATUS

Repeatedly validated during recent chunks:
- `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" build`
- `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" test`
- lint checks on touched files were clean

## STILL OUTSTANDING (CARRY FORWARD)

- Manual stress pass for Phase 2 closure:
  - rapid keyboard command loops (e.g. repeated command palette/open-close cycles)
  - rapid project switching under realistic dataset size
- Optional follow-up extraction of `UXMotion` / `CoalescedTransitionQueue` to dedicated shared source once project include workflow is confirmed.

## WHAT NEXT AGENT SHOULD DO FIRST (PHASE 4)

1) Run build/test sanity before new pipeline changes:
   - `xcodebuild ... build`
   - `xcodebuild ... test`
2) Identify synchronous or broad-scan work on active UI paths and classify:
   - user-blocking
   - deferrable
   - cacheable
3) Prioritize progressive/non-blocking flow for expensive operations:
   - staged loading
   - cancellation/coalescing for repeated triggers
   - incremental updates instead of full rescans where safe
4) Add clear progressive UI feedback for longer operations without introducing extra visual churn.
5) Keep keyboard/focus behavior and perceived speed intact while changing pipeline internals.
6) Update the plan file after each reviewable chunk.

## PHASE 4 PRIMARY TARGET FILES (from plan)

- `Subtext/Services/FileService.swift`
- `Subtext/Models/CMSStore.swift`
- `Subtext/Services/ProjectValidation.swift`
- `Subtext/Services/MDXParser.swift`
- `Subtext/Services/MDXSerialiser.swift`

## PHASE 4 IMPLEMENTATION GUIDANCE

- Prefer cancellable background tasks for parse/validation/reload operations that can be superseded.
- Avoid broad synchronous scans triggered by small edits.
- Cache stable derived outputs when input hashes/mtimes are unchanged.
- Make state transitions explicit (idle/running/partial/complete/error) so UI can reflect progress cheaply.
- Preserve correctness first; optimize only where behavior remains deterministic.

## PHASE 4 KICKOFF CHECKLIST (DO THIS IN ORDER)

1) Re-run baseline sanity and capture timing hooks before refactors:
   - `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" build`
   - `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" test`
   - verify current `ux.perf` / `ux.preview` logs are still emitted for core edit + save + preview flows
2) Add or confirm instrumentation around parse/validation/reload pipeline boundaries:
   - queue time (request -> work start)
   - execution time (work start -> result)
   - cancellation/superseded count
3) Pick one high-frequency path first (recommended: editor-triggered parse/validation path) and make it cancellable/coalesced before touching secondary paths.
4) Ship progressive state exposure to UI (`idle`, `running`, `partial`, `complete`, `error`) with minimal visual churn.
5) Re-run build/tests and compare timing deltas to baseline after each chunk.

## FIRST REVIEWABLE CHUNK (RECOMMENDED)

- Scope:
  - `Subtext/Services/FileService.swift`
  - `Subtext/Services/MDXParser.swift`
  - any directly-coupled caller needed to thread cancellation token/task handles
- Goal:
  - move parse trigger path from eager synchronous behavior to cancellable background task pipeline
  - ensure latest-request-wins semantics during rapid edits
- Guardrails:
  - no parsing correctness regressions
  - no keyboard/focus regressions while parse runs
  - avoid introducing new global shared mutable state
- Acceptance:
  - rapid repeated edits do not queue unbounded work
  - superseded tasks cancel quickly and predictably
  - UI can represent in-progress vs complete parse state

## PHASE 4 DONE DEFINITION

- Parse/validation/reload work on active editing paths is no longer broadly synchronous.
- Repeated triggers are coalesced or cancelled where superseded.
- Stable inputs reuse cached derived outputs when safe.
- Long-running operations expose explicit progress/state to UI.
- Build + tests pass after each chunk, and timing comparisons show non-regressive or improved p50/p95 on targeted flows.

## PROGRESS SINCE PICKUP

- Incremental reload landed in `Subtext/Models/CMSStore.swift`:
  - external project-file change handling now uses targeted `reloadProject(at:)` instead of `reloadProjects()` full rescan
  - conflict resolution reload for a single project now reloads only that file
  - single-file reload now handles delete events (removes in-memory entry + selection cleanup)
- Coalesced editor validation landed in `Subtext/Views/Projects/ProjectEditorView.swift`:
  - frontmatter validation now debounces with cancellation during rapid edits
  - prevents synchronous validation on every document mutation
- Parse cache landed in `Subtext/Services/FileService.swift`:
  - mtime-based cache for parsed `ProjectDocument` by project URL
  - repeated reads of unchanged `.mdx` skip re-read + re-parse
  - cache updated/invalidated on write/delete paths
- Explicit reload pipeline state landed in `Subtext/Models/CMSStore.swift`:
  - `ProjectReloadPipelineState` with `idle/running/partial/complete/error`
  - state updates wired through both full and single-file reload flows
  - failure states now exposed without relying only on toast messaging
- Validation coalescing telemetry + UI feedback landed in `Subtext/Views/Projects/ProjectEditorView.swift`:
  - emits `validation.coalesce.cancelled` and `validation.coalesce.completed` events
  - completed events include file name, elapsed ms, and issue count metadata
  - subtle `Validating` chip shown while debounced validation work is pending/running
- Explicit save pipeline state landed in `Subtext/Models/CMSStore.swift`:
  - `SavePipelineState` with `idle/running/complete/error`
  - transitions wired through splash/site/project save paths and `saveCurrent(...)`
  - conflict and validation failures now emit explicit error state payloads
- Reload/save coalescing telemetry counters landed in `Subtext/Models/CMSStore.swift`:
  - `PipelineTelemetry` tracks request/superseded/failure counts for reload and save paths
  - emits `reload.coalesce.queued|superseded` and `save.coalesce.queued|superseded` events
  - failure counters are incremented on reload/save error paths (including validation/conflict failures)
- Pipeline telemetry UI surface landed in `Subtext/Views/Settings/SiteSettingsView.swift`:
  - new "Pipeline telemetry" settings section with in-session reload/save request/superseded/failure counters
  - includes current reload/save pipeline state labels for quick manual audit context
- Verification:
  - `xcodebuild ... build` passes after each chunk
  - `xcodebuild ... test` passes after each chunk

## PHASE 4 CLOSEOUT CHECKLIST (REMAINING)

1) Manual stress run (carry-forward + Phase 4):
   - rapid command palette open/close loops
   - rapid project switching on realistic dataset size
   - rapid typing/edit loops in Project Editor while watching `Validating` chip behavior
2) Telemetry audit run:
   - open Settings -> Pipeline telemetry and confirm request/superseded/failure counters behave as expected
   - cross-check Event Log for `reload.coalesce.*`, `save.coalesce.*`, `validation.coalesce.*` markers
   - confirm Performance baseline sheet captures `ux.perf` metrics for targeted flows
3) Regression sweep:
   - save conflict flows (`overwrite`, `reload`, `cancel`) still deterministic
   - deleted project-file external change path remains stable
   - no keyboard/focus regressions in editor/list/navigation
4) Closure update:
   - if manual pass is clean, mark Phase 4 complete in the plan file and move this handoff to archival/summary mode

## PHASE 4 CLOSEOUT STATUS

- Engineering checklist items are implemented and build/test/lint-verified.
- Remaining gate is manual stress/perf validation (product acceptance step), not additional core pipeline refactor work.
- Phase 5 kickoff has started in the main plan; keep this doc as reference/archive for Phase 4 outcomes and validation checklist.

## HANDOFF NOTES

- Do not regress Phase 2 coalescing/choreography behavior while tuning pipeline work.
- Do not regress Phase 3 visual/token consistency.
- Keep each change set reviewable and phase-scoped.
- Favor measurable improvements (timing/logging hooks) over opaque refactors.

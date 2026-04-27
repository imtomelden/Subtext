# UX Revamp - Phase 5 Handoff

Use this handoff to start a new agent directly on Phase 5 (QA, accessibility, and finish).

## START HERE

Continue from **Phase 4 implementation complete + transition to hardening**, not from earlier phases.

Core responsiveness architecture work is in place. Priority now is regression coverage, accessibility validation, and final polish.

## CURRENT STATUS

- **Phase 0**: Implemented; baseline capture reliability remains partially deferred by product acceptance.
- **Phase 1**: Closed by product acceptance.
- **Phase 2**: Implemented; manual stress validation remains a carry-forward verification item.
- **Phase 3**: Completed (visual system redesign and consistency).
- **Phase 4**: Marked complete in main plan (`pipeline-async` complete) and handed over to archival/reference mode.
- **Phase 5**: Active (`qa-and-hardening` in progress).

## PLAN FILE (authoritative context)

- `/Users/tomblagden/.cursor/plans/bear-like_ux_revamp_18b85ecc.plan.md`

## PHASE 4 OUTCOMES TO PROTECT (NON-REGRESSION)

- Incremental single-file project reload path in `CMSStore` (avoid broad rescans for single changes).
- Debounced/cancellable editor validation path + lightweight `Validating` indicator.
- mtime-based project parse cache in `FileService`.
- Explicit pipeline states:
  - `ProjectReloadPipelineState`
  - `SavePipelineState`
- Coalescing telemetry:
  - `PipelineTelemetry` counters
  - `reload.coalesce.*`, `save.coalesce.*`, `validation.coalesce.*` events
- Settings telemetry panel in `SiteSettingsView`.

## PHASE 5 FIRST TASKS (ORDERED)

1) Extend/solidify tests for Phase 4 behavior:
   - reload/save pipeline state transition sanity
   - incremental reload correctness invariants
   - validation coalescing non-regression checks where testable
2) Run targeted manual stress validation:
   - rapid command palette loops
   - rapid project switching under realistic dataset size
   - rapid project editor typing while observing validation state/telemetry
3) Run focused accessibility pass:
   - keyboard-only navigation on Projects + Settings
   - VoiceOver focus order and labels on newly touched surfaces
4) Apply small, bounded polish fixes only where regressions/noise are identified.

## PHASE 5 CHECKPOINT (2026-04-27)

- Added targeted regression coverage for Phase 4 file pipeline invariants in `SubtextTests/BuildServiceTests.swift`:
  - `testFileServiceReadProjectRepairsMissingSlugAndOwnership`
  - `testFileServiceReadProjectRefreshesCacheAfterExternalChange`
- What these tests protect:
  - legacy project frontmatter normalization on read remains stable (`slug` + `ownership` repair path),
  - mtime-based parse cache invalidates when an external file change updates modification timestamp.
- Verification:
  - `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" test` passed (19/19).
  - Lint checks clean on touched test files.
- Remaining Phase 5 execution focus is unchanged:
  - manual stress run (command loops, rapid switching, typing/coalescing),
  - keyboard-only + VoiceOver a11y pass on Projects/Settings surfaces,
  - bounded polish fixes only for observed regressions/noise.

## PHASE 5 CHECKPOINT (2026-04-27, Accessibility Slice)

- Applied focused accessibility hardening in `Subtext/Views/Settings/SiteSettingsView.swift`:
  - VoiceOver-friendly labels/hints for recent repository switch buttons.
  - Combined accessibility element/value for current repository path row.
  - Combined accessibility summaries for reload/save telemetry rows (requests, superseded, failures, state).
  - Explicit accessibility labels/values for compact telemetry pills (`Req`, `Sup`, `Err`).
- Scope note:
  - This slice is intentionally bounded to semantics/readout improvements (no pipeline logic or visual-system behavior changes).
- Verification:
  - `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" test` passed.
  - Lint clean on touched file.

## PHASE 5 CHECKPOINT (2026-04-27, Project Editor A11y Polish)

- Applied focused accessibility polish in `Subtext/Views/Projects/ProjectEditorView.swift`:
  - Added explicit accessibility label for back navigation ("Back to projects list").
  - Added frontmatter panel toggle accessibility value (`Expanded`/`Collapsed`) and hint.
  - Added explicit labels for controls that intentionally hide visual labels:
    - ownership segmented control,
    - editor mode segmented control,
    - editor display options menu button.
- Scope note:
  - Semantics-only pass for keyboard/VoiceOver clarity; no editing/pipeline logic changes.
- Verification:
  - `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" test` passed.
  - Lint clean on touched file.

## PHASE 5 CHECKPOINT (2026-04-27, Project Editor A11y Polish 2)

- Extended focused accessibility semantics in `Subtext/Views/Projects/ProjectEditorView.swift`:
  - Added expanded/collapsed accessibility values for disclosure groups:
    - Advanced metadata
    - Case study
    - Hero override
    - Video metadata
  - Added explicit accessibility label/hint for the empty blocks canvas state.
  - Added clearer VoiceOver label/hint for the focus mode informational hint.
- Scope note:
  - Semantics-only changes; no rendering, navigation, or data-path behavior changes.
- Verification:
  - `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" test` passed.
  - Lint clean on touched file.

## PHASE 5 CHECKPOINT (2026-04-27, Pipeline Regression Coverage Expansion)

- Added focused `CMSStore` pipeline regression tests in `SubtextTests/BuildServiceTests.swift` under `CMSStorePipelineTests`:
  - `testReloadProjectMissingFileRemovesSelectionAndCompletes`
  - `testReloadProjectExistingFileUpdatesStoreAndResetsDirty`
  - `testSaveProjectValidationFailureSetsErrorStateAndTelemetry`
- What these tests protect:
  - incremental single-file reload deletion path clears selection and reaches `complete`,
  - incremental single-file reload update path refreshes in-memory data and preserves clean baseline state,
  - validation-blocked save path transitions to `.error(...)` and increments save failure telemetry.
- Verification:
  - `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" test` passed (22/22).
  - Lint clean on touched test file.

## PHASE 5 CHECKPOINT (2026-04-27, Automated Closeout Pass)

- Completed full automated closeout pass for current Phase 5 code scope:
  - `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" build` passed.
  - `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" test` passed (22/22).
  - Lint checks clean across touched files (`BuildServiceTests`, `ProjectEditorView`, `SiteSettingsView`).
- Status decision:
  - Code-side QA/hardening work is functionally complete for this phase.
  - Remaining gate is manual execution + result recording from the runbook below (stress + telemetry + keyboard/VoiceOver).

## TESTING / VERIFICATION BASELINE

Run after each reviewable chunk:

- `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" build`
- `xcodebuild -project Subtext.xcodeproj -scheme Subtext -destination "platform=macOS" test`
- Lint checks on touched files.

Also use:

- Settings -> Pipeline telemetry
- Settings -> Event log
- Settings -> Performance baseline

## PHASE 5 PRIMARY TARGET FILES

- `SubtextTests/BuildServiceTests.swift`
- `SubtextTests/DevServerControllerTests.swift`
- `SubtextTests/RepoValidationTests.swift`
- `Subtext/Views/Projects/ProjectEditorView.swift` (only for focused accessibility/polish fixes)
- `Subtext/Views/Settings/SiteSettingsView.swift` (only for focused accessibility/polish fixes)

## DONE CRITERIA (PHASE 5)

- Targeted regression tests for Phase 4 behaviors are in place and stable.
- Manual stress run and accessibility checks are completed with outcomes recorded.
- Remaining issues are either fixed or explicitly documented as accepted risk.
- Build/test/lint remain green after fixes.

## PHASE 5 MANUAL EXECUTION RUNBOOK (Remaining)

Use this checklist to complete and record the remaining non-automated verification work.

### A) Stress Validation (Command + Navigation + Typing)

1. Command palette stress:
   - Loop `⌘K` open/close rapidly (10-20 cycles).
   - Run a mix of actions and immediate dismisses.
   - Pass criteria:
     - no double-presentation glitches,
     - no stuck modal/sheet state,
     - no perceptible lag growth across loops.

2. Rapid project switching:
   - In Projects list, switch between many projects quickly (20+ switches).
   - Include switching while a project is mid-edit (unsaved changes visible).
   - Pass criteria:
     - directional transitions remain stable,
     - no stale editor content after switch,
     - no panel jump/flicker regressions.

3. Typing + validation coalescing:
   - In Project Editor body, type continuously in bursts (30-60 seconds).
   - Add/remove required metadata fields to trigger validation changes.
   - Pass criteria:
     - typing remains smooth,
     - `Validating` indicator appears transiently and clears,
     - no persistent validation spinner lockups.

### B) Telemetry Audit

While running stress flows, observe:

- Settings -> Pipeline telemetry:
  - `Req` counters increase for relevant actions.
  - `Sup` counters increase only during genuine rapid overlaps.
  - `Err` counters remain stable unless intentionally faulting.
- Settings -> Event log:
  - presence of expected coalescing markers:
    - `reload.coalesce.*`
    - `save.coalesce.*`
    - `validation.coalesce.*`
- Settings -> Performance baseline:
  - confirm `ux.perf` events appear for the targeted flows.

Pass criteria:
- telemetry movement matches user actions,
- no unexplained error spikes,
- event log markers remain semantically aligned with observed UI behavior.

### C) Accessibility Verification (Keyboard + VoiceOver)

1. Keyboard-only:
   - Traverse Projects and Settings without mouse.
   - Trigger high-use controls (source preview, history, focus mode, telemetry tools).
   - Pass criteria:
     - focus order is predictable,
     - all actionable controls reachable,
     - no keyboard trap in sheets/panels.

2. VoiceOver readout:
   - Validate labels/values/hints on:
     - Settings telemetry panel,
     - repo path + recent repo switches,
     - Project Editor toolbar and disclosure sections.
   - Pass criteria:
     - labels are understandable without visual context,
     - expanded/collapsed state is announced where applicable,
     - no ambiguous repeated unnamed controls.

### D) Results Recording Template

Record outcomes directly in this file under a new checkpoint:

- Date/time:
- Environment/dataset:
- Stress validation:
  - command palette: pass/fail + notes
  - project switching: pass/fail + notes
  - typing/validation: pass/fail + notes
- Telemetry audit:
  - counters/events alignment: pass/fail + notes
  - perf baseline capture: pass/fail + notes
- Accessibility:
  - keyboard-only: pass/fail + notes
  - VoiceOver: pass/fail + notes
- Issues found:
  - fixed immediately: list
  - accepted risk/deferred: list + rationale
- Final verification:
  - build/test/lint status

## HANDOFF NOTES

- Keep changes tightly scoped to QA/hardening; avoid re-opening broad architecture work.
- Do not regress Phase 2 choreography or Phase 3 visual consistency.
- Prefer measurable/observable fixes over opaque refactors.

## PHASE 5 CLOSEOUT CHECKPOINT (Template)

Use this section as the final signoff entry once manual execution is complete.

### Completion Snapshot

- Date/time:
- Operator:
- Dataset/repo shape used for stress run:
- Build status:
- Test status:
- Lint status:

### Manual Stress Results

- Command palette loops:
  - Result: _pass/fail_
  - Notes:
- Rapid project switching:
  - Result: _pass/fail_
  - Notes:
- Typing + validation coalescing:
  - Result: _pass/fail_
  - Notes:

### Telemetry/Instrumentation Results

- Pipeline telemetry counters behavior:
  - Result: _pass/fail_
  - Notes:
- Event log coalescing markers:
  - Result: _pass/fail_
  - Notes:
- Performance baseline capture reliability:
  - Result: _pass/fail_
  - Notes:

### Accessibility Results

- Keyboard-only traversal (Projects + Settings):
  - Result: _pass/fail_
  - Notes:
- VoiceOver labels/focus/state readout:
  - Result: _pass/fail_
  - Notes:

### Issues and Disposition

- Fixed during closeout:
  - [ ] _(list or mark none)_
- Accepted risk/deferred:
  - [ ] _(list or mark none, include rationale)_

### Final Phase Decision

- [ ] Mark `qa-and-hardening` as `completed` in the plan file.
- [ ] Record any deferred work as explicit follow-ups.

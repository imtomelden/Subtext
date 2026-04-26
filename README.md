# Subtext

A native macOS 26 SwiftUI app that serves as a local, file-system-backed CMS
for an Astro site (for example the `imtomelden.com` workspace). On first launch
you pick the website repository in a folder dialog; Subtext stores a
**security-scoped bookmark** so macOS does not re-prompt for access on every
run. A **default starting location** for that picker is compiled in for
convenience, but the app is not locked to a single path.

Subtext reads and writes:

- `src/content/splash.json` — home page sections and CTAs
- `src/content/site.json` — top-level site toggle
- `src/content/projects/*.mdx` — project case studies (YAML frontmatter + body)

When you close the app/window, Subtext creates timestamped backups for files
changed in that session under `<repo>/.subtext-backups/`. Every file also
exposes per-file version history with restore (and restores are backup-protected).

## Requirements

- macOS 26.0+ (Liquid Glass–era design; some surfaces use native glass where supported)
- Xcode 26+
- Swift 6

## Project layout

The app sources live under [`Subtext/`](Subtext). High-level structure:

```
Subtext/
  App/          SwiftUI entry point + AppDelegate for title-bar chrome
  Constants/    Repo root resolution, bookmarks, recent repos
  Models/       Codable data model + @Observable store
  Services/     Actor-isolated file / backup / build services + MDX parse/write
  Views/        SwiftUI views, organised by feature (Home, Projects, Settings)
  Resources/    Assets
```

## Generating the Xcode project

An [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec lives at
[`project.yml`](project.yml). To generate the `.xcodeproj`:

```bash
brew install xcodegen     # once
cd /path/to/Subtext
xcodegen generate
open Subtext.xcodeproj
```

Then build and run the `Subtext` scheme.

For a local rebuild and launch, you can also use [`scripts/rebuild-and-run.sh`](scripts/rebuild-and-run.sh) if present in your checkout.

### Command-line build (CI or headless)

From the same directory as `project.yml`:

```bash
xcodegen generate
xcodebuild -scheme Subtext -configuration Debug -destination 'platform=macOS' build
```

Signing uses the project’s local/ad hoc settings; adjust `CODE_SIGN_IDENTITY` in
CI if needed.

## Configuration

- **Repo folder:** Chosen at onboarding or under **Settings → Website repo**
  (see [`Subtext/Constants/RepoConstants.swift`](Subtext/Constants/RepoConstants.swift)).
  The default path shown in the open panel is `defaultRepoRoot` in that file;
  change it if your machine’s Astro repo usually lives elsewhere.
- **Recent websites:** The last few chosen repos are remembered for quick
  switching from Settings.
- **Appearance:** Settings includes optional compact layout density.

## Dev-server reliability runbook

Subtext now uses a strict preflight gate before launching `npm run dev`:

- selected repo must contain `package.json` with `scripts.dev`
- required content paths must exist (`src/content/splash.json`, `src/content/site.json`, `src/content/projects`)
- project frontmatter and required block fields must validate
- launch-time preflight does not silently mutate project files

### Canonical startup sequence

1. Pick a valid website repo in onboarding or Settings.
2. Run **Settings → Site health → Run preflight**.
3. If preflight reports repairable legacy blocks, run **Repair content** and re-run preflight.
4. Start dev server from the sidebar (or open **Dev server** from Settings) — full controls and log live in the Dev Server window.

### Troubleshooting when dev server fails

- **Folder validation failed:** re-pick a folder with the required structure.
- **Preflight failed (required fields):** fix the reported file/field in `src/content/projects/*.mdx`.
- **Repair required:** run **Repair content** in Settings, then re-run preflight.
- **Need CLI verification:** run `./scripts/health-check.sh /path/to/website` (append `--with-build` for a build smoke test).

## Features (current)

- Home and Settings editing with save/discard, conflict detection, and
  external-change banners
- Projects (MDX) with blocks, source preview, and version history
- Command palette (Go to / Find in content), focus mode (hide sidebar), keyboard shortcuts help
- Live preview window, dev server control, git status and publish flow
- Site health audit (assets + SEO), event log, menu bar status panel

## Phase plan (historical)

Earlier milestones; most items below now exist in the app and are kept for
context only.

1. **Phase 1 — Core MVP** — Home + Settings editing, save/restore flow,
   glass-style visual design.
2. **Phase 2 — Projects** — MDX parsing/serialisation and full project editing.
3. **Phase 3 — Polish** — source preview, build/dev integration, keyboard
   shortcuts, search, menu bar, backups/history.

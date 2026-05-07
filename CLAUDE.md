# CLAUDE.md

## Project

Subtext is a Swift/Xcode project for editing and validating project-page content (MDX, frontmatter, and visual blocks).

## Working Agreement

- Keep edits focused and minimal.
- Preserve existing behavior unless explicitly changing it.
- Prefer small, reviewable commits.
- Avoid broad refactors unless requested.

## Code Style

- Follow existing Swift conventions in nearby files.
- Use descriptive names and keep functions small.
- Add comments only when intent is non-obvious.
- Do not introduce new dependencies without clear need.

## Validation Checklist

Before finishing a task:

- Build the app in Xcode.
- Run relevant tests (especially `SubtextTests` when parsing/serialization changes).
- Verify modified editor flows manually when UI files change.
- Confirm no obvious lints/warnings are introduced.

## Safety Rules

- Never commit secrets or machine-specific credentials.
- Do not rewrite git history unless explicitly requested.
- Do not remove user-authored changes outside task scope.
- Flag risky migrations or data-shape changes before applying.

## Typical High-Impact Areas

- `Subtext/Services/MDXParser.swift`
- `Subtext/Services/MDXSerialiser.swift`
- `Subtext/Services/FileService.swift`
- `Subtext/Services/MicroblogService.swift`
- `Subtext/Views/Projects/`
- `SubtextTests/`

## Micro.blog CMS Integration

Home page content (`splash.json`) is now published to Micro.blog via the Micropub API in addition to being written to the local file. The local file becomes a warm fallback; the live site reads from Micro.blog.

**Key files:**
- `Subtext/Services/KeychainService.swift` — stores the API token securely (never in UserDefaults or on disk)
- `Subtext/Services/MicroblogService.swift` — actor with `fetchSplash`, `updateSplash`, and `createSplashPage` (Micropub)
- `Subtext/Models/MicroblogStore.swift` — `@Observable` store exposing `syncState`; called by `CMSStore` after local save
- `Subtext/Models/SiteSettings.swift` — `MicroblogSettings` struct (page URL + enabled flag) persisted in `site.json`

**Settings UI:** Settings → Micro.blog — token field (Keychain-backed), page URL, enable toggle, "Push current home content…" migration button.

**First-time setup:** Token → enable toggle → "Push current home content…" → page URL auto-fills from the Micropub `Location` response → save. Then add `MICROBLOG_TOKEN` and `MICROBLOG_PAGE_URL` to Vercel env vars.

**Micropub notes:**
- Create: `POST /micropub` form-encoded with `mp-channel=pages`
- Update: `POST /micropub` JSON body `{ action: update, url, replace: { content: [json] } }`
- Read (site-side): `GET /micropub?q=source&mp-channel=pages&url=...` — returns `{ items: [{ properties: { content: ["<json-string>"] } }] }`

## Notes for Future Changes

When modifying block models, parser logic, or serialization formats, ensure model, parser, serializer, UI editor, and tests stay in sync.

When modifying the splash save flow in `CMSStore`, be aware that `performSaveSplash` triggers a Micro.blog push after the local write succeeds. The push is fire-and-forget (Task) and surfaces errors as toasts via `microblogStore.syncState`.

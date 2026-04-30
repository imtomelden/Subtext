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
- `Subtext/Views/Projects/`
- `SubtextTests/`

## Notes for Future Changes

When modifying block models, parser logic, or serialization formats, ensure model, parser, serializer, UI editor, and tests stay in sync.

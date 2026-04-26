# Project Page Blocks

This folder contains the standardized block model for project pages:

1. `narrative`
2. `statCards`
3. `quote` (pull quote)
4. `mediaGrid`
5. `videoShowcase`
6. `cta`

Legacy imports may still include older block types (`projectSnapshot`, `keyStats`,
`goalsMetrics`, `mediaGallery`). Subtext preflight detects these and the
`Repair content` action migrates them to canonical equivalents before dev launch.

## Optional image frontmatter

- `thumbnail`: optional card/list image for project overviews.
- `headerImage`: optional hero image for project detail pages.
- If `headerImage` is omitted, frontends can safely fall back to `thumbnail`.

## Validation rules

- `projectSnapshot`: requires title, summary, owner team, start date, target completion date.
- `keyStats`: requires 3-5 items; each item must include label, value, and `lastUpdated`.
- `goalsMetrics`: requires 2-4 goals; each goal needs measure, baseline, target, and cadence.
- `quote`: requires quote text; attribution fields must be provided together (name + role/context).
- `mediaGallery`: each item requires `src` and `alt`.

## Pilot files

- `template.mdx`
- `pilot-neighbourhood-clean-up.mdx`
- `pilot-safe-routes.mdx`

Use these pilot entries to test editor behavior, YAML round-tripping, and schema checks before wider adoption.

# Project page blocks

The project page is one ordered `blocks:` list. **Layout blocks** place page chrome (hero, header image, MDX body, case study, video details, external link, tags, related projects). **Content blocks** are rich cards (project snapshot, key stats, goals, quotes, media, video showcase, CTA).

## Content block types

- `projectSnapshot` — project title, summary, status, team, timeline, optional budget
- `keyStats` — titled grid of label / value / unit / context / last updated
- `goalsMetrics` — goals with success measures, baselines, targets, cadence
- `statCards` — legacy site alias; normalises to `keyStats` in the parser
- `quote` — pull quote with optional attribution
- `mediaGallery` / `mediaGrid` — gallery of images (aliases map to the same model)
- `videoShowcase` — embedded YouTube, Vimeo, or file video
- `cta` — heading, optional description, link list

## Layout block types

- `body` — no fields; the MDX body renders at this position
- `pageHero` — optional `eyebrow`, `title`, `subtitle` (replaces top-level `hero:`)
- `headerImage` — `src`, optional `alt` (replaces top-level `headerImage:`)
- `caseStudy` — optional `challenge`, `approach`, `outcome`, `role`, `duration` (replaces the inline case-study fields)
- `videoDetails` — `runtime`, `platform`, `transcriptUrl`, `credits` (replaces top-level `videoMeta:` for layout)
- `externalLink` — `href`, optional `label` (default label on the site: “View project →”)
- `tagList` — no fields; project `tags:` render here
- `relatedProjects` — no fields; related projects (derived at build) render here

## Top-level frontmatter

Always: `title`, `slug`, `description`, `date`, `ownership`, `tags`, `featured`, `draft`, `thumbnail`, `externalUrl` (for listings/SEO; the external link block still controls in-page button placement when present).

Legacy fields remain readable for migration: `hero`, `headerImage`, `challenge`, `approach`, `outcome`, `role`, `duration`, `videoMeta`. Subtext stops emitting them once the matching layout block exists and is saved.

## Optional images

- `thumbnail` — list/card image
- `headerImage` — detail hero (or use a `headerImage` block instead)

## Validation (Subtext)

- `projectSnapshot`: requires title, summary, owner team, start date, target completion date.
- `keyStats`: items need label, value, and `lastUpdated` per row where applicable.
- `goalsMetrics`: each goal needs measure, baseline, target, and cadence.
- `quote`: quote text required; attribution is optional.
- `mediaGallery`: each item requires `src` and `alt`.
- `headerImage` (block): `src` required.
- `externalLink` (block): `href` required.

## Pilot files

- `template.mdx`
- `pilot-neighbourhood-clean-up.mdx`
- `pilot-safe-routes.mdx`

## Legacy preflight

`mediaGallery` may appear as `mediaGrid` in older YAML; the preflight pass rewrites the type line for the site schema. `projectSnapshot` and `goalsMetrics` are first-class block types and are not rewritten to other types.

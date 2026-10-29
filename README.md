# Terraform Lunch and Learn

Slidev deck (Carbon white theme) for session 1 of the IBM Cloud IaC series:
Terraform fundamentals, with a live VPC + server demo.

```
slides/            Slidev project (slides.md has speaker notes in HTML comments)
take_screens.py    Playwright script that captures portal screenshots into shots/
mise.toml          Task runner config (python 3.12, node 22)
```

## Prerequisites

- [mise](https://mise.jdx.dev) (installs the pinned node and python versions)
- A Vercel account if you want to deploy (`npx vercel login` once)

```bash
mise install
```

## Run the deck locally

```bash
mise run slides          # installs deps, starts Slidev, opens the browser
```

Handy keys while presenting: `o` overview, `d` dark mode toggle, `p` presenter
view (shows the speaker notes), arrow keys / space to step through clicks.

## Build

```bash
mise run slides:build    # static site in slides/dist
mise run slides:export   # PDF in slides/dist/terraform-lunch-and-learn.pdf
```

Without mise, from inside `slides/`:

```bash
npm install
npx slidev build slides.md --out dist
```

## Deploy to Vercel

`slides/vercel.json` already sets the install command, build command
(`npx slidev build slides.md --out dist`), output directory (`dist`) and an SPA
rewrite so links like `/12` load the right slide.

```bash
cd slides
npx vercel deploy --prod
```

The first run asks you to link the project (team: `greyhoundfortys-projects`,
project: `tf101`). That creates `slides/.vercel/` and `slides/.env.local`,
both gitignored. Use `npx vercel deploy` (no `--prod`) for a preview URL.

## Notes

- Fonts (IBM Plex) load from Google Fonts at runtime, so check the venue wifi
  or open the deck once beforehand so the browser caches them.
- `auth.json` (Playwright login state for `take_screens.py`) is a credential.
  It is gitignored; never commit it.

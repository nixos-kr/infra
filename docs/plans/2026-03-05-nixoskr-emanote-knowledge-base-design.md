# nixos.kr Emanote Knowledge Base — Design

**Date**: 2026-03-05
**Status**: Approved

## Context

nixos.kr is the domain for the Korean NixOS Discord community. The community wants a web presence that serves as:
1. Onboarding guide for Korean-speaking Nix newcomers (highest priority)
2. Knowledge archive from Discord Q&A
3. Community hub (future: Discourse)
4. Reference docs for Korean Nix users

Inspiration: [nixos.asia](https://nixos.asia) — an Emanote-based Zettelkasten knowledge base for Asian Nix communities.

## Decision

Use **Emanote** (by srid) as the static site generator. It provides:
- Zettelkasten-style interconnected notes with `[[wiki-links]]`
- Automatic backlinks and connection graph visualization
- Static HTML output deployable to GitHub Pages / Cloudflare Pages
- Nix-native (Haskell, available as flake-parts module)
- Markdown content in git — fully declarative

## Alternatives Considered

- **Docusaurus/VitePress**: Good for structured docs but tree-structured, not graph-structured. Node.js-based (un-Nixy).
- **Hakyll (current skeleton)**: Maximum flexibility but essentially rebuilding Emanote from scratch.
- **Discourse/Wiki.js**: Requires a server. Saved for future community discussion phase.

## Architecture

```
nixos.kr/
├── flake.nix              # Emanote via flake-parts module
├── flake.lock
├── global/                # Shared assets (images, templates, CSS)
│   └── templates/
├── ko/                    # Korean content (primary)
│   ├── index.md           # Landing page
│   ├── index.yaml         # Site config (title, base URL, edit URL)
│   ├── start/             # Onboarding guide (linear note chain)
│   │   ├── install-nix.md
│   │   ├── first-shell.md
│   │   ├── first-flake.md
│   │   └── nixos-install.md
│   ├── topics/            # Reference topics (knowledge graph)
│   │   ├── flakes.md
│   │   ├── home-manager.md
│   │   └── ...
│   └── faq/               # Discord-extracted Q&A
├── en/                    # English content (future placeholder)
└── .github/workflows/
    └── publish.yaml       # CI: build & deploy static site
```

## Content Model

- Each page is a Markdown file with YAML frontmatter
- Pages link via `[[wiki-links]]` — Emanote renders backlinks automatically
- Onboarding path: linear chain through `start/` directory
- Knowledge graph grows organically as topics and FAQ entries are added

## Deployment

- `nix build .#ko` → static HTML in `./result`
- GitHub Actions publishes to GitHub Pages (or Cloudflare Pages)
- Custom domain: `nixos.kr` via CNAME

## Contribution Workflow

- Core team: git clone → edit Markdown → PR
- Community: GitHub web editor → edit Markdown → PR
- All content is Markdown — no build tools needed for contributors

## Growth Path

| Phase | Scope | Timing |
|-------|-------|--------|
| 1 | Onboarding guide (5-10 notes) | First launch |
| 2 | Topic reference pages | Ongoing |
| 3 | FAQ extraction from Discord | Ongoing |
| 4 | English content layer | When ready |
| 5 | Discourse on dedicated server | Future |

## Constraints

- Fully declarative: Nix flake defines the build, git defines content
- Static-first: no server required for initial launch
- Korean-first: `ko/` is the primary content layer
- No legal organization: community-driven, open-source

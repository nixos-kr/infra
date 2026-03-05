# Discord Archive Bot — Design

**Date**: 2026-03-05
**Status**: Approved

## Context

The nixos.kr Discord server accumulates valuable Q&A knowledge that gets lost in chat history. Moderators need a way to archive useful conversations into the Emanote knowledge base as FAQ entries.

## Decision

Build a Discord slash command `/archive <message-link>` that extracts a conversation from Discord, digests it into a structured FAQ entry via Gemini API, and opens a GitHub PR.

## Architecture

```
/archive <message-link>
       │
       ▼
  Cloudflare Worker (JS)
    - Receives Discord interaction
    - Validates signature
    - Responds "📋 아카이브 처리 중..."
    - Triggers GitHub Actions via repository_dispatch
       │
       ▼
  GitHub Actions workflow
    Haskell CLI binary:
      1. Parse message link → channel ID + message ID
      2. Fetch surrounding conversation via Discord API
         - Smart clustering: group by time gaps (<5min) and participants
      3. Send conversation to Gemini 2.5 Pro API
         - Prompt: produce Korean FAQ in template format
           (제목, 증상, 원인, 해결 방법, 관련 주제 with [[wiki-links]])
      4. Create PR with generated ko/faq/<slug>.md
      5. Post PR link back to Discord channel via webhook
```

## Components

| Component | Tech | Location |
|-----------|------|----------|
| Discord interaction endpoint | Cloudflare Worker (JS) | Managed via Wrangler CLI |
| Message fetcher + PR creator | Haskell CLI | This repo, built via Nix flake |
| LLM digest | Gemini 2.5 Pro | Google AI Studio API |

## Secrets

| Secret | Source | Used by |
|--------|--------|---------|
| `DISCORD_BOT_TOKEN` | Discord Developer Portal | Haskell CLI (fetch messages, post response) |
| `DISCORD_PUBLIC_KEY` | Discord Developer Portal | Cloudflare Worker (verify signatures) |
| `DISCORD_APPLICATION_ID` | Discord Developer Portal | Slash command registration |
| `GEMINI_API_KEY` | Google AI Studio | Haskell CLI (digest conversation) |
| `GITHUB_TOKEN` | Auto-provided by Actions | Haskell CLI (create PR) |

## Message clustering algorithm

Given a linked message, the bot:
1. Fetches ~50 messages around it (25 before, 25 after)
2. Groups messages into conversation clusters by:
   - Time gap: messages within 5 minutes of each other belong to same cluster
   - Participant continuity: if the same people are talking, extend the cluster
3. Selects the cluster containing the linked message
4. Includes the full cluster in the digest

## Gemini prompt template

The prompt instructs Gemini to produce output matching the FAQ template from CONTRIBUTING.md:

```markdown
# <제목>

## 증상
<문제 설명>

## 원인
<원인 분석>

## 해결 방법
<단계별 해결책>

## 관련 주제
- [[topics/...]]
```

## Constraints

- Every archive action produces a PR, never a direct commit
- The bot only works in designated channels (configurable)
- Moderators only (permission check in Cloudflare Worker)
- Haskell CLI is built via Nix and cached in GitHub Actions
- Cloudflare Worker is free tier (100k requests/day)

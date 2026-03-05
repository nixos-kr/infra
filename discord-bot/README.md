# Discord Archive Bot

Discord 대화를 FAQ 항목으로 변환하여 PR을 생성하는 봇입니다.

## 구조

```
discord-bot/
├── src/                    # Haskell CLI (메시지 수집 → 클러스터링 → Gemini 요약)
│   ├── Main.hs
│   ├── MessageLink.hs      # Discord 메시지 링크 파서
│   ├── Discord.hs          # Discord REST API 호출
│   ├── Cluster.hs          # 시간/참여자 기반 메시지 클러스터링
│   └── Gemini.hs           # Gemini 2.5 Pro API 호출
├── worker/                 # Rust Cloudflare Worker (Discord ↔ GitHub Actions 브릿지)
│   ├── src/lib.rs
│   ├── Cargo.toml
│   └── wrangler.toml
├── test/                   # 테스트
├── flake.nix               # Haskell CLI 빌드
├── register-command.sh     # 슬래시 명령어 등록 스크립트
└── discord-archive.cabal
```

## 작동 방식

```
/archive <메시지 링크>
       │
       ▼
  Cloudflare Worker (Rust)
    - Ed25519 서명 검증
    - "📋 처리 중..." 응답
    - GitHub Actions repository_dispatch 트리거
       │
       ▼
  GitHub Actions
    1. Haskell CLI 빌드 (Nix)
    2. Discord API로 대화 가져오기 (메시지 주변 50개)
    3. 시간 간격(<5분) + 참여자 연속성으로 클러스터링
    4. Gemini 2.5 Pro로 FAQ 마크다운 생성
    5. PR 생성 (ko/faq/<slug>.md)
    6. Discord에 PR 링크 응답
```

## 설정

### 1. Discord 애플리케이션 생성

1. [Discord Developer Portal](https://discord.com/developers/applications)에서 앱 생성
2. Bot 탭에서 토큰 복사 → `DISCORD_BOT_TOKEN`
3. General Information에서 Public Key 복사 → `DISCORD_PUBLIC_KEY`
4. Application ID 복사 → `DISCORD_APPLICATION_ID`
5. Bot에 `MESSAGE_CONTENT` Privileged Intent 활성화

### 2. Gemini API 키 발급

[Google AI Studio](https://aistudio.google.com/apikey)에서 API 키 생성 → `GEMINI_API_KEY`

### 3. Cloudflare Worker 배포

```bash
cd discord-bot/worker

# 시크릿 설정
npx wrangler secret put DISCORD_PUBLIC_KEY
npx wrangler secret put GITHUB_TOKEN    # repo scope 필요

# 배포
npx wrangler deploy
```

배포 후 Worker URL을 Discord Developer Portal → General Information → Interactions Endpoint URL에 입력합니다:

```
https://nixoskr-archive-bot.<subdomain>.workers.dev/interactions
```

Discord가 PING을 보내 엔드포인트를 검증합니다.

### 4. 슬래시 명령어 등록

```bash
./discord-bot/register-command.sh <APPLICATION_ID> <BOT_TOKEN>
```

`MANAGE_MESSAGES` 권한이 있는 사용자만 명령어를 사용할 수 있습니다.

### 5. GitHub Actions 시크릿

GitHub 저장소 → Settings → Secrets → Actions에 추가:

| 시크릿 | 설명 |
|--------|------|
| `DISCORD_BOT_TOKEN` | Discord 봇 토큰 |
| `GEMINI_API_KEY` | Google AI Studio API 키 |

`GITHUB_TOKEN`은 Actions가 자동 제공합니다.

## 로컬 빌드

```bash
cd discord-bot

# 빌드
nix build .#default

# 테스트
nix develop -c cabal test

# 직접 실행 (디버그용)
./result/bin/discord-archive \
  --channel-id <CHANNEL_ID> \
  --message-id <MESSAGE_ID> \
  --discord-token <TOKEN> \
  --gemini-key <KEY>
```

CLI는 JSON을 stdout으로 출력합니다:

```json
{"slug": "unfree-패키지-설치", "content": "# unfree 패키지를 설치하고 싶어요\n..."}
```

## 사용법

Discord에서 아카이브할 메시지를 찾고:

1. 메시지 우클릭 → "메시지 링크 복사"
2. `/archive link:<붙여넣기>`
3. 봇이 "📋 처리 중..." 응답 후 PR 링크를 표시합니다

생성된 PR을 리뷰하고 머지하면 FAQ가 [nixos.kr](https://nixos.kr)에 게시됩니다.

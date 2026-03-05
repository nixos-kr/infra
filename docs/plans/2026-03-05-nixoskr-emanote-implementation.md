# nixos.kr Emanote Knowledge Base — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the Hakyll skeleton with an Emanote-based Zettelkasten knowledge base for the Korean NixOS community, starting with an onboarding guide.

**Architecture:** Emanote via flake-parts module renders Markdown content from `ko/` (Korean) and `global/` (shared assets) layers into a static site. GitHub Actions deploys to GitHub Pages with custom domain `nixos.kr`. Content uses `[[wiki-links]]` for interconnected notes.

**Tech Stack:** Emanote (flake-parts module), Nix flakes, Markdown, GitHub Actions, GitHub Pages

---

### Task 1: Clean up old Hakyll skeleton

**Files:**
- Delete: `nixos.kr/nixos-kr/` (entire Hakyll project directory)
- Delete: `nixos.kr/nixos.qcow2` (stale VM disk image)

**Step 1: Remove old files**

```bash
cd /home/jhhuh/Sync/proj/nixoskr-infra/nixos.kr
rm -rf nixos-kr/ nixos.qcow2
```

**Step 2: Commit**

```bash
git add -A nixos.kr/nixos-kr nixos.kr/nixos.qcow2
git commit -m "remove hakyll skeleton and stale VM image

Replacing with Emanote-based knowledge base."
```

---

### Task 2: Rewrite flake.nix for Emanote

**Files:**
- Rewrite: `nixos.kr/flake.nix`
- Keep: `nixos.kr/static-web-server.nix`, `nixos.kr/port-forward.nix` (still useful for local VM testing later)

**Step 1: Rewrite flake.nix**

Replace the entire file with:

```nix
{
  nixConfig = {
    extra-substituters = "https://cache.nixos.asia/oss";
    extra-trusted-public-keys = "oss:KO872wNJkCDgmGN3xy9dT89WAhvv13EiKncTtHDItVU=";
  };

  inputs = {
    emanote.url = "github:srid/emanote";
    emanote.inputs.emanote-template.follows = "";
    nixpkgs.follows = "emanote/nixpkgs";
    flake-parts.follows = "emanote/flake-parts";
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      imports = [ inputs.emanote.flakeModule ];
      perSystem = { self', pkgs, ... }: {
        emanote.sites = {
          default = {
            layers = [
              { path = ./global; pathString = "./global"; }
              { path = ./ko; pathString = "./ko"; }
            ];
          };
        };
        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.nixpkgs-fmt ];
        };
      };
    };
}
```

**Step 2: Update flake.lock**

```bash
cd /home/jhhuh/Sync/proj/nixoskr-infra/nixos.kr
nix flake update
```

Expected: flake.lock regenerated with emanote, nixpkgs, flake-parts inputs.

**Step 3: Verify it evaluates**

```bash
nix flake show
```

Expected: Shows `packages.<system>.default` and `devShells.<system>.default`.

**Step 4: Commit**

```bash
git add flake.nix flake.lock
git commit -m "rewrite flake.nix for Emanote via flake-parts

Uses emanote flakeModule with ko/ and global/ content layers.
Binary cache from cache.nixos.asia for faster builds."
```

---

### Task 3: Create content directory structure and landing page

**Files:**
- Create: `nixos.kr/global/.gitkeep`
- Create: `nixos.kr/ko/index.md`
- Create: `nixos.kr/ko/index.yaml`

**Step 1: Create directories**

```bash
mkdir -p nixos.kr/global nixos.kr/ko
touch nixos.kr/global/.gitkeep
```

**Step 2: Create site config (index.yaml)**

Create `nixos.kr/ko/index.yaml`:

```yaml
template:
  theme: blue
  sidebar:
    enable: true
    collapsed: false
  urlStrategy: pretty
page:
  siteTitle: NixOS Korea
  editBaseUrl: https://github.com/<OWNER>/<REPO>/edit/master/nixos.kr/ko/
```

Note: `<OWNER>/<REPO>` should be replaced with the actual GitHub repo path.

**Step 3: Create landing page (index.md)**

Create `nixos.kr/ko/index.md`:

```markdown
---
page:
  description: 한국어 NixOS 커뮤니티 지식 베이스
---

# NixOS Korea

한국어 NixOS 커뮤니티의 지식 베이스에 오신 것을 환영합니다.

## 시작하기

NixOS가 처음이신가요? [[start|입문 가이드]]를 따라가 보세요.

## 주제

- [[topics|주제별 문서]]

## 커뮤니티

- [Discord 서버](https://discord.gg/YOUR_INVITE)에서 질문하고 토론하세요.
```

**Step 4: Commit**

```bash
git add nixos.kr/global nixos.kr/ko
git commit -m "add content directory structure and landing page

Korean landing page with links to onboarding guide and topics."
```

---

### Task 4: Create onboarding guide — first notes

**Files:**
- Create: `nixos.kr/ko/start.md` (onboarding index)
- Create: `nixos.kr/ko/start/install-nix.md`
- Create: `nixos.kr/ko/start/first-shell.md`
- Create: `nixos.kr/ko/start/first-flake.md`

**Step 1: Create onboarding index**

Create `nixos.kr/ko/start.md`:

```markdown
# 입문 가이드

NixOS를 처음 사용하시는 분을 위한 단계별 가이드입니다.

1. [[start/install-nix|Nix 설치하기]]
2. [[start/first-shell|첫 번째 Nix Shell]]
3. [[start/first-flake|첫 번째 Flake]]
```

**Step 2: Create install-nix.md**

Create `nixos.kr/ko/start/install-nix.md`:

```markdown
# Nix 설치하기

Nix 패키지 매니저를 설치하는 방법을 알아봅시다.

## 공식 설치 스크립트

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

## 설치 확인

```bash
nix --version
```

## 다음 단계

- [[start/first-shell|첫 번째 Nix Shell 사용하기]]

## 관련 주제

- [[topics/flakes|Flakes]]
```

**Step 3: Create first-shell.md**

Create `nixos.kr/ko/start/first-shell.md`:

```markdown
# 첫 번째 Nix Shell

`nix-shell`을 사용해서 임시 개발 환경을 만들어 봅시다.

## 기본 사용법

```bash
nix-shell -p python3 git
```

이 명령어를 실행하면 Python 3와 Git이 설치된 임시 셸에 들어갑니다.
셸을 나가면 (`exit` 또는 Ctrl-D) 설치된 패키지가 사라집니다.

## 다음 단계

- [[start/first-flake|첫 번째 Flake 만들기]]

## 관련 주제

- [[topics/flakes|Flakes]]
```

**Step 4: Create first-flake.md**

Create `nixos.kr/ko/start/first-flake.md`:

```markdown
# 첫 번째 Flake

Nix Flake를 사용해서 재현 가능한 프로젝트 환경을 만들어 봅시다.

## Flake 초기화

```bash
mkdir my-project && cd my-project
nix flake init
```

## flake.nix 살펴보기

생성된 `flake.nix` 파일을 열어보세요. 기본 구조는 다음과 같습니다:

- `inputs`: 의존성 (예: nixpkgs)
- `outputs`: 이 flake가 제공하는 것 (패키지, 셸, 설정 등)

## 관련 주제

- [[topics/flakes|Flakes 개요]]
```

**Step 5: Commit**

```bash
git add nixos.kr/ko/start.md nixos.kr/ko/start/
git commit -m "add onboarding guide: install, first shell, first flake

Three-step Korean onboarding path with wiki-links between notes."
```

---

### Task 5: Create initial topic pages

**Files:**
- Create: `nixos.kr/ko/topics.md` (topics index)
- Create: `nixos.kr/ko/topics/flakes.md`
- Create: `nixos.kr/ko/topics/home-manager.md`

**Step 1: Create topics index**

Create `nixos.kr/ko/topics.md`:

```markdown
# 주제별 문서

NixOS 관련 주제를 정리한 문서 모음입니다.

- [[topics/flakes|Flakes]]
- [[topics/home-manager|Home Manager]]
```

**Step 2: Create flakes.md**

Create `nixos.kr/ko/topics/flakes.md`:

```markdown
# Flakes

Nix Flakes는 Nix 프로젝트의 의존성 관리와 재현성을 위한 기능입니다.

## 핵심 개념

- `flake.nix`: 프로젝트의 입력(inputs)과 출력(outputs)을 선언
- `flake.lock`: 의존성 버전을 고정하여 재현성 보장

## 관련 문서

- [[start/first-flake|첫 번째 Flake 만들기]]
```

**Step 3: Create home-manager.md**

Create `nixos.kr/ko/topics/home-manager.md`:

```markdown
# Home Manager

Home Manager는 Nix를 사용하여 사용자 환경(dotfiles, 프로그램 설정)을 선언적으로 관리하는 도구입니다.

## 관련 문서

- [[topics/flakes|Flakes]] — Home Manager는 Flake로 설치할 수 있습니다
```

**Step 4: Commit**

```bash
git add nixos.kr/ko/topics.md nixos.kr/ko/topics/
git commit -m "add initial topic pages: flakes, home-manager

Stub pages with wiki-links to onboarding guide for cross-referencing."
```

---

### Task 6: Build and test locally

**Step 1: Build the static site**

```bash
cd /home/jhhuh/Sync/proj/nixoskr-infra/nixos.kr
nix build .#default -o ./result
```

Expected: `./result/` contains the generated static HTML site.

**Step 2: Verify output structure**

```bash
ls ./result/
```

Expected: `index.html` and directories for `start/`, `topics/` etc.

**Step 3: Run the dev server**

```bash
nix run
```

Expected: Opens a local dev server (typically port 8080). Visit in browser to verify:
- Landing page renders with links
- Wiki-links resolve correctly
- Backlinks appear on topic pages
- Connection graph visible at page top

**Step 4: Clean up**

```bash
rm -f result
```

**Step 5: Commit .gitignore update if needed**

```bash
echo "result" >> .gitignore
git add .gitignore
git commit -m "add result to gitignore"
```

---

### Task 7: Add GitHub Actions deployment

**Files:**
- Create: `nixos.kr/.github/workflows/publish.yaml`

**Step 1: Create workflow**

Create `nixos.kr/.github/workflows/publish.yaml`:

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [master]

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: nixbuild/nix-quick-install-action@v33
      - run: nix --accept-flake-config build .#default -o ./_site
        working-directory: nixos.kr
      - uses: actions/upload-pages-artifact@v3

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

Note: The `working-directory` is set to `nixos.kr` because the flake lives in a subdirectory of the repo.

**Step 2: Add CNAME for custom domain**

Create `nixos.kr/global/CNAME`:

```
nixos.kr
```

Note: Emanote copies files from global/ into the output. The CNAME file in global/ will end up in the site root for GitHub Pages custom domain.

**Step 3: Commit**

```bash
git add nixos.kr/.github nixos.kr/global/CNAME
git commit -m "add GitHub Actions workflow for Pages deployment

Builds Emanote site from nixos.kr/ subdirectory, deploys to GitHub Pages
with nixos.kr custom domain."
```

---

### Task 8: Push and verify deployment

**Step 1: Push to remote**

```bash
git push
```

**Step 2: Verify GitHub Actions run**

Check the Actions tab on GitHub. The workflow should build and deploy.

**Step 3: Configure GitHub Pages**

In repo Settings → Pages:
- Source: GitHub Actions
- Custom domain: nixos.kr

**Step 4: Configure DNS**

Add DNS records for nixos.kr pointing to GitHub Pages:
- `A` records: 185.199.108.153, 185.199.109.153, 185.199.110.153, 185.199.111.153
- Or `CNAME` to `<username>.github.io`

---

## Summary

| Task | What | Commit |
|------|------|--------|
| 1 | Remove Hakyll skeleton + stale VM image | `remove hakyll skeleton...` |
| 2 | Rewrite flake.nix for Emanote | `rewrite flake.nix...` |
| 3 | Create directory structure + landing page | `add content directory...` |
| 4 | Write onboarding guide (3 notes) | `add onboarding guide...` |
| 5 | Write initial topic pages (2 notes) | `add initial topic pages...` |
| 6 | Build and test locally | `add result to gitignore` |
| 7 | Add GitHub Actions deployment | `add GitHub Actions...` |
| 8 | Push and verify deployment | (push + manual config) |

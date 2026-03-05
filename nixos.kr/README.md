# nixos.kr

[nixos.kr](https://nixos.kr) 한국어 NixOS 커뮤니티 지식 베이스입니다.

[Emanote](https://emanote.srid.ca)로 만들어진 정적 사이트이며, 콘텐츠는 `ko/` 디렉토리의 Markdown 파일들입니다.

## 콘텐츠 수정/추가하기

`ko/` 안의 `.md` 파일을 수정하거나 새로 만드세요. 페이지 간 연결은 `[[wiki-link]]` 문법을 사용합니다:

```markdown
[[topics/flakes|Flakes 개요]]
```

## 로컬 미리보기

```bash
nix run .#default
```

브라우저에서 표시되는 주소(기본: http://localhost:8080)를 열면 실시간 미리보기가 가능합니다. 파일을 수정하면 자동으로 반영됩니다.

## 정적 사이트 빌드

```bash
nix build .#default
ls result/
```

## PR 기여 방법

1. 저장소를 fork합니다
2. `ko/` 안의 Markdown 파일을 수정/추가합니다
3. `nix run .#default`로 로컬에서 확인합니다
4. PR을 제출합니다

`master` 브랜치에 머지되면 자동으로 배포됩니다.

## 구조

```
nixos.kr/
├── flake.nix          # Emanote 빌드 설정
├── global/            # 공유 에셋 (이미지, CNAME 등)
├── ko/                # 한국어 콘텐츠
│   ├── index.md       # 메인 페이지
│   ├── start/         # 입문 가이드
│   └── topics/        # 주제별 문서
└── dns/               # DNS 관리 (OpenTofu + Cloudflare)
```

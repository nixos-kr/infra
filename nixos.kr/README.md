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
cd nixos.kr
nix run .#default
```

브라우저에서 표시되는 주소(기본: http://localhost:8080)를 열면 실시간 미리보기가 가능합니다. 파일을 수정하면 자동으로 반영됩니다.

저장소 루트에서 실행할 경우:

```bash
nix run ./nixos.kr#default
```

## 정적 사이트 빌드

```bash
cd nixos.kr
nix build .#default
ls result/
```

## PR 기여 방법

1. 저장소를 fork합니다
2. `ko/` 안의 Markdown 파일을 수정/추가합니다
3. `cd nixos.kr && nix run .#default`로 로컬에서 확인합니다
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
├── dns/               # DNS 관리 (OpenTofu + Cloudflare)
└── .env.example       # 시크릿 템플릿 (Cloudflare 인증)
```

## DNS 관리

DNS 레코드를 OpenTofu + Cloudflare로 선언적으로 관리합니다.

### 설정

1. Cloudflare 인증 정보 준비:
   - **Zone ID**: Dashboard → nixos.kr → Overview → 우측 사이드바
   - **API Token**: My Profile → API Tokens → Create Token → "Edit zone DNS"

2. 시크릿 파일 생성:
   ```bash
   cp .env.example .env
   # Cloudflare API 토큰과 Zone ID 입력
   ```

   > `.env`는 **시크릿**이며 gitignore 대상입니다. 절대 커밋하지 마세요.

### 사용법

```bash
nix run .#dns -- plan   # 변경사항 미리보기
nix run .#dns           # 변경사항 적용
```

CWD에 `.env`가 있으면 어디서든 실행 가능합니다. `dns/` 디렉토리에 `.tf` 파일과 상태 파일이 생성됩니다.

### 레코드 추가

`dns/main.tf`를 수정하고 `cloudflare_record` 리소스를 추가하세요:

```hcl
resource "cloudflare_record" "example" {
  zone_id = var.zone_id
  name    = "sub"
  type    = "CNAME"
  content = "example.com"
  proxied = false
}
```

### 기존 레코드 가져오기

Cloudflare에 이미 존재하는 레코드는 적용 전에 import 하세요:

```bash
# 레코드 ID 찾기
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records?name=RECORD_NAME" \
  | jq '.result[0].id'

# state로 가져오기
nix run .#dns -- import 'cloudflare_record.RESOURCE_NAME' ZONE_ID/RECORD_ID
```

# 기여 가이드

nixos.kr에 기여해 주셔서 감사합니다!

## 기여 방법

### GitHub 웹에서 (가장 쉬움)

1. [nixos.kr](https://nixos.kr)에서 수정하고 싶은 페이지를 찾습니다
2. 페이지 하단의 "Edit this page" 링크를 클릭합니다
3. GitHub에서 Markdown을 수정하고 PR을 제출합니다

### 로컬에서

```bash
# 1. 저장소를 fork하고 clone합니다
git clone https://github.com/YOUR_USERNAME/infra.git
cd infra/nixos.kr

# 2. 콘텐츠를 수정/추가합니다
# ko/ 디렉토리 안의 .md 파일을 편집하세요

# 3. 로컬에서 확인합니다
nix run .#default
# 브라우저에서 http://localhost:8080 을 엽니다

# 4. PR을 제출합니다
git checkout -b my-change
git add .
git commit -m "설명"
git push origin my-change
# GitHub에서 PR을 생성합니다
```

## 콘텐츠 작성 규칙

### 파일 위치

| 종류 | 위치 | 예시 |
|------|------|------|
| 입문 가이드 | `ko/start/` | `ko/start/install-nix.md` |
| 주제별 문서 | `ko/topics/` | `ko/topics/flakes.md` |
| FAQ | `ko/faq/` | `ko/faq/slow-build.md` |

### 위키 링크

페이지 간 연결은 `[[wiki-link]]` 문법을 사용합니다:

```markdown
[[topics/flakes|Flakes 개요]]        # 다른 페이지로 링크
[[start/install-nix|Nix 설치하기]]   # 표시 텍스트 지정
```

Emanote가 자동으로 역방향 링크(backlinks)를 생성합니다.

### 새 페이지 만들기

1. 적절한 디렉토리에 `.md` 파일을 만듭니다
2. 제목을 `# 제목` 형식으로 시작합니다
3. 관련 페이지에 `[[wiki-link]]`를 추가합니다
4. 기존 페이지에서도 새 페이지로 링크를 추가합니다

### FAQ 작성 형식

Discord에서 자주 나오는 질문을 문서화할 때:

```markdown
# 빌드가 너무 느려요

## 증상

nix build 또는 nixos-rebuild가 오래 걸리는 경우

## 원인

- 바이너리 캐시를 사용하지 않는 경우
- ...

## 해결 방법

...

## 관련 주제

- [[topics/flakes|Flakes]]
```

## 질문이 있나요?

[Discord 서버](https://discord.gg/6fybcHTnup)에서 물어보세요!

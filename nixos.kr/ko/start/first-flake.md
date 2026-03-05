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

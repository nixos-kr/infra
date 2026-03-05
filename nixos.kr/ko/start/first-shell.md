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

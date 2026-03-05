# unfree 패키지를 설치하고 싶어요

## 증상

`nix-env -iA` 또는 `nix shell` 실행 시 다음과 같은 에러가 나오는 경우:

```
error: Package 'vscode-1.xx.x' has an unfree license ('unfree'), refusing to evaluate.
```

## 원인

Nix는 기본적으로 자유 소프트웨어 라이선스가 아닌 패키지의 설치를 거부합니다.

## 해결 방법

### 임시로 허용

```bash
NIXPKGS_ALLOW_UNFREE=1 nix shell nixpkgs#vscode --impure
```

### 영구 설정 (NixOS)

`configuration.nix`에 추가:

```nix
nixpkgs.config.allowUnfree = true;
```

### 영구 설정 (Home Manager)

```nix
nixpkgs.config.allowUnfree = true;
```

### Flake에서

```nix
nixpkgs = import inputs.nixpkgs {
  inherit system;
  config.allowUnfree = true;
};
```

## 관련 주제

- [[topics/flakes|Flakes]]
- [[topics/home-manager|Home Manager]]

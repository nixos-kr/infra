# 빌드가 너무 느려요

## 증상

`nix build`, `nixos-rebuild`, 또는 `home-manager switch`가 오래 걸리는 경우.

## 원인

소스에서 직접 컴파일하고 있을 가능성이 높습니다. 바이너리 캐시에서 미리 빌드된 결과물을 받아오면 대부분의 빌드가 빨라집니다.

## 해결 방법

### 1. 바이너리 캐시 확인

`/etc/nix/nix.conf` 또는 flake의 `nixConfig`에 공식 캐시가 설정되어 있는지 확인하세요:

```
substituters = https://cache.nixos.org
```

### 2. nixpkgs 버전 맞추기

`nixpkgs`를 최신 안정 채널(예: `nixos-24.11`)로 고정하면 캐시 히트율이 높아집니다. `unstable`은 캐시가 아직 없는 경우가 있습니다.

### 3. 불필요한 재빌드 피하기

`nix build`에 `--log-format bar-with-logs`를 붙이면 무엇을 빌드하고 있는지 확인할 수 있습니다.

## 관련 주제

- [[topics/flakes|Flakes]]

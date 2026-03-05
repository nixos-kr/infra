# flake.lock 충돌이 나요

## 증상

`git pull` 또는 `git rebase` 시 `flake.lock`에서 merge conflict가 발생하는 경우.

## 원인

여러 사람이 각자 `nix flake update`를 실행하면 `flake.lock`이 서로 다른 버전으로 갱신됩니다.

## 해결 방법

`flake.lock` 충돌은 한쪽을 선택한 뒤 다시 업데이트하면 됩니다:

```bash
# 상대방 버전을 수락
git checkout --theirs flake.lock
# 다시 업데이트
nix flake update
git add flake.lock
git rebase --continue   # 또는 git commit
```

## 관련 주제

- [[topics/flakes|Flakes]]

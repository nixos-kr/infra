# Discord Archive Bot Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Discord `/archive <message-link>` slash command that extracts conversations, digests them into FAQ entries via Gemini, and opens GitHub PRs.

**Architecture:** Rust Cloudflare Worker receives Discord interaction → verifies Ed25519 signature → responds with deferred message → triggers GitHub Actions via `repository_dispatch`. GitHub Actions builds and runs a Haskell CLI that fetches messages, clusters them, calls Gemini 2.5 Pro, and outputs FAQ markdown. The workflow script handles git branching, PR creation, and posting the PR link back to Discord.

**Tech Stack:** Rust (Cloudflare Worker via `workers-rs`), Haskell (CLI via Nix), Gemini 2.5 Pro API, GitHub Actions, Discord REST API

**Design doc:** `docs/plans/2026-03-05-discord-archive-bot-design.md`

---

### Task 1: Haskell CLI project scaffold

**Files:**
- Create: `discord-bot/discord-archive.cabal`
- Create: `discord-bot/flake.nix`
- Create: `discord-bot/src/Main.hs`

**Step 1: Create directory structure**

```bash
mkdir -p discord-bot/src
```

**Step 2: Write cabal file**

Create `discord-bot/discord-archive.cabal`:

```cabal
cabal-version:      3.0
name:               discord-archive
version:            0.1.0.0
synopsis:           Discord conversation archiver for nixos.kr
license:            MIT

executable discord-archive
  main-is:          Main.hs
  hs-source-dirs:   src
  default-language: Haskell2010
  default-extensions:
    OverloadedStrings
    DeriveGeneric
    RecordWildCards
  ghc-options:      -Wall
  build-depends:
      base          >= 4.14 && < 5
    , aeson         >= 2.0
    , bytestring
    , optparse-applicative >= 0.16
    , req           >= 3.9
    , text
    , time
    , vector
```

**Step 3: Write flake.nix**

Create `discord-bot/flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      perSystem = { pkgs, ... }:
        let
          hpkgs = pkgs.haskellPackages;
          discordArchive = hpkgs.developPackage {
            root = ./.;
          };
        in
        {
          packages.default = discordArchive;
          devShells.default = discordArchive.env.overrideAttrs (old: {
            buildInputs = (old.buildInputs or []) ++ [
              pkgs.cabal-install
              hpkgs.haskell-language-server
            ];
          });
        };
    };
}
```

**Step 4: Write minimal Main.hs**

Create `discord-bot/src/Main.hs`:

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Options.Applicative
import Data.Text (Text)
import qualified Data.Text.IO as TIO

data Opts = Opts
  { optChannelId      :: Text
  , optMessageId      :: Text
  , optDiscordToken   :: Text
  , optGeminiKey      :: Text
  } deriving (Show)

optsParser :: ParserInfo Opts
optsParser = info (helper <*> parser) $
  fullDesc <> progDesc "Archive a Discord conversation as a FAQ entry"
  where
    parser = Opts
      <$> strOption (long "channel-id" <> help "Discord channel ID")
      <*> strOption (long "message-id" <> help "Discord message ID")
      <*> strOption (long "discord-token" <> help "Discord bot token")
      <*> strOption (long "gemini-key" <> help "Gemini API key")

main :: IO ()
main = do
  opts <- execParser optsParser
  TIO.putStrLn $ "Channel: " <> optChannelId opts
  TIO.putStrLn $ "Message: " <> optMessageId opts
  TIO.putStrLn "TODO: implement pipeline"
```

**Step 5: Verify it builds**

Run: `cd discord-bot && nix build .#default`
Expected: builds successfully, produces `result/bin/discord-archive`

**Step 6: Test the executable**

Run: `./result/bin/discord-archive --channel-id 123 --message-id 456 --discord-token fake --gemini-key fake`
Expected: prints channel/message IDs

**Step 7: Commit**

```bash
git add discord-bot/
git commit -m "feat: scaffold Haskell CLI for Discord archive bot"
```

---

### Task 2: Discord message link parser

**Files:**
- Create: `discord-bot/src/MessageLink.hs`
- Modify: `discord-bot/src/Main.hs`
- Create: `discord-bot/test/MessageLinkSpec.hs`
- Modify: `discord-bot/discord-archive.cabal` (add test suite)

**Step 1: Add test dependencies to cabal**

Add to `discord-bot/discord-archive.cabal`:

```cabal
test-suite discord-archive-test
  type:             exitcode-stdio-1.0
  main-is:          Spec.hs
  hs-source-dirs:   test, src
  default-language: Haskell2010
  default-extensions:
    OverloadedStrings
  build-depends:
      base
    , hspec
    , text
    , aeson
    , bytestring
    , optparse-applicative >= 0.16
    , req >= 3.9
    , time
    , vector
```

**Step 2: Write the test**

Create `discord-bot/test/Spec.hs`:

```haskell
{-# LANGUAGE OverloadedStrings #-}

import Test.Hspec
import MessageLink

main :: IO ()
main = hspec $ do
  describe "parseMessageLink" $ do
    it "parses a full Discord message URL" $
      parseMessageLink "https://discord.com/channels/123/456/789"
        `shouldBe` Just (MessageRef "123" "456" "789")

    it "parses a canary URL" $
      parseMessageLink "https://canary.discord.com/channels/111/222/333"
        `shouldBe` Just (MessageRef "111" "222" "333")

    it "rejects invalid URLs" $
      parseMessageLink "https://example.com/foo" `shouldBe` Nothing

    it "rejects URLs with missing parts" $
      parseMessageLink "https://discord.com/channels/123/456" `shouldBe` Nothing
```

**Step 3: Run test to verify it fails**

Run: `cd discord-bot && nix develop -c cabal test`
Expected: FAIL (module `MessageLink` not found)

**Step 4: Implement MessageLink module**

Create `discord-bot/src/MessageLink.hs`:

```haskell
module MessageLink (MessageRef(..), parseMessageLink) where

import Data.Text (Text)
import qualified Data.Text as T

data MessageRef = MessageRef
  { refGuildId   :: Text
  , refChannelId :: Text
  , refMessageId :: Text
  } deriving (Eq, Show)

-- | Parse a Discord message URL into guild/channel/message IDs.
-- Accepts: https://discord.com/channels/{guild}/{channel}/{message}
--          https://canary.discord.com/channels/{guild}/{channel}/{message}
parseMessageLink :: Text -> Maybe MessageRef
parseMessageLink url =
  case T.splitOn "/channels/" stripped of
    [_, rest] ->
      case T.splitOn "/" rest of
        [gid, cid, mid]
          | not (T.null gid) && not (T.null cid) && not (T.null mid) ->
            Just (MessageRef gid cid mid)
        _ -> Nothing
    _ -> Nothing
  where
    stripped = T.replace "canary." "" url
```

**Step 5: Run test to verify it passes**

Run: `cd discord-bot && nix develop -c cabal test`
Expected: 4 tests PASS

**Step 6: Commit**

```bash
git add discord-bot/src/MessageLink.hs discord-bot/test/ discord-bot/discord-archive.cabal
git commit -m "feat: add Discord message link parser with tests"
```

---

### Task 3: Discord REST API message fetcher

**Files:**
- Create: `discord-bot/src/Discord.hs`
- Modify: `discord-bot/discord-archive.cabal` (add `http-client` dep if needed)

**Step 1: Write the Discord message fetcher**

Create `discord-bot/src/Discord.hs`:

```haskell
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Discord (DiscordMessage(..), fetchMessagesAround) where

import Data.Aeson
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import Network.HTTP.Req

data DiscordUser = DiscordUser
  { userId   :: Text
  , userName :: Text
  , userBot  :: Maybe Bool
  } deriving (Show, Generic)

instance FromJSON DiscordUser where
  parseJSON = withObject "DiscordUser" $ \o ->
    DiscordUser <$> o .: "id" <*> o .: "username" <*> o .:? "bot"

data DiscordMessage = DiscordMessage
  { dmId        :: Text
  , dmContent   :: Text
  , dmAuthor    :: DiscordUser
  , dmTimestamp :: UTCTime
  } deriving (Show)

instance FromJSON DiscordMessage where
  parseJSON = withObject "DiscordMessage" $ \o ->
    DiscordMessage
      <$> o .: "id"
      <*> o .: "content"
      <*> o .: "author"
      <*> o .: "timestamp"

-- | Fetch up to 50 messages around a given message ID from a Discord channel.
fetchMessagesAround :: Text -> Text -> Text -> IO (Either String [DiscordMessage])
fetchMessagesAround token channelId messageId = do
  result <- runReq defaultHttpConfig $ do
    r <- req GET
      (https "discord.com" /: "api" /: "v10" /: "channels" /: channelId /: "messages")
      NoReqBody
      jsonResponse
      (  header "Authorization" (TE.encodeUtf8 $ "Bot " <> token)
      <> queryParam "around" (Just messageId)
      <> queryParam "limit" (Just ("50" :: Text))
      )
    pure (responseBody r :: [DiscordMessage])
  pure (Right result)
  `catch` \(e :: HttpException) ->
    pure (Left (show e))
```

Note: `catch` needs `import Control.Exception (catch, SomeException)` or `UnliftIO`.

**Step 2: Verify it compiles**

Run: `cd discord-bot && nix develop -c cabal build`
Expected: compiles successfully

**Step 3: Commit**

```bash
git add discord-bot/src/Discord.hs
git commit -m "feat: add Discord REST API message fetcher"
```

---

### Task 4: Message clustering algorithm

**Files:**
- Create: `discord-bot/src/Cluster.hs`
- Create: `discord-bot/test/ClusterSpec.hs`

**Step 1: Write the failing test**

Add to `discord-bot/test/Spec.hs` (or create `ClusterSpec.hs` and import from Spec):

```haskell
-- In test/Spec.hs, add:
import Cluster
import Data.Time

-- Add test cases:
  describe "clusterMessages" $ do
    it "groups messages within 5 minutes of each other" $ do
      let t0 = read "2026-01-01 12:00:00 UTC" :: UTCTime
          t1 = read "2026-01-01 12:01:00 UTC" :: UTCTime
          t2 = read "2026-01-01 12:10:00 UTC" :: UTCTime  -- 10 min gap
          t3 = read "2026-01-01 12:11:00 UTC" :: UTCTime
          msgs = [ mkMsg "1" "alice" t0 "hello"
                 , mkMsg "2" "bob"   t1 "hi"
                 , mkMsg "3" "carol" t2 "different topic"
                 , mkMsg "4" "carol" t3 "indeed"
                 ]
          target = "2"  -- should be in cluster with "1"
          result = clusterMessages target msgs
      length result `shouldBe` 2
      map cmId result `shouldBe` ["1", "2"]

    it "extends cluster for same participants" $ do
      let t0 = read "2026-01-01 12:00:00 UTC" :: UTCTime
          t1 = read "2026-01-01 12:04:00 UTC" :: UTCTime
          t2 = read "2026-01-01 12:08:00 UTC" :: UTCTime  -- 4 min from t1
          msgs = [ mkMsg "1" "alice" t0 "q"
                 , mkMsg "2" "alice" t1 "follow-up"
                 , mkMsg "3" "alice" t2 "still going"
                 ]
          result = clusterMessages "1" msgs
      length result `shouldBe` 3
```

Where `mkMsg` is a test helper and `cmId`/`cmAuthorName` are accessors for `ClusterMessage`.

**Step 2: Run test to verify it fails**

Run: `cd discord-bot && nix develop -c cabal test`
Expected: FAIL

**Step 3: Implement Cluster module**

Create `discord-bot/src/Cluster.hs`:

```haskell
module Cluster (ClusterMessage(..), clusterMessages) where

import Data.Text (Text)
import Data.Time (UTCTime, diffUTCTime, NominalDiffTime)
import Data.List (groupBy)

data ClusterMessage = ClusterMessage
  { cmId         :: Text
  , cmAuthorId   :: Text
  , cmAuthorName :: Text
  , cmTimestamp  :: UTCTime
  , cmContent    :: Text
  } deriving (Eq, Show)

-- | Maximum time gap (seconds) between messages in the same cluster.
maxGapSeconds :: NominalDiffTime
maxGapSeconds = 300  -- 5 minutes

-- | Cluster messages by time proximity, then select the cluster
-- containing the target message ID.
clusterMessages :: Text -> [ClusterMessage] -> [ClusterMessage]
clusterMessages targetId msgs =
  case filter (any (\m -> cmId m == targetId)) clusters of
    (c:_) -> c
    []    -> []
  where
    sorted = sortByTime msgs
    clusters = buildClusters sorted

    sortByTime = id  -- assume messages are already sorted by timestamp

    buildClusters [] = []
    buildClusters (m:ms) = go [m] ms
      where
        go acc [] = [reverse acc]
        go acc (x:xs)
          | isCloseEnough (head acc) x = go (x:acc) xs
          | otherwise                  = reverse acc : go [x] xs

    isCloseEnough prev curr =
      let gap = abs (diffUTCTime (cmTimestamp curr) (cmTimestamp prev))
      in gap <= maxGapSeconds
         || cmAuthorId curr == cmAuthorId prev  -- extend for same author
```

**Step 4: Run test to verify it passes**

Run: `cd discord-bot && nix develop -c cabal test`
Expected: PASS

**Step 5: Commit**

```bash
git add discord-bot/src/Cluster.hs discord-bot/test/
git commit -m "feat: add message clustering algorithm with tests"
```

---

### Task 5: Gemini API digest module

**Files:**
- Create: `discord-bot/src/Gemini.hs`

**Step 1: Write the Gemini API caller**

Create `discord-bot/src/Gemini.hs`:

```haskell
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Gemini (digestConversation) where

import Data.Aeson
import Data.Aeson.Types (parseMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Vector as V
import GHC.Generics (Generic)
import Network.HTTP.Req
import Cluster (ClusterMessage(..))

-- | Call Gemini 2.5 Pro to digest a conversation into a FAQ entry.
-- Returns the raw markdown output from Gemini.
digestConversation :: Text -> [ClusterMessage] -> IO (Either String Text)
digestConversation apiKey messages = do
  let prompt = buildPrompt messages
      payload = object
        [ "contents" .= [ object [ "parts" .= [ object [ "text" .= prompt ] ] ] ]
        ]
  result <- runReq defaultHttpConfig $ do
    r <- req POST
      (https "generativelanguage.googleapis.com"
        /: "v1beta" /: "models" /: "gemini-2.5-pro:generateContent")
      (ReqBodyJson payload)
      jsonResponse
      (queryParam "key" (Just apiKey))
    pure (responseBody r :: Value)
  pure $ case extractText result of
    Just t  -> Right t
    Nothing -> Left "Failed to extract text from Gemini response"

extractText :: Value -> Maybe Text
extractText v = flip parseMaybe v $ \o -> do
  candidates <- o .: "candidates"
  first      <- withArray "candidates" (\a -> pure (a V.! 0)) candidates
  content    <- withObject "candidate" (.: "content") first
  parts      <- withObject "content" (.: "parts") content
  part0      <- withArray "parts" (\a -> pure (a V.! 0)) parts
  withObject "part" (.: "text") part0

buildPrompt :: [ClusterMessage] -> Text
buildPrompt msgs = T.unlines
  [ "다음은 NixOS 한국 커뮤니티 Discord 서버의 대화입니다."
  , "이 대화를 분석하여 FAQ 항목으로 정리해주세요."
  , ""
  , "출력 형식 (정확히 이 마크다운 형식을 따르세요):"
  , ""
  , "```"
  , "# <제목 - 질문 형태로>"
  , ""
  , "## 증상"
  , "<사용자가 겪은 문제나 상황 설명>"
  , ""
  , "## 원인"
  , "<문제의 원인 분석>"
  , ""
  , "## 해결 방법"
  , "<단계별 해결책, 코드 블록 포함>"
  , ""
  , "## 관련 주제"
  , "- [[topics/...]]"
  , "```"
  , ""
  , "규칙:"
  , "- 한국어로 작성하세요"
  , "- 제목은 \"~하고 싶어요\", \"~가 안 돼요\" 같은 자연스러운 질문형으로"
  , "- 해결 방법에는 구체적인 코드와 명령어를 포함하세요"
  , "- 관련 주제의 위키 링크는 flakes, home-manager, nixpkgs 등 기존 주제에서 선택"
  , "- 마크다운 코드 펜스 없이 순수 마크다운만 출력하세요"
  , ""
  , "=== 대화 시작 ==="
  , T.unlines (map formatMsg msgs)
  , "=== 대화 끝 ==="
  ]
  where
    formatMsg m = T.concat
      [ "[", cmAuthorName m, "] ", cmContent m ]
```

**Step 2: Verify it compiles**

Run: `cd discord-bot && nix develop -c cabal build`
Expected: compiles

**Step 3: Commit**

```bash
git add discord-bot/src/Gemini.hs
git commit -m "feat: add Gemini API digest module"
```

---

### Task 6: Wire up CLI main pipeline

**Files:**
- Modify: `discord-bot/src/Main.hs`

**Step 1: Update Main.hs to wire all modules together**

The CLI should:
1. Parse `--channel-id`, `--message-id`, `--discord-token`, `--gemini-key` from args
2. Fetch messages from Discord
3. Convert `DiscordMessage` → `ClusterMessage`
4. Cluster messages
5. Call Gemini to digest
6. Output JSON `{ "slug": "...", "content": "..." }` to stdout

```haskell
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Main where

import Data.Aeson (encode, object, (.=))
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.Char (isAlphaNum)
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import Options.Applicative
import System.Exit (exitFailure)
import qualified Data.Text.IO as TIO

import Cluster
import Discord
import Gemini

data Opts = Opts
  { optChannelId    :: Text
  , optMessageId    :: Text
  , optDiscordToken :: Text
  , optGeminiKey    :: Text
  } deriving (Show)

optsParser :: ParserInfo Opts
optsParser = info (helper <*> parser) $
  fullDesc <> progDesc "Archive a Discord conversation as a FAQ entry"
  where
    parser = Opts
      <$> strOption (long "channel-id" <> help "Discord channel ID")
      <*> strOption (long "message-id" <> help "Discord message ID")
      <*> strOption (long "discord-token" <> help "Discord bot token")
      <*> strOption (long "gemini-key" <> help "Gemini API key")

main :: IO ()
main = do
  opts <- execParser optsParser

  -- 1. Fetch messages
  TIO.hPutStrLn stderr "Fetching messages from Discord..."
  messagesResult <- fetchMessagesAround
    (optDiscordToken opts) (optChannelId opts) (optMessageId opts)
  rawMsgs <- case messagesResult of
    Left err   -> TIO.hPutStrLn stderr (T.pack err) >> exitFailure
    Right msgs -> pure msgs

  -- 2. Convert and cluster
  let clusterMsgs = map toClusterMsg rawMsgs
      clustered = clusterMessages (optMessageId opts) clusterMsgs

  when (null clustered) $ do
    TIO.hPutStrLn stderr "No messages found in cluster"
    exitFailure

  -- 3. Call Gemini
  TIO.hPutStrLn stderr "Calling Gemini API..."
  digestResult <- digestConversation (optGeminiKey opts) clustered
  faqContent <- case digestResult of
    Left err  -> TIO.hPutStrLn stderr (T.pack err) >> exitFailure
    Right md  -> pure md

  -- 4. Generate slug from first line (title)
  let slug = generateSlug faqContent

  -- 5. Output JSON
  BL.putStrLn $ encode $ object
    [ "slug"    .= slug
    , "content" .= faqContent
    ]

toClusterMsg :: DiscordMessage -> ClusterMessage
toClusterMsg dm = ClusterMessage
  { cmId         = dmId dm
  , cmAuthorId   = userId (dmAuthor dm)
  , cmAuthorName = userName (dmAuthor dm)
  , cmTimestamp  = dmTimestamp dm
  , cmContent    = dmContent dm
  }

-- | Extract a URL-safe slug from the FAQ title (first # line).
generateSlug :: Text -> Text
generateSlug content =
  let firstLine = case filter (T.isPrefixOf "# ") (T.lines content) of
        (l:_) -> T.drop 2 l
        []    -> "untitled"
  in T.intercalate "-"
     . filter (not . T.null)
     . T.split (not . isSlugChar)
     . T.toLower
     $ firstLine
  where
    isSlugChar c = isAlphaNum c || c == '-'
```

Note: The slug generation for Korean text needs consideration. Korean characters are alphanumeric via `isAlphaNum`, so `generateSlug` will keep them. If the slug should be ASCII-only, we'd transliterate or use a hash — but for Emanote paths, Korean filenames are fine.

**Step 2: Verify it compiles**

Run: `cd discord-bot && nix develop -c cabal build`
Expected: compiles

**Step 3: Commit**

```bash
git add discord-bot/src/Main.hs
git commit -m "feat: wire up CLI pipeline (fetch → cluster → digest → output)"
```

---

### Task 7: Rust Cloudflare Worker scaffold

**Files:**
- Create: `discord-bot/worker/Cargo.toml`
- Create: `discord-bot/worker/wrangler.toml`
- Create: `discord-bot/worker/src/lib.rs`
- Create: `discord-bot/worker/.gitignore`

**Step 1: Create directory**

```bash
mkdir -p discord-bot/worker/src
```

**Step 2: Write Cargo.toml**

Create `discord-bot/worker/Cargo.toml`:

```toml
[package]
name = "discord-archive-worker"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
worker = "0.4"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
ed25519-compact = "2"
hex = "0.4"

[profile.release]
opt-level = "s"
lto = true
codegen-units = 1
panic = "abort"
```

**Step 3: Write wrangler.toml**

Create `discord-bot/worker/wrangler.toml`:

```toml
name = "nixoskr-archive-bot"
main = "build/worker/shim.mjs"
compatibility_date = "2025-01-01"

[build]
command = "worker-build --release"

[[rules]]
globs = ["**/*.wasm"]
type = "CompiledWasm"

# Secrets (set via `npx wrangler secret put <NAME>`):
# DISCORD_PUBLIC_KEY
# GITHUB_TOKEN
# GITHUB_REPO (e.g. "nixos-kr/infra")
```

**Step 4: Write minimal src/lib.rs**

Create `discord-bot/worker/src/lib.rs`:

```rust
use worker::*;

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    Router::new()
        .get("/health", |_, _| Response::ok("OK"))
        .post_async("/interactions", |req, ctx| async move {
            Response::ok("TODO: handle Discord interactions")
        })
        .run(req, env)
        .await
}
```

**Step 5: Write .gitignore**

Create `discord-bot/worker/.gitignore`:

```
target/
build/
node_modules/
.wrangler/
```

**Step 6: Commit**

```bash
git add discord-bot/worker/
git commit -m "feat: scaffold Rust Cloudflare Worker for Discord interactions"
```

---

### Task 8: CF Worker Discord interaction handling

**Files:**
- Modify: `discord-bot/worker/src/lib.rs`

**Step 1: Implement full interaction handler**

Replace `discord-bot/worker/src/lib.rs`:

```rust
use ed25519_compact::{PublicKey, Signature};
use serde::{Deserialize, Serialize};
use serde_json::json;
use worker::*;

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    Router::new()
        .get("/health", |_, _| Response::ok("OK"))
        .post_async("/interactions", handle_interaction)
        .run(req, env)
        .await
}

async fn handle_interaction(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let public_key = ctx.secret("DISCORD_PUBLIC_KEY")?.to_string();

    // Read headers before consuming body
    let signature = req
        .headers()
        .get("X-Signature-Ed25519")?
        .ok_or_else(|| Error::RustError("Missing signature header".into()))?;
    let timestamp = req
        .headers()
        .get("X-Signature-Timestamp")?
        .ok_or_else(|| Error::RustError("Missing timestamp header".into()))?;

    let body = req.text().await?;

    // Verify Ed25519 signature
    if !verify_signature(&public_key, &signature, &timestamp, body.as_bytes()) {
        return Response::error("Invalid signature", 401);
    }

    let interaction: Interaction = serde_json::from_str(&body)
        .map_err(|e| Error::RustError(format!("Invalid JSON: {}", e)))?;

    match interaction.r#type {
        // PING
        1 => Response::from_json(&json!({"type": 1})),
        // APPLICATION_COMMAND
        2 => handle_command(interaction, &ctx).await,
        _ => Response::error("Unknown interaction type", 400),
    }
}

fn verify_signature(public_key_hex: &str, signature_hex: &str, timestamp: &str, body: &[u8]) -> bool {
    let Ok(pk_bytes) = hex::decode(public_key_hex) else { return false };
    let Ok(sig_bytes) = hex::decode(signature_hex) else { return false };
    let Ok(pk) = PublicKey::from_slice(&pk_bytes) else { return false };
    let Ok(sig) = Signature::from_slice(&sig_bytes) else { return false };

    let mut message = timestamp.as_bytes().to_vec();
    message.extend_from_slice(body);
    pk.verify(&message, &sig).is_ok()
}

async fn handle_command(interaction: Interaction, ctx: &RouteContext<()>) -> Result<Response> {
    // Extract message link from command options
    let message_link = interaction.data
        .as_ref()
        .and_then(|d| d.options.as_ref())
        .and_then(|opts| opts.first())
        .and_then(|opt| opt.value.as_ref())
        .map(|v| v.as_str().unwrap_or(""))
        .unwrap_or("");

    if message_link.is_empty() {
        return Response::from_json(&json!({
            "type": 4,
            "data": {"content": "메시지 링크를 입력해주세요."}
        }));
    }

    // Parse channel ID and message ID from the link
    let parts: Vec<&str> = message_link.split("/channels/").collect();
    let ids: Vec<&str> = parts.get(1).map(|s| s.split('/').collect()).unwrap_or_default();
    if ids.len() < 3 {
        return Response::from_json(&json!({
            "type": 4,
            "data": {"content": "올바른 메시지 링크가 아닙니다."}
        }));
    }
    let channel_id = ids[1];
    let msg_id = ids[2];

    // Trigger GitHub Actions via repository_dispatch
    let github_token = ctx.secret("GITHUB_TOKEN")?.to_string();
    let github_repo = ctx.var("GITHUB_REPO")?.to_string();

    let dispatch_body = json!({
        "event_type": "discord-archive",
        "client_payload": {
            "channel_id": channel_id,
            "message_id": msg_id,
            "interaction_token": interaction.token,
            "application_id": interaction.application_id,
        }
    });

    let url = format!("https://api.github.com/repos/{}/dispatches", github_repo);
    let mut headers = Headers::new();
    headers.set("Authorization", &format!("Bearer {}", github_token))?;
    headers.set("Accept", "application/vnd.github+json")?;
    headers.set("Content-Type", "application/json")?;
    headers.set("User-Agent", "nixoskr-archive-bot/1.0")?;

    let init = RequestInit {
        method: Method::Post,
        headers,
        body: Some(dispatch_body.to_string().into()),
        ..Default::default()
    };

    let request = Request::new_with_init(&url, &init)?;
    let resp = Fetch::Request(request).send().await?;

    if resp.status_code() != 204 {
        return Response::from_json(&json!({
            "type": 4,
            "data": {"content": "GitHub Actions 트리거에 실패했습니다."}
        }));
    }

    // Respond with deferred message (type 5)
    Response::from_json(&json!({
        "type": 5,
        "data": {"content": "📋 아카이브 처리 중..."}
    }))
}

#[derive(Deserialize)]
struct Interaction {
    r#type: u8,
    token: Option<String>,
    application_id: Option<String>,
    data: Option<InteractionData>,
}

#[derive(Deserialize)]
struct InteractionData {
    name: Option<String>,
    options: Option<Vec<InteractionOption>>,
}

#[derive(Deserialize)]
struct InteractionOption {
    name: String,
    value: Option<serde_json::Value>,
}
```

**Step 2: Build the worker locally**

Run: `cd discord-bot/worker && npx wrangler dev` (requires wrangler installed)
Or just verify Rust compilation: `cargo check --target wasm32-unknown-unknown`
Expected: compiles

**Step 3: Commit**

```bash
git add discord-bot/worker/src/lib.rs
git commit -m "feat: implement Discord interaction handler with Ed25519 verification"
```

---

### Task 9: GitHub Actions workflow

**Files:**
- Create: `.github/workflows/discord-archive.yaml`

**Step 1: Write the workflow**

Create `.github/workflows/discord-archive.yaml`:

```yaml
name: Discord Archive

on:
  repository_dispatch:
    types: [discord-archive]

jobs:
  archive:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: nixbuild/nix-quick-install-action@v33

      - name: Build discord-archive CLI
        run: nix build ./discord-bot#default --accept-flake-config

      - name: Run archive pipeline
        id: archive
        env:
          CHANNEL_ID: ${{ github.event.client_payload.channel_id }}
          MESSAGE_ID: ${{ github.event.client_payload.message_id }}
          DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
        run: |
          OUTPUT=$(./discord-bot/result/bin/discord-archive \
            --channel-id "$CHANNEL_ID" \
            --message-id "$MESSAGE_ID" \
            --discord-token "$DISCORD_BOT_TOKEN" \
            --gemini-key "$GEMINI_API_KEY")

          SLUG=$(echo "$OUTPUT" | jq -r '.slug')
          CONTENT=$(echo "$OUTPUT" | jq -r '.content')

          echo "slug=$SLUG" >> "$GITHUB_OUTPUT"

          # Write FAQ file
          echo "$CONTENT" > "nixos.kr/ko/faq/${SLUG}.md"

      - name: Create PR
        id: create-pr
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SLUG: ${{ steps.archive.outputs.slug }}
        run: |
          BRANCH="archive/${SLUG}"
          git checkout -b "$BRANCH"
          git add "nixos.kr/ko/faq/${SLUG}.md"
          git config user.name "nixoskr-bot"
          git config user.email "bot@nixos.kr"
          git commit -m "docs: add FAQ entry from Discord archive (${SLUG})"
          git push origin "$BRANCH"

          PR_URL=$(gh pr create \
            --title "FAQ: ${SLUG}" \
            --body "이 FAQ 항목은 Discord 대화에서 자동 생성되었습니다." \
            --head "$BRANCH" \
            --base master)

          echo "pr_url=$PR_URL" >> "$GITHUB_OUTPUT"

      - name: Post result to Discord
        env:
          APPLICATION_ID: ${{ github.event.client_payload.application_id }}
          INTERACTION_TOKEN: ${{ github.event.client_payload.interaction_token }}
          PR_URL: ${{ steps.create-pr.outputs.pr_url }}
        run: |
          curl -s -X PATCH \
            "https://discord.com/api/v10/webhooks/${APPLICATION_ID}/${INTERACTION_TOKEN}/messages/@original" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"✅ PR이 생성되었습니다: ${PR_URL}\"}"

      - name: Post error to Discord on failure
        if: failure()
        env:
          APPLICATION_ID: ${{ github.event.client_payload.application_id }}
          INTERACTION_TOKEN: ${{ github.event.client_payload.interaction_token }}
        run: |
          curl -s -X PATCH \
            "https://discord.com/api/v10/webhooks/${APPLICATION_ID}/${INTERACTION_TOKEN}/messages/@original" \
            -H "Content-Type: application/json" \
            -d '{"content": "❌ 아카이브 처리 중 오류가 발생했습니다."}'
```

**Step 2: Commit**

```bash
git add .github/workflows/discord-archive.yaml
git commit -m "feat: add GitHub Actions workflow for Discord archive bot"
```

---

### Task 10: Discord slash command registration

**Files:**
- Create: `discord-bot/register-command.sh`

**Step 1: Write registration script**

Create `discord-bot/register-command.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: ./register-command.sh <APPLICATION_ID> <BOT_TOKEN>
APP_ID="${1:?Usage: $0 <APPLICATION_ID> <BOT_TOKEN>}"
BOT_TOKEN="${2:?Usage: $0 <APPLICATION_ID> <BOT_TOKEN>}"

curl -s -X POST \
  "https://discord.com/api/v10/applications/${APP_ID}/commands" \
  -H "Authorization: Bot ${BOT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "archive",
    "description": "Discord 대화를 FAQ 항목으로 아카이브합니다",
    "default_member_permissions": "8192",
    "options": [
      {
        "name": "link",
        "description": "아카이브할 메시지 링크",
        "type": 3,
        "required": true
      }
    ]
  }' | jq .

echo "Slash command registered."
```

Note: `"default_member_permissions": "8192"` requires `MANAGE_MESSAGES` permission (moderators only).

**Step 2: Make it executable and commit**

```bash
chmod +x discord-bot/register-command.sh
git add discord-bot/register-command.sh
git commit -m "feat: add Discord slash command registration script"
```

---

### Task 11: Cloudflare Worker deployment

**Files:**
- Modify: `discord-bot/worker/wrangler.toml` (add GITHUB_REPO var)

**Step 1: Set up secrets and deploy**

This is a manual step. Run these commands:

```bash
cd discord-bot/worker

# Set secrets
npx wrangler secret put DISCORD_PUBLIC_KEY
npx wrangler secret put GITHUB_TOKEN

# Set variables (in wrangler.toml or via CLI)
# GITHUB_REPO is already in wrangler.toml as a var

# Deploy
npx wrangler deploy
```

**Step 2: Configure Discord application**

Go to Discord Developer Portal → Application → General Information:
- Set "Interactions Endpoint URL" to `https://nixoskr-archive-bot.<your-workers-subdomain>.workers.dev/interactions`
- Discord will send a PING to verify the endpoint

**Step 3: Register the slash command**

```bash
./discord-bot/register-command.sh <APPLICATION_ID> <BOT_TOKEN>
```

**Step 4: Add GitHub Actions secrets**

Go to GitHub repo → Settings → Secrets → Actions:
- `DISCORD_BOT_TOKEN`: Bot token from Discord Developer Portal
- `GEMINI_API_KEY`: API key from Google AI Studio

(`GITHUB_TOKEN` is auto-provided by Actions)

---

### Task 12: End-to-end integration test

**Step 1: Test the full flow**

1. In Discord, go to a channel where the bot has access
2. Find a message with a NixOS Q&A conversation
3. Run `/archive link:<paste message link>`
4. Verify:
   - Bot responds with "📋 아카이브 처리 중..."
   - GitHub Actions workflow triggers
   - A PR is created with a `ko/faq/<slug>.md` file
   - Bot updates the message with the PR link

**Step 2: Verify the generated FAQ**

- Check the PR content matches the FAQ template format
- Verify wiki-links are reasonable
- Check Korean language quality

**Step 3: Document any issues and iterate**

If the Gemini output doesn't match the expected format, adjust the prompt in `discord-bot/src/Gemini.hs`.

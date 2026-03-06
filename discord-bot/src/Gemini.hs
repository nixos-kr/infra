{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Gemini (FaqEntry(..), digestConversation) where

import Control.Exception (try, SomeException)
import Data.Aeson
import Data.Aeson.Types (parseMaybe)
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Vector as V
import Network.HTTP.Req

import Discord (DiscordMessage(..), DiscordUser(..))

data FaqEntry = FaqEntry
  { feSlug    :: Text
  , feContent :: Text
  } deriving (Eq, Show)

instance FromJSON FaqEntry where
  parseJSON = withObject "FaqEntry" $ \o ->
    FaqEntry <$> o .: "slug" <*> o .: "content"

instance ToJSON FaqEntry where
  toJSON (FaqEntry s c) = object ["slug" .= s, "content" .= c]

-- | Call Gemini 2.5 Pro to digest a conversation into FAQ entries.
-- May return multiple entries if the conversation covers multiple topics.
digestConversation :: Text -> [DiscordMessage] -> IO (Either String [FaqEntry])
digestConversation apiKey messages = do
  let prompt = buildPrompt messages
      payload = object
        [ "contents" .= [ object [ "parts" .= [ object [ "text" .= prompt ] ] ] ]
        , "generationConfig" .= object
            [ "responseMimeType" .= ("application/json" :: Text) ]
        ]
  result <- try $ runReq defaultHttpConfig $ do
    r <- req POST
      (https "generativelanguage.googleapis.com"
        /: "v1beta" /: "models" /: "gemini-2.5-pro:generateContent")
      (ReqBodyJson payload)
      jsonResponse
      (queryParam "key" (Just apiKey))
    pure (responseBody r :: Value)
  case result of
    Left (e :: SomeException) -> pure (Left (show e))
    Right val -> case extractEntries val of
      Just entries -> pure (Right entries)
      Nothing      -> pure (Left "Failed to extract FAQ entries from Gemini response")

extractEntries :: Value -> Maybe [FaqEntry]
extractEntries v = do
  t <- extractText v
  decode (BL.fromStrict (TE.encodeUtf8 t))

extractText :: Value -> Maybe Text
extractText v = parseMaybe parseResponse v
  where
    parseResponse = withObject "response" $ \top -> do
      candidates <- top .: "candidates"
      withArray "candidates" (\arr -> do
        case arr V.!? 0 of
          Nothing -> fail "Empty candidates array"
          Just cand -> do
            first <- withObject "candidate" (.: "content") cand
            parts <- withObject "content" (.: "parts") first
            withArray "parts" (\parr ->
              case parr V.!? 0 of
                Nothing -> fail "Empty parts array"
                Just p  -> withObject "part" (.: "text") p
              ) parts
        ) candidates

buildPrompt :: [DiscordMessage] -> Text
buildPrompt msgs = T.unlines
  [ "다음은 NixOS 한국 커뮤니티 Discord 서버의 대화입니다."
  , "이 대화를 분석하여 FAQ 항목으로 정리해주세요."
  , ""
  , "대화에 여러 주제가 포함되어 있을 수 있습니다."
  , "각 독립된 주제를 별도의 FAQ 항목으로 분리해주세요."
  , "관련 없는 잡담이나 인사는 무시하세요."
  , ""
  , "JSON 배열로 반환하세요. 각 항목의 형식:"
  , ""
  , "{"
  , "  \"slug\": \"url-safe-slug\","
  , "  \"content\": \"# 제목\\n\\n## 증상\\n...\\n\\n## 원인\\n...\\n\\n## 해결 방법\\n...\\n\\n## 관련 주제\\n- [[topics/...]]\\n\""
  , "}"
  , ""
  , "규칙:"
  , "- 한국어로 작성하세요"
  , "- 제목은 \"~하고 싶어요\", \"~가 안 돼요\" 같은 자연스러운 질문형으로"
  , "- 해결 방법에는 구체적인 코드와 명령어를 포함하세요"
  , "- slug는 URL에 사용할 수 있는 영문/숫자/하이픈 형태로"
  , "- 관련 주제의 위키 링크는 flakes, home-manager, nixpkgs 등 기존 주제에서 선택"
  , "- 잡담이나 인사만 있는 경우 빈 배열 [] 반환"
  , ""
  , "=== 대화 시작 ==="
  , T.unlines (map formatMsg msgs)
  , "=== 대화 끝 ==="
  ]
  where
    formatMsg m = T.concat ["[", duUsername (dmAuthor m), "] ", dmContent m]

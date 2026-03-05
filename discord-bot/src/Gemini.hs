{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Gemini (digestConversation) where

import Control.Exception (try, SomeException)
import Data.Aeson
import Data.Aeson.Types (parseMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Vector as V
import Network.HTTP.Req
import Cluster (ClusterMessage(..))

-- | Call Gemini 2.5 Pro to digest a conversation into a FAQ entry.
digestConversation :: Text -> [ClusterMessage] -> IO (Either String Text)
digestConversation apiKey messages = do
  let prompt = buildPrompt messages
      payload = object
        [ "contents" .= [ object [ "parts" .= [ object [ "text" .= prompt ] ] ] ]
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
    Right val -> case extractText val of
      Just t  -> pure (Right t)
      Nothing -> pure (Left "Failed to extract text from Gemini response")

extractText :: Value -> Maybe Text
extractText v = parseMaybe parseResponse v
  where
    parseResponse = withObject "response" $ \top -> do
      candidates <- top .: "candidates"
      withArray "candidates" (\arr -> do
        first <- withObject "candidate" (.: "content") (arr V.! 0)
        parts <- withObject "content" (.: "parts") first
        withArray "parts" (\parr ->
          withObject "part" (.: "text") (parr V.! 0)
          ) parts
        ) candidates

buildPrompt :: [ClusterMessage] -> Text
buildPrompt msgs = T.unlines
  [ "다음은 NixOS 한국 커뮤니티 Discord 서버의 대화입니다."
  , "이 대화를 분석하여 FAQ 항목으로 정리해주세요."
  , ""
  , "출력 형식 (정확히 이 마크다운 형식을 따르세요):"
  , ""
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
    formatMsg m = T.concat ["[", cmAuthorName m, "] ", cmContent m]

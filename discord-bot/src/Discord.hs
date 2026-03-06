{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Discord
  ( DiscordUser(..)
  , DiscordMessage(..)
  , MessageReference(..)
  , fetchMessagesAround
  , fetchMessage
  , fetchWithReferences
  ) where

import Control.Exception (try, SomeException)
import Data.Aeson
import Data.Either (rights)
import Data.List (nub, sortOn)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import Network.HTTP.Req

import MessageLink (MessageRef(..), parseMessageLink)

data DiscordUser = DiscordUser
  { duId       :: Text
  , duUsername  :: Text
  , duBot      :: Maybe Bool
  } deriving (Show, Generic)

instance FromJSON DiscordUser where
  parseJSON = withObject "DiscordUser" $ \o ->
    DiscordUser <$> o .: "id" <*> o .: "username" <*> o .:? "bot"

data MessageReference = MessageReference
  { mrefMessageId :: Maybe Text
  , mrefChannelId :: Maybe Text
  } deriving (Show)

instance FromJSON MessageReference where
  parseJSON = withObject "MessageReference" $ \o ->
    MessageReference <$> o .:? "message_id" <*> o .:? "channel_id"

data DiscordMessage = DiscordMessage
  { dmId               :: Text
  , dmContent          :: Text
  , dmAuthor           :: DiscordUser
  , dmTimestamp        :: UTCTime
  , dmMessageReference :: Maybe MessageReference
  } deriving (Show)

instance FromJSON DiscordMessage where
  parseJSON = withObject "DiscordMessage" $ \o ->
    DiscordMessage
      <$> o .: "id"
      <*> o .: "content"
      <*> o .: "author"
      <*> o .: "timestamp"
      <*> o .:? "message_reference"

-- | Fetch up to 50 messages around a given message ID.
fetchMessagesAround :: Text -> Text -> Text -> IO (Either String [DiscordMessage])
fetchMessagesAround token channelId messageId = do
  result <- try $ runReq defaultHttpConfig $ do
    r <- req GET
      (https "discord.com" /: "api" /: "v10" /: "channels" /: channelId /: "messages")
      NoReqBody
      jsonResponse
      (  header "Authorization" (TE.encodeUtf8 $ "Bot " <> token)
      <> queryParam "around" (Just messageId)
      <> queryParam "limit" (Just ("50" :: Text))
      )
    pure (responseBody r :: [DiscordMessage])
  case result of
    Left (e :: SomeException) -> pure (Left (show e))
    Right msgs -> pure (Right msgs)

-- | Fetch a single message by channel and message ID.
fetchMessage :: Text -> Text -> Text -> IO (Either String DiscordMessage)
fetchMessage token channelId messageId = do
  result <- try $ runReq defaultHttpConfig $ do
    r <- req GET
      (https "discord.com" /: "api" /: "v10" /: "channels" /: channelId /: "messages" /: messageId)
      NoReqBody
      jsonResponse
      (header "Authorization" (TE.encodeUtf8 $ "Bot " <> token))
    pure (responseBody r :: DiscordMessage)
  case result of
    Left (e :: SomeException) -> pure (Left (show e))
    Right msg -> pure (Right msg)

-- | Expand message list by following reply chains and embedded Discord links.
-- Fetches referenced messages not already in the list (one level deep).
fetchWithReferences :: Text -> [DiscordMessage] -> IO [DiscordMessage]
fetchWithReferences token msgs = do
  let knownIds = map dmId msgs
      refs = nub
        [ (cid, mid)
        | msg <- msgs
        , (cid, mid) <- getReferences msg
        , mid `notElem` knownIds
        ]
  results <- mapM (\(cid, mid) -> fetchMessage token cid mid) refs
  let extras = rights results
  pure (sortOn dmTimestamp (msgs ++ extras))

-- | Extract (channelId, messageId) pairs from a message's reply reference
-- and any Discord message links embedded in its content.
getReferences :: DiscordMessage -> [(Text, Text)]
getReferences msg = replyRefs ++ linkRefs
  where
    replyRefs = case dmMessageReference msg of
      Just ref -> case (mrefMessageId ref, mrefChannelId ref) of
        (Just mid, Just cid) -> [(cid, mid)]
        _                    -> []
      Nothing -> []
    linkRefs = map (\lr -> (refChannelId lr, refMessageId lr))
             $ extractDiscordLinks (dmContent msg)

-- | Extract Discord message links from text content.
extractDiscordLinks :: Text -> [MessageRef]
extractDiscordLinks =
  mapMaybe (parseMessageLink . T.dropAround (\c -> c == '<' || c == '>'))
  . filter (\w -> "discord.com/channels/" `T.isInfixOf` w)
  . T.words

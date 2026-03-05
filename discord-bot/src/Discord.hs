{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Discord (DiscordUser(..), DiscordMessage(..), fetchMessagesAround) where

import Control.Exception (try, SomeException)
import Data.Aeson
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import Network.HTTP.Req

data DiscordUser = DiscordUser
  { duId       :: Text
  , duUsername  :: Text
  , duBot      :: Maybe Bool
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

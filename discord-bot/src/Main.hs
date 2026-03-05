{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import Control.Monad (when)
import Data.Aeson (encode, object, (.=))
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.Char (isAlphaNum)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Options.Applicative
import System.Exit (exitFailure)
import System.IO (stderr)

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

  TIO.hPutStrLn stderr $ "Fetched " <> T.pack (show (length rawMsgs)) <> " messages"

  -- 2. Convert and cluster
  let clusterMsgs = map toClusterMsg rawMsgs
      clustered = clusterMessages (optMessageId opts) clusterMsgs

  when (null clustered) $ do
    TIO.hPutStrLn stderr "No messages found in cluster"
    exitFailure

  TIO.hPutStrLn stderr $ "Cluster size: " <> T.pack (show (length clustered))

  -- 3. Call Gemini
  TIO.hPutStrLn stderr "Calling Gemini API..."
  digestResult <- digestConversation (optGeminiKey opts) clustered
  faqContent <- case digestResult of
    Left err  -> TIO.hPutStrLn stderr (T.pack err) >> exitFailure
    Right md  -> pure md

  -- 4. Generate slug from title
  let slug = generateSlug faqContent

  TIO.hPutStrLn stderr $ "Generated slug: " <> slug

  -- 5. Output JSON to stdout
  BL.putStrLn $ encode $ object
    [ "slug"    .= slug
    , "content" .= faqContent
    ]

toClusterMsg :: DiscordMessage -> ClusterMessage
toClusterMsg dm = ClusterMessage
  { cmId         = dmId dm
  , cmAuthorId   = duId (dmAuthor dm)
  , cmAuthorName = duUsername (dmAuthor dm)
  , cmTimestamp  = dmTimestamp dm
  , cmContent    = dmContent dm
  }

-- | Extract a URL-safe slug from the FAQ title (first # line).
generateSlug :: Text -> Text
generateSlug content =
  let firstLine = case filter (T.isPrefixOf "# ") (T.lines content) of
        (l:_) -> T.drop 2 l
        []    -> "untitled"
      cleaned = T.intercalate "-"
        . filter (not . T.null)
        . T.split (\c -> not (isAlphaNum c) && c /= '-')
        . T.toLower
        $ firstLine
  in if T.null cleaned then "untitled" else cleaned

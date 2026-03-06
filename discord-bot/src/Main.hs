{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import Control.Monad (when)
import Data.Aeson (encode)
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Options.Applicative
import System.Exit (exitFailure)
import System.IO (stderr)

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
  fullDesc <> progDesc "Archive a Discord conversation as FAQ entries"
  where
    parser = Opts
      <$> strOption (long "channel-id" <> help "Discord channel ID")
      <*> strOption (long "message-id" <> help "Discord message ID")
      <*> strOption (long "discord-token" <> help "Discord bot token")
      <*> strOption (long "gemini-key" <> help "Gemini API key")

main :: IO ()
main = do
  opts <- execParser optsParser

  -- 1. Fetch messages around target
  TIO.hPutStrLn stderr "Fetching messages from Discord..."
  messagesResult <- fetchMessagesAround
    (optDiscordToken opts) (optChannelId opts) (optMessageId opts)
  rawMsgs <- case messagesResult of
    Left err   -> TIO.hPutStrLn stderr (T.pack err) >> exitFailure
    Right msgs -> pure msgs

  TIO.hPutStrLn stderr $ "Fetched " <> T.pack (show (length rawMsgs)) <> " messages"

  -- 2. Follow reply chains and embedded message links
  TIO.hPutStrLn stderr "Following message references..."
  allMsgs <- fetchWithReferences (optDiscordToken opts) rawMsgs

  when (null allMsgs) $ do
    TIO.hPutStrLn stderr "No messages found"
    exitFailure

  TIO.hPutStrLn stderr $ "Total messages (with references): " <> T.pack (show (length allMsgs))

  -- 3. Call Gemini for multi-topic FAQ generation
  TIO.hPutStrLn stderr "Calling Gemini API..."
  digestResult <- digestConversation (optGeminiKey opts) allMsgs
  entries <- case digestResult of
    Left err  -> TIO.hPutStrLn stderr (T.pack err) >> exitFailure
    Right es  -> pure es

  when (null entries) $ do
    TIO.hPutStrLn stderr "No FAQ-worthy topics found in conversation"
    exitFailure

  TIO.hPutStrLn stderr $ "Generated " <> T.pack (show (length entries)) <> " FAQ entries"

  -- 4. Output JSON array to stdout
  BL.putStrLn $ encode entries

{-# LANGUAGE OverloadedStrings #-}

module Main where

import Options.Applicative
import Data.Text (Text)
import qualified Data.Text.IO as TIO
import System.IO (stderr, hPutStrLn)

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
  TIO.hPutStrLn stderr $ "Channel: " <> optChannelId opts
  TIO.hPutStrLn stderr $ "Message: " <> optMessageId opts
  TIO.putStrLn "{\"slug\": \"test\", \"content\": \"# Test\"}"

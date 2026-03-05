{-# LANGUAGE OverloadedStrings #-}

import Test.Hspec
import MessageLink
import Cluster
import Data.Text (Text)
import Data.Time

-- Helper to make test ClusterMessages
mkMsg :: Text -> Text -> UTCTime -> Text -> ClusterMessage
mkMsg mid author ts content = ClusterMessage mid author author ts content

main :: IO ()
main = hspec $ do
  describe "parseMessageLink" $ do
    it "parses a full Discord message URL" $
      parseMessageLink "https://discord.com/channels/123/456/789"
        `shouldBe` Just (MessageRef "123" "456" "789")

    it "parses a canary URL" $
      parseMessageLink "https://canary.discord.com/channels/111/222/333"
        `shouldBe` Just (MessageRef "111" "222" "333")

    it "parses a ptb URL" $
      parseMessageLink "https://ptb.discord.com/channels/111/222/333"
        `shouldBe` Just (MessageRef "111" "222" "333")

    it "rejects invalid URLs" $
      parseMessageLink "https://example.com/foo" `shouldBe` Nothing

    it "rejects URLs with missing parts" $
      parseMessageLink "https://discord.com/channels/123/456" `shouldBe` Nothing

  describe "clusterMessages" $ do
    it "groups messages within 5 minutes of each other" $ do
      let t0 = read "2026-01-01 12:00:00 UTC" :: UTCTime
          t1 = read "2026-01-01 12:01:00 UTC" :: UTCTime
          t2 = read "2026-01-01 12:10:00 UTC" :: UTCTime
          t3 = read "2026-01-01 12:11:00 UTC" :: UTCTime
          msgs = [ mkMsg "1" "alice" t0 "hello"
                 , mkMsg "2" "bob"   t1 "hi"
                 , mkMsg "3" "carol" t2 "different topic"
                 , mkMsg "4" "carol" t3 "indeed"
                 ]
      map cmId (clusterMessages "2" msgs) `shouldBe` ["1", "2"]

    it "extends cluster for same participants" $ do
      let t0 = read "2026-01-01 12:00:00 UTC" :: UTCTime
          t1 = read "2026-01-01 12:04:00 UTC" :: UTCTime
          t2 = read "2026-01-01 12:08:00 UTC" :: UTCTime
          msgs = [ mkMsg "1" "alice" t0 "q"
                 , mkMsg "2" "alice" t1 "follow-up"
                 , mkMsg "3" "alice" t2 "still going"
                 ]
      length (clusterMessages "1" msgs) `shouldBe` 3

    it "returns empty for unknown target" $
      clusterMessages "999" [] `shouldBe` []

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

    it "parses a ptb URL" $
      parseMessageLink "https://ptb.discord.com/channels/111/222/333"
        `shouldBe` Just (MessageRef "111" "222" "333")

    it "rejects invalid URLs" $
      parseMessageLink "https://example.com/foo" `shouldBe` Nothing

    it "rejects URLs with missing parts" $
      parseMessageLink "https://discord.com/channels/123/456" `shouldBe` Nothing
